# Fastlane — App Store automation

This directory contains everything needed to generate App Store screenshots and
push metadata to App Store Connect for **OpenWeer**. It contains **zero
secrets** — credentials live in `./secrets/.env.fastlane` (gitignored).

## One-time setup

1. Generate an App Store Connect API key
   - App Store Connect → Users & Access → Integrations → Keys → `+`
   - Role: **App Manager** (sufficient for `deliver`; use **Admin** for `produce`)
   - Download the `.p8` and drop it in `./secrets/`
2. Copy the env template and fill in the issuer ID:
   ```sh
   cp ./secrets/.env.fastlane.example ./secrets/.env.fastlane
   $EDITOR ./secrets/.env.fastlane
   ```
   `APPLE_TEAM_ID` is reused from the project-root `.env` (`APNS_TEAM_ID`),
   so it doesn't need to be set again here.
3. Install Ruby gems:
   ```sh
   bundle install
   ```
4. The app record must exist in App Store Connect before `deliver` can upload.
   Create it once via App Store Connect → Apps → `+` (bundle id `nl.openweer.app`),
   or scaffold it with `bundle exec fastlane produce` (requires Admin role).

## Lanes

```sh
# Generate App Store screenshots in every locale × device defined in Snapfile.
bundle exec fastlane ios screenshots

# Lint metadata against App Store rules (no upload).
bundle exec fastlane ios precheck_metadata

# Push metadata + screenshots to App Store Connect (preview before commit).
bundle exec fastlane ios upload_metadata

# Full pipeline: screenshots → precheck → upload (still requires manual review submit).
bundle exec fastlane ios release_metadata
```

## What is NOT automated here

- **Binary upload + code signing.** Build/upload from Xcode (Product → Archive →
  Distribute App), or wire up `match` + `gym` later against a private cert repo.
- **Privacy nutrition labels.** Apple's API doesn't yet support these — set
  once in App Store Connect; they persist across versions.
- **In-app purchases.** Precheck/deliver can't read IAP metadata via API Key
  auth yet (Apple limitation); we don't have any anyway.
- **Pricing & availability.** Set in App Store Connect.

## Files

| Path | Purpose |
|---|---|
| `Appfile` | Bundle id + team id (sourced from env) |
| `Snapfile` | Devices, locales, scheme for screenshot capture |
| `Deliverfile` | Defaults for the `deliver` action |
| `Fastfile` | Lane definitions |
| `metadata/` | Per-locale name/subtitle/description/keywords + global category/copyright/review info |
| `screenshots/` | Output of `screenshots` lane; consumed by `deliver` |
