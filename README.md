# nftables-geo-builder

A single-page Flutter app that generates Linux `nftables` deployment scripts for country-based IP allowlists.

The UI lets you choose:

- target country allowlist: `tw`, `jp`, `us`
- admin fixed IP allowlist
- SSH allow
- HTTP/HTTPS allow
- allow all ports
- custom ports
- protocol selection for web traffic, custom ports, and full-open rules

The app instantly generates a Bash deployment script that:

- disables `firewalld` and `ufw`
- downloads country IP ranges from `IPdeny`
- writes `/etc/nftables/country_ips.nft`
- writes `/etc/nftables.conf`
- registers a cron job to refresh country IP ranges daily
- enables `nftables`

## Tech Stack

- Flutter
- Dart 3
- Material 3
- Web and desktop-ready project structure

## Run Locally

1. Install Flutter.
2. Open this project folder.
3. Run:

```bash
flutter pub get
flutter run -d chrome
```

If your environment uses a local Flutter SDK path instead of PATH, run the SDK directly, for example:

```powershell
C:\Users\User\Documents\flutter_sdk_plain\bin\flutter.bat run -d chrome
```

## What The Script Does

Generated scripts follow this flow:

1. Disable old firewall services.
2. Download the selected country's IPv4 CIDR list from `https://www.ipdeny.com/ipblocks/data/countries/<country>.zone`.
3. Convert that list into an `nftables` set named `allow_ips`.
4. Apply rules that only allow traffic from the country allowlist and any optional admin IP allowlist.
5. Refresh the country list daily with cron.

## Important Notes

- Country IP allowlists are geoblocking helpers, not perfect geolocation controls.
- VPNs, proxies, cloud providers, and IP allocation quirks can still affect access behavior.
- If you do not set an admin fixed IP, you may lock yourself out of SSH.
- SSH normally uses TCP only. Be careful when opening UDP broadly.

## Verification

Current project checks used during development:

- `flutter analyze`
- `flutter test`

## License

No license has been added yet.
