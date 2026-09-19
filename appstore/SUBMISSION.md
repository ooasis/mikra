# App Store submission checklist

## Already done (in this repo)
- [x] App icon (Assets.xcassets/AppIcon, 1024px, no alpha)
- [x] Version 1.0, build 3 uploaded 2026-09-19 (project.yml)
- [x] Export compliance key (ITSAppUsesNonExemptEncryption=NO)
- [x] 6.9" screenshots in appstore/screenshots/ (1320×2868, iPhone 17 Pro Max)
- [x] Metadata drafts (metadata.md)
- [x] Privacy policy text (privacy-policy.md)

## One-time prerequisites
- [ ] Paid Apple Developer Program membership ($99/yr) on team 263U684LP7 — required for App Store distribution; a free account can only run on device. Check at developer.apple.com/account.
- [x] Privacy/support page live at https://mikra.pages.dev/ (docs/index.html, Cloudflare Pages project "mikra"; deploy updates with `wrangler pages deploy docs --project-name mikra --branch main`).

## App Store Connect (appstoreconnect.apple.com)
- [x] Apps → "+" → New App: iOS, name from metadata.md, primary language English, bundle ID com.ooasis.mikra (register it at developer.apple.com/account → Identifiers if it's not in the dropdown), SKU e.g. `mikra-001`.
- [ ] App Information: category, privacy policy URL.
- [ ] Pricing: Free, choose territories.
- [ ] App Privacy: answer "No" to data collection → publish "Data Not Collected".
- [ ] Age rating questionnaire → 4+.
- [ ] 1.0 version page: paste description/keywords/promo text, upload the two screenshots from appstore/screenshots/.

## Archive & upload

One command each, all from the repo root. Authentication is the Apple ID signed
into Xcode (Xcode → Settings → Accounts) — **no App Store Connect API key
needed**; `~/.appstoreconnect/private_keys/` is empty and can stay that way.

```sh
# 1. bump the build number (App Store Connect rejects a reused one)
sed -i '' 's/CURRENT_PROJECT_VERSION: N/CURRENT_PROJECT_VERSION: N+1/' project.yml
xcodegen generate

# 2. archive
xcodebuild -project Mikra.xcodeproj -scheme Mikra \
  -destination 'generic/platform=iOS' -archivePath /tmp/Mikra.xcarchive \
  -allowProvisioningUpdates archive

# 3. upload (export.plist below; `destination: upload` does the delivery)
xcodebuild -exportArchive -archivePath /tmp/Mikra.xcarchive \
  -exportOptionsPlist export.plist -exportPath /tmp/mikra-upload \
  -allowProvisioningUpdates
```

`export.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>263U684LP7</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>upload</string>
</dict>
</plist>
```

Success looks like `Progress 100%: Upload succeeded.` / `Uploaded Mikra` /
`** EXPORT SUCCEEDED **`. Swap `upload` for `export` to get a signed `.ipa`
without delivering it. The app record must exist in App Store Connect first,
or the upload fails with "no application records". Processing takes ~15 min
before the build is selectable on the version page.

Xcode's Organizer (Product → Archive → Distribute App → Upload) does the same
thing by hand; drop the archive in
`~/Library/Developer/Xcode/Archives/<date>/` for it to show up there.

## Submit
- [ ] Add App Review notes from metadata.md.
- [ ] Submit for Review. First review typically takes 1–3 days.

## Gotchas that cause first-submission rejections
- Privacy policy URL must load publicly (test in an incognito window).
- Screenshots must show the actual app (ours do).
- If Apple asks "does your app use encryption" anyway, answer No/exempt (HTTPS-only counts as exempt; we have no networking at all).
- Test once on a real iPhone before submitting — TTS voice availability can differ from the simulator (he-IL voice downloads on demand; if Speech.say is silent on device, the voice needs downloading in Settings → Accessibility → Spoken Content → Voices → Hebrew).
