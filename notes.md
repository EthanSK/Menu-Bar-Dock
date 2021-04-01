# Notes

- Do not upload binary directly to github releases. Instead compress locally first, then upload that, or the app just doesn't open after downloading it.

- To check downloads of Menu Bar Dock, use Github API https://stackoverflow.com/a/4339085/6820042

  `curl https://api.github.com/repos/EthanSK/Menu-Bar-Dock/releases/latest`

- When exporting, first validate the app, then distribute it and make sure to upload to Apple's notary sevices or it will give a warning when tryna open it normally (and chrome will say that the download is potentially dodgy)
