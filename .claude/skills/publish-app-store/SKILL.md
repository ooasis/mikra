---
name: publish-app-store
description: Ship a new Mikra build to App Store Connect — bump the build number, archive, and upload from the CLI. Use when the user asks to publish, ship, release, submit, or "push to the App Store", upload a build, or send a build to TestFlight for this project.
---

# Publish Mikra to App Store Connect

Upload authenticates with the Apple ID signed into Xcode. There is **no API key**
— `~/.appstoreconnect/private_keys/` is empty on purpose. Never ask the user for
a `.p8`, a key ID, or an app-specific password.

## Steps

1. **Commit first.** A shipped build must trace to a commit. Two commits, matching
   repo convention: one for the code, one titled `Bump build number to N`.

2. **Bump the build number** in `project.yml` (`CURRENT_PROJECT_VERSION`), then
   `xcodegen generate`. App Store Connect rejects a build number it has already
   seen. Keep `MARKETING_VERSION` unless the current version is already live on
   the store — then bump it too (1.0 → 1.0.1).

3. **Archive:**
   ```sh
   xcodebuild -project Mikra.xcodeproj -scheme Mikra \
     -destination 'generic/platform=iOS' -archivePath /tmp/Mikra.xcarchive \
     -allowProvisioningUpdates archive
   ```

4. **Upload** with `export.plist` (`method: app-store-connect`, `teamID:
   263U684LP7`, `uploadSymbols: true`, `destination: upload` — full plist in
   `appstore/SUBMISSION.md`):
   ```sh
   xcodebuild -exportArchive -archivePath /tmp/Mikra.xcarchive \
     -exportOptionsPlist export.plist -exportPath /tmp/mikra-upload \
     -allowProvisioningUpdates
   ```
   Success = `Progress 100%: Upload succeeded.` + `Uploaded Mikra` +
   `** EXPORT SUCCEEDED **`. Takes ~90s. `destination: export` instead produces a
   signed `.ipa` without delivering it.

5. **Report what's left**: ~15 min processing, then select the build on the
   version page in App Store Connect and finish the unchecked items in
   `appstore/SUBMISSION.md` (metadata, privacy, age rating, submit).

## Failure modes

- *"no application records"* → the app record doesn't exist in App Store Connect.
  The user creates it (Apps → + → New App, bundle `com.ooasis.mikra`); you can't.
- *Build number already used* → step 2 was skipped.
- Signing prompts → `-allowProvisioningUpdates` is missing from the command.

## Install on the user's iPhone instead

Not a release, but the usual companion request:
```sh
xcrun devicectl list devices                      # get the device id
xcodebuild -project Mikra.xcodeproj -scheme Mikra \
  -destination 'id=<device-id>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-id> \
  ~/Library/Developer/Xcode/DerivedData/Mikra-*/Build/Products/Debug-iphoneos/Mikra.app
```
