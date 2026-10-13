# Janki Staff — mobile app

Android / iOS app for reception staff of Janki Agro Tourism. It talks to the
website over its staff API and does three things, each the same as on the
website's admin panel:

| App | Website |
|---|---|
| **Scan Ticket** | Admin ▸ Check-In (scan QR or type booking ID, edit, confirm check-in) |
| **Walk-in Booking** | Customer Enquiries ▸ Walk-in Customer |
| **Take Enquiry** | Customer Enquiries ▸ New Enquiry |

Staff log in with their website username and password. Only **Owner** and
**Manager** accounts can use the app (the same roles that can open those pages).

## Website side (do this first)

The API lives in the Laravel project (`routes/api.php`,
`app/Http/Controllers/Api/StaffAppController.php`). After deploying it:

```bash
php artisan migrate --force      # creates the api_tokens table
php artisan optimize:clear       # only if routes/config are cached
```

The site must be served over **HTTPS**. Check it is live:
`https://YOUR-DOMAIN/api/app/v1/config` should answer
`{"success":false,"message":"Session expired. Please log in again."}`.

## Build

The website address is set at build time (default
`https://jankiagro.nextlogic.in`, see `lib/core/config.dart`):

```bash
flutter pub get
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.com
```

### Codemagic

`codemagic.yaml` has two workflows:

- **Android APK** — works as is. Change `API_BASE_URL` in the file if the
  domain differs. The APK is in the build's artifacts.
- **iOS IPA** — Apple does not allow unsigned installs, so this needs an Apple
  Developer account connected to Codemagic (see the comments in the file).

Before a public release: upload your own Android keystore (comments in
`codemagic.yaml`), replace the launcher icons in
`android/app/src/main/res/mipmap-*` and `ios/Runner/Assets.xcassets`, and
change the app ID `com.jankiagro.janki_staff` / `com.jankiagro.jankiStaff` if
you want a different one.

## Security notes

- Release builds refuse any website address that is not HTTPS.
- The login token is stored in Android Keystore / iOS Keychain, never in
  plain storage, and is excluded from backups.
- The website stores only a hash of each token. A token stops working after
  30 days without use, on logout, when the account is deactivated or its role
  changes, and when its password is changed.
- Login attempts are rate-limited together with the website's login page.

## API (all under `/api/app/v1`, `Authorization: Bearer <token>`)

| Method | Path | Purpose |
|---|---|---|
| POST | `login` | `username`, `password` → `token` |
| POST | `logout` | revoke this device's token |
| GET | `config` | packages, prices, meal rates, holidays |
| POST | `ticket/lookup` | `code` = scanned QR text or booking ID |
| POST | `ticket/checkin` | save edits + check in |
| POST | `walkin` | new confirmed walk-in booking |
| GET | `availability` | seats for a date / rooms for a stay |
| POST | `enquiry` | new enquiry |
