//
//  DebugLog.swift
//  Menu Bar Dock
//
//  Bounded, asynchronous debug logging for diagnosing the hard-to-reproduce
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

    /// A normal quit closes the session. An unfinished marker is evidence of an
    /// abnormal exit, not proof of a crash (force-quit/power loss can also do it).
    /// Never install Swift signal handlers for the AppKit stack-overflow case:
    /// allocating or doing Foundation IO on an exhausted stack is unsafe.
    struct DiagnosticSession: Codable {
        let sessionID: String
        let processID: Int32
        let version: String
        var cleanShutdown = false
        var breadcrumbs: [String] = []

        init() {
            sessionID = UUID().uuidString
            processID = ProcessInfo.processInfo.processIdentifier
            version = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown").\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unknown")"
        }
    }

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

    // Only the IO queue owns this bounded state. Atomic checkpoints preserve
    // context across launches without polling, a crash handler, or UI work.
    private var diagnosticSession = DiagnosticSession()
    private let maxBreadcrumbs = 32
    private let maxBreadcrumbLength = 512
    private let diagnosticAdmissionLock = NSLock()
    private var pendingDiagnostics = 0
    private var droppedDiagnostics: UInt64 = 0

	// ISO-8601 formatter with fractional seconds, used both to WRITE the leading
	// timestamp and to PARSE it back during the time-based prune.
	private let isoFormatter: ISO8601DateFormatter = {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return f
	}()

	// MARK: - Init

	init(logDirectory: URL? = nil, enabled: Bool? = nil) {
		// Resolve ~/Library/Logs/Menu Bar Dock/debug.log
		let fm = FileManager.default
		if let logsDir = logDirectory ?? fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
			.appendingPathComponent("Logs", isDirectory: true)
			.appendingPathComponent(Constants.App.name, isDirectory: true) {
			self.logFileURL = logsDir.appendingPathComponent("debug.log", isDirectory: false)
		} else {
			self.logFileURL = nil
		}

		// Read the enable flag. Key absent => enabled (default ON). Only an
		// explicit `false` disables logging.
        if let enabled = enabled {
            self.isEnabled = enabled
        } else if UserDefaults.standard.object(forKey: DebugLog.enabledDefaultsKey) == nil {
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
            self?.beginDiagnosticSessionLocked(url: url)
		}
	}

	// MARK: - Public API

	// Fire-and-forget log of one line. Safe to call from any thread.
	// `message` should be a single human-readable line; we prepend a timestamp.
	func log(_ message: String) {
		guard isEnabled, let url = logFileURL else { return }
        let time = Date()
		ioQueue.async { [weak self] in
			guard let self = self else { return }
			// The formatter is mutable Foundation state; keep both formatting and
            // parsing on its owning queue when callers log concurrently.
            let line = "\(self.isoFormatter.string(from: time)) \(message)"
			self.appendRawLocked(line, url: url)
			self.enforceSizeCapLocked(url: url)
		}
	}

    /// Record primitive values supplied by their UI owner. This method never
    /// traverses views, asks AppKit to lay out/display, or captures user content.
    /// Checkpoints are asynchronous best effort: a fatal exit can still beat
    /// queued IO. debug.log plus macOS's .ips report remain complementary evidence.
    func diagnostic(_ message: String, checkpoint: Bool = false) {
        guard isEnabled, let url = logFileURL else { return }
        // If AppKit starts producing a pathological burst, discard diagnostic
        // detail instead of allowing logging closures to grow without bound.
        diagnosticAdmissionLock.lock()
        guard pendingDiagnostics < 256 else {
            droppedDiagnostics &+= 1
            diagnosticAdmissionLock.unlock()
            return
        }
        pendingDiagnostics += 1
        let dropped = droppedDiagnostics
        droppedDiagnostics = 0
        diagnosticAdmissionLock.unlock()
        let time = Date()
        let mainThread = Thread.isMainThread
        let bounded = String(message.prefix(maxBreadcrumbLength))
            .replacingOccurrences(of: "\n", with: " ")
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.diagnosticAdmissionLock.lock()
                self.pendingDiagnostics -= 1
                self.diagnosticAdmissionLock.unlock()
            }
            if dropped > 0 {
                self.appendRawLocked("\(self.isoFormatter.string(from: time)) [layout] diagnostic-overload dropped=\(dropped)", url: url)
            }
            let line = "\(self.isoFormatter.string(from: time)) [layout] main=\(mainThread) \(bounded)"
            self.appendRawLocked(line, url: url)
            self.diagnosticSession.breadcrumbs.append(line)
            if self.diagnosticSession.breadcrumbs.count > self.maxBreadcrumbs {
                self.diagnosticSession.breadcrumbs.removeFirst(self.diagnosticSession.breadcrumbs.count - self.maxBreadcrumbs)
            }
            if checkpoint { self.writeDiagnosticSessionLocked(url: url) }
            self.enforceSizeCapLocked(url: url)
        }
    }

    /// Used at normal application termination, never from a fatal-signal handler.
    func finishSession() {
        guard isEnabled, let url = logFileURL else { return }
        ioQueue.sync {
            diagnosticSession.cleanShutdown = true
            appendRawLocked("\(isoFormatter.string(from: Date())) [session] clean-shutdown", url: url)
            writeDiagnosticSessionLocked(url: url)
        }
    }

    /// Bounded queue barrier for diagnostics/tests; ordinary UI logging is async.
    func flush() { ioQueue.sync {} }

    private func beginDiagnosticSessionLocked(url: URL) {
        let directory = url.deletingLastPathComponent()
        let stateURL = directory.appendingPathComponent("layout-state.json")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: stateURL.path),
           let size = attributes[.size] as? UInt64,
           size <= 128 * 1024,
           let data = try? Data(contentsOf: stateURL),
           let previous = try? JSONDecoder().decode(DiagnosticSession.self, from: data),
           !previous.cleanShutdown {
            // Preserve exactly one prior unfinished run before replacing the live
            // state. It survives later clean launches until another abnormal exit.
            let previousURL = directory.appendingPathComponent("previous-session.json")
            try? data.write(to: previousURL, options: .atomic)
            appendRawLocked("\(isoFormatter.string(from: Date())) [session] previous-exit=unclean session=\(previous.sessionID) last=\(previous.breadcrumbs.last ?? "no checkpoint")", url: url)
        }
        appendRawLocked("\(isoFormatter.string(from: Date())) [session] id=\(diagnosticSession.sessionID) pid=\(diagnosticSession.processID) version=\(diagnosticSession.version) os=\(ProcessInfo.processInfo.operatingSystemVersionString)", url: url)
        writeDiagnosticSessionLocked(url: url)
    }

    private func writeDiagnosticSessionLocked(url: URL) {
        guard let data = try? JSONEncoder().encode(diagnosticSession) else { return }
        try? data.write(to: url.deletingLastPathComponent().appendingPathComponent("layout-state.json"), options: .atomic)
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
