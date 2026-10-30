# <img src="Packaging/icon.png" width="48" height="48" align="absmiddle"> InternetCheck

macOS menubar app that checks whether you're online and shows which connection you're using.

- Wi-Fi icon when online, red dot when offline.
- Polls Apple, Cloudflare and Google in parallel; online if any answers with its expected reply, so captive-portal login pages read as offline.
- Dropdown shows the active connection (Wi-Fi, USB LAN, iPhone USB, …) with interface and IP; a VPN tag appears when the route goes through a tunnel.
- Preferences: enable/disable targets, add your own URL or IP, interval, optional notifications, launch at login.

## Install
```sh
brew install --cask PhilRoli/tap/internet-check
```

## Development
```sh
swift test
./rebuild.sh
```
Built on [menubar-kit](https://github.com/PhilRoli/menubar-kit).
