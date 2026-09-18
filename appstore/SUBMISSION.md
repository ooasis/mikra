# App Store submission checklist

## Already done (in this repo)
- [x] App icon (Assets.xcassets/AppIcon, 1024px, no alpha)
- [x] Version 1.0, build 1 (project.yml)
- [x] Export compliance key (ITSAppUsesNonExemptEncryption=NO)
- [x] 6.9" screenshots in appstore/screenshots/ (1320×2868, iPhone 17 Pro Max)
- [x] Metadata drafts (metadata.md)
- [x] Privacy policy text (privacy-policy.md)

## One-time prerequisites
- [ ] Paid Apple Developer Program membership ($99/yr) on team 263U684LP7 — required for App Store distribution; a free account can only run on device. Check at developer.apple.com/account.
- [ ] Fill in your contact email in privacy-policy.md, then host it at a public URL (`gh gist create --public appstore/privacy-policy.md` is the quickest; GitHub Pages also works).

## App Store Connect (appstoreconnect.apple.com)
- [ ] Apps → "+" → New App: iOS, name from metadata.md, primary language English, bundle ID com.ooasis.mikra (register it at developer.apple.com/account → Identifiers if it's not in the dropdown), SKU e.g. `mikra-001`.
- [ ] App Information: category, privacy policy URL.
- [ ] Pricing: Free, choose territories.
- [ ] App Privacy: answer "No" to data collection → publish "Data Not Collected".
- [ ] Age rating questionnaire → 4+.
- [ ] 1.0 version page: paste description/keywords/promo text, upload the two screenshots from appstore/screenshots/.

## Archive & upload (Xcode is easiest)
1. `xcodegen generate` if project.yml changed since last time.
2. Open Mikra.xcodeproj in Xcode, select the "Mikra" scheme, destination **Any iOS Device (arm64)**.
3. Product → Archive.
4. In the Organizer window: Distribute App → App Store Connect → Upload (accept defaults; automatic signing handles certificates/profiles).
5. Wait ~15 min for processing, then on the 1.0 version page select the build.

(First submission: use Xcode's Organizer as above — it handles signing questions interactively. Later releases can script this with `xcodebuild archive` + `-exportArchive`.)

## Submit
- [ ] Add App Review notes from metadata.md.
- [ ] Submit for Review. First review typically takes 1–3 days.

## Gotchas that cause first-submission rejections
- Privacy policy URL must load publicly (test in an incognito window).
- Screenshots must show the actual app (ours do).
- If Apple asks "does your app use encryption" anyway, answer No/exempt (HTTPS-only counts as exempt; we have no networking at all).
- Test once on a real iPhone before submitting — TTS voice availability can differ from the simulator (he-IL voice downloads on demand; if Speech.say is silent on device, the voice needs downloading in Settings → Accessibility → Spoken Content → Voices → Hebrew).
