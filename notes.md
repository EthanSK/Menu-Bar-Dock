# Notes

- Do not upload binary directly to github releases. Instead compress locally first, then upload that, or the app just doesn't open after downloading it.

- To check downloads of Menu Bar Dock, use Github API https://stackoverflow.com/a/4339085/6820042
  `curl -s https://api.github.com/repos/EthanSK/Menu-Bar-Dock/releases | egrep '"name"|"download_count"'`

- When exporting, distribute it and make sure to upload to Apple's notary sevices or it will give a warning when tryna open it normally (and chrome will say that the download is potentially dodgy)

- We disabled app sandbox because otherwise it can't quit apps using the dropdown menu on right click

- The login item for the launcher is found in the file at `/private/var/db/com.apple.xpc.launchd/loginitems.501.plist`

- The plist with the user prefs is _usually_ found in the file at `/Users/ethansarif-kattan/Library/Preferences/com.ethansk.MenuBarDock.plist`. Use `defaults delete com.ethansk.MenuBarDock` in terminal to delete it properly.
