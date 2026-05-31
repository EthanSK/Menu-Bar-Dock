//
//  DebugLog.swift
//  Menu Bar Dock
//
//  Lightweight, crash-safe debug logging for diagnosing the hard-to-reproduce
//  activation / recency-ordering issues (see LEARNINGS.md + the v4.7.5
//  post-mortem). The whole point of this file is so that when Ethan hits a
//  "the order looks wrong / app X isn't showing" situation that's hard to
//  describe, there is a readable timestamped trace on disk that a future agent
//  can just open and read — no live debugging session required.
//
//  WHERE THE LOG LIVES
//  -------------------
//    ~/Library/Logs/Menu Bar Dock/debug.log
//  This path is chosen deliberately:
//    - It's visible in Console.app under "Log Reports" / "~/Library/Logs", so
//      Ethan can grab it from the GUI.
//    - It's a plain text file, so it can be `cat`-ed, attached to Telegram, or
//      read directly by an agent.
//  If the directory doesn't exist we create it on first write.
//
//  RETENTION (Ethan: "don't keep logs too old, maybe a day")
//  ----------------------------------------------------------
//  Two complementary guards keep the file bounded:
//    1. TIME-BASED prune: on launch (and opportunistically thereafter) we drop
//       any line whose leading ISO-8601 timestamp is older than ~24h.
//    2. SIZE-BASED cap: if the file exceeds `maxFileSizeBytes` we trim the
//       OLDEST lines (front of the file) until it's back under a low-water
//       mark. This protects against a pathological burst of activations
//       producing megabytes within a single day.
//  Both are best-effort: if anything throws we swallow it — logging must NEVER
//  crash or destabilise the app.
//
//  THREADING / OVERHEAD
//  --------------------
//  All file IO happens on a single dedicated SERIAL queue (`ioQueue`), off the
//  main thread, so logging from the activation-notification callback (which
//  fires on .main) never blocks the UI. Calls are fire-and-forget (async).
//  Formatting the message is cheap; the actual disk append is serialised.
//
//  ENABLE / DISABLE
//  ----------------
//  Logging is ON by default (Ethan wants to capture repros without fiddling).
//  It can be turned off by setting the UserDefaults key
//  `MenuBarDockDebugLogging` to NO (e.g. via:
//    defaults write com.ethansk.MenuBarDock MenuBarDockDebugLogging -bool NO
//  ). We read the flag once and cache it; absence of the key == enabled.
//

import Foundation

// Global singleton accessor. `DebugLog.shared.log(...)` from anywhere.
final class DebugLog {

	// MARK: - Singleton

	static let shared = DebugLog()

	// MARK: - Configuration

	// Max file size before we trim the oldest lines. A few MB is plenty for a
	// day of activation events and keeps the file trivially attachable/readable.
	private let maxFileSizeBytes: UInt64 = 4 * 1024 * 1024 // 4 MB hard cap
	// After a size-trim we cut down to this low-water mark so we don't trim on
	// every single write once we're near the cap.
	private let trimToBytes: UInt64 = 3 * 1024 * 1024 // 3 MB low-water mark
	// Retention window for the time-based prune.
	private let maxAgeSeconds: TimeInterval = 24 * 60 * 60 // ~24h

	// UserDefaults key to disable logging (default = enabled when key absent).
	private static let enabledDefaultsKey = "MenuBarDockDebugLogging"

	// MARK: - State

	// Dedicated serial queue so all disk IO is off the main thread and ordered.
	private let ioQueue = DispatchQueue(label: "com.ethansk.MenuBarDock.debuglog", qos: .utility)

	// Cached enabled flag (read once on init). If logging is disabled every
	// log() call becomes an early-return no-op for near-zero overhead.
	private let isEnabled: Bool

	// Absolute path to the log file, computed once. nil only if we somehow
	// can't resolve the user's Library/Logs dir (then logging is a no-op).
	private let logFileURL: URL?

	// ISO-8601 formatter with fractional seconds, used both to WRITE the leading
	// timestamp and to PARSE it back during the time-based prune.
	private let isoFormatter: ISO8601DateFormatter = {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return f
	}()

	// MARK: - Init

	private init() {
		// Resolve ~/Library/Logs/Menu Bar Dock/debug.log
		let fm = FileManager.default
		if let logsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
			.appendingPathComponent("Logs", isDirectory: true)
			.appendingPathComponent(Constants.App.name, isDirectory: true) {
			self.logFileURL = logsDir.appendingPathComponent("debug.log", isDirectory: false)
		} else {
			self.logFileURL = nil
		}

		// Read the enable flag. Key absent => enabled (default ON). Only an
		// explicit `false` disables logging.
		if UserDefaults.standard.object(forKey: DebugLog.enabledDefaultsKey) == nil {
			self.isEnabled = true
		} else {
			self.isEnabled = UserDefaults.standard.bool(forKey: DebugLog.enabledDefaultsKey)
		}

		// On launch: ensure the directory exists and prune anything older than
		// the retention window. Done async on the io queue so init stays cheap.
		guard isEnabled, let url = logFileURL else { return }
		ioQueue.async { [weak self] in
			self?.ensureDirectoryExists(for: url)
			self?.pruneOldLinesLocked(url: url)
			// Mark a session boundary so it's obvious in the log where each
			// launch starts (helps when reading a multi-launch trace).
			self?.appendRawLocked("==== Menu Bar Dock launched (logging on) ====", url: url)
		}
	}

	// MARK: - Public API

	// Fire-and-forget log of one line. Safe to call from any thread.
	// `message` should be a single human-readable line; we prepend a timestamp.
	func log(_ message: String) {
		guard isEnabled, let url = logFileURL else { return }
		let ts = isoFormatter.string(from: Date())
		// Build the full line on the calling thread (cheap), append on ioQueue.
		let line = "\(ts) \(message)"
		ioQueue.async { [weak self] in
			guard let self = self else { return }
			self.appendRawLocked(line, url: url)
			self.enforceSizeCapLocked(url: url)
		}
	}

	// MARK: - Private file helpers (all run on ioQueue — "Locked" suffix means
	//         "only call from ioQueue", giving us serial-access safety).

	private func ensureDirectoryExists(for fileURL: URL) {
		let dir = fileURL.deletingLastPathComponent()
		do {
			try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		} catch {
			// Best effort — if we can't make the dir, subsequent writes will
			// just fail silently. Never crash.
		}
	}

	// Append a single line (newline added) to the file, creating it if needed.
	private func appendRawLocked(_ line: String, url: URL) {
		let data = Data((line + "\n").utf8)
		do {
			if FileManager.default.fileExists(atPath: url.path) {
				// Append mode via file handle. Wrapped in do/catch so a transient
				// IO error can't take down the app.
				let handle = try FileHandle(forWritingTo: url)
				defer { handle.closeFile() }
				// seekToEndOfFile() (not seekToEnd()) — the latter needs macOS
				// 10.15.4 but our deployment target is 10.15, so it fails to build.
				// closeFile() likewise is the broadly-available counterpart of close().
				handle.seekToEndOfFile()
				handle.write(data)
			} else {
				// First write: create the file (directory was ensured at init).
				ensureDirectoryExists(for: url)
				try data.write(to: url, options: .atomic)
			}
		} catch {
			// Swallow — logging must never crash the app.
		}
	}

	// TIME-BASED retention: drop any line whose leading timestamp is older than
	// maxAgeSeconds. Lines without a parseable leading timestamp (e.g. the
	// session-boundary banner) are KEPT only if they appear after the first
	// retained timestamped line — simplest robust approach: we keep a line if
	// either (a) its timestamp parses and is recent, or (b) it has no timestamp
	// (banners/blank). This errs on the side of keeping a little extra rather
	// than dropping good data.
	private func pruneOldLinesLocked(url: URL) {
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		do {
			let contents = try String(contentsOf: url, encoding: .utf8)
			let cutoff = Date().addingTimeInterval(-maxAgeSeconds)
			let kept = contents.split(separator: "\n", omittingEmptySubsequences: false).filter { rawLine in
				let line = String(rawLine)
				// Extract the leading token up to the first space — that's the ISO ts.
				guard let spaceIdx = line.firstIndex(of: " ") else {
					return true // no space => banner/odd line => keep
				}
				let tsToken = String(line[line.startIndex..<spaceIdx])
				guard let date = isoFormatter.date(from: tsToken) else {
					return true // unparseable leading token => keep (don't lose data)
				}
				return date >= cutoff // keep only if within the retention window
			}
			let rebuilt = kept.joined(separator: "\n")
			// Write via Data (Data has write(to:options:); String.write does not
			// accept Data.WritingOptions). .atomic avoids a torn file on crash.
			try Data(rebuilt.utf8).write(to: url, options: .atomic)
		} catch {
			// Swallow — a failed prune just means the file keeps a bit more; the
			// size cap below is the backstop.
		}
	}

	// SIZE-BASED cap: if the file is over maxFileSizeBytes, trim oldest lines
	// (front of file) until under trimToBytes. This is the backstop against a
	// burst of activations producing a large file within the 24h window.
	private func enforceSizeCapLocked(url: URL) {
		do {
			let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
			guard let size = attrs[.size] as? UInt64, size > maxFileSizeBytes else { return }
			// Read everything, drop oldest lines until we're under the low-water
			// mark. Lines are time-ordered (we only ever append), so dropping
			// from the FRONT drops the oldest.
			let contents = try String(contentsOf: url, encoding: .utf8)
			var lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
			var running = UInt64(contents.utf8.count)
			var dropCount = 0
			while running > trimToBytes && dropCount < lines.count {
				running -= UInt64(lines[dropCount].utf8.count + 1) // +1 for the newline
				dropCount += 1
			}
			if dropCount > 0 {
				lines.removeFirst(dropCount)
				let rebuilt = lines.joined(separator: "\n")
				// Write via Data (see note in pruneOldLinesLocked).
				try Data(rebuilt.utf8).write(to: url, options: .atomic)
			}
		} catch {
			// Swallow — never crash on a maintenance failure.
		}
	}
}
