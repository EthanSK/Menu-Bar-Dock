# Uncomment the next line to define a global platform for your project
platform :macos, '10.15'

target 'Launcher' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Launcher

end

target 'Menu Bar Dock' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Menu Bar Dock
	pod 'SwiftLint'

	# Sparkle 2.x for auto-update — added 2026-05-28 (Ethan voice 7174).
	# Mirrors the macos-widgets-stats-from-website + producer-player release
	# pipelines: the framework is embedded into
	# Menu Bar Dock.app/Contents/Frameworks at archive time; the CI deep-signs
	# the nested bundles with Developer ID before notarizing; the appcast.xml
	# served from gh-pages drives in-app updates.
	#
	# 2.6.x is the last minor that supports macOS 10.15 (our deployment target
	# above). Bumping to 2.7+ would force a deployment-target bump to 11.0.
	pod 'Sparkle', '~> 2.6.4'


  target 'Menu Bar DockTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'Menu Bar DockUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end
