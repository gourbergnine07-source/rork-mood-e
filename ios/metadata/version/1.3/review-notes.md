# App Review — Reply for Mood-E 1.3 (build 15)

## Reply to send in App Store Connect (Resolution Center)

Hello App Review Team,

Thank you for the detailed feedback and for the screenshot, which made the issue
clear. Build 15 of version 1.3 fixes both points.

**1. Permission requests were not shown in the device language**

You are right: the purpose strings of our permission requests were hardcoded in
Italian, so on an English device the system alert showed an English title with an
Italian explanation.

What we changed in build 15:

- All four purpose strings are now fully localized through `InfoPlist.strings`
  files, in English, Italian, Spanish and French:
  - `NSUserTrackingUsageDescription` (App Tracking Transparency)
  - `NSLocationWhenInUseUsageDescription` (nearby cinemas)
  - `NSCameraUsageDescription` (movie poster scan)
  - `NSPhotoLibraryUsageDescription` (poster picked from the library)
- English is the default language of the app, and `CFBundleLocalizations`
  declares en, it, es, fr.
- On an English device every permission alert is now entirely in English, and
  the same applies to Italian, Spanish and French devices.

**2. Behaviour when the in-app language differs from the device language**

Mood-E also lets the user choose the app language on first launch, independently
from the device language. Because iOS resolves the language of system alerts once
per launch, a language chosen in-app can only affect system alerts starting from
the next launch.

To make sure a permission request is never displayed in a language the user did
not choose, build 15 postpones it in that specific case:

- App Tracking Transparency: the request is presented on the following launch.
  Until the user answers it, we serve non-personalized ads only, and we never
  access the IDFA.
- Location: tapping "Allow" shows a short in-app message asking the user to
  reopen the app, so the system alert appears in the selected language.

This means that if the app language is switched to a language different from the
device one, the ATT alert intentionally does not appear during that session; it
appears on the next launch. Launching the app with the device language and the
app language matching (for example both English) shows the ATT alert immediately.

**3. Subscription information on the paywall (previous submission)**

For completeness, the paywall also includes, as required: the plan name, the
localized price, the billing period ("per month"), and working links to the
Terms of Use (EULA) and the Privacy Policy.

We have attached a screen recording showing all permission requests in English on
an English-language device, plus the paywall details.

Thank you for your time and for reviewing our app.

Best regards,
The Mood-E team

## Screen recording — shot list

Record with the device (or simulator) language set to **English**, on a **fresh
install** so no permission has been answered yet. One single take, roughly 60–90
seconds, no cuts. Do not add narration; the alerts must be readable.

1. **Device language proof (5 s)** — Settings > General > Language & Region,
   iPhone Language = English. Then go back to the Home screen.
2. **Fresh install (5 s)** — Delete Mood-E (long press > Remove App > Delete
   App), then reinstall from TestFlight. If you cannot delete it, at least reset
   location and tracking in Settings > Privacy & Security.
3. **Launch and language choice (10 s)** — Open the app, let the splash play,
   and on the language screen select **English**. This keeps the app language and
   the device language aligned, which is the case App Review is testing.
4. **ATT alert in English (10 s)** — Complete onboarding. The tracking request
   appears: stay on it for 3–4 seconds so the full English text is readable, then
   tap "Allow Tracking" or "Ask App Not to Track".
5. **Location alert in English (10 s)** — Open the **Cinema** tab, tap the
   "Allow" button, hold on the system alert so the English text is readable, then
   confirm.
6. **Camera alert in English (10 s)** — Open the poster scan (camera icon), let
   the camera permission alert appear, hold on it, then allow.
7. **Photo library alert in English (8 s)** — In the same screen, choose the
   option to pick a poster from the library, let the alert appear, hold on it.
8. **Paywall details (15 s)** — Open the premium screen. Slowly show the plan
   name, the price and "per month", then tap **Terms of Use (EULA)**: the page
   opens. Go back and tap **Privacy Policy**: the page opens too.
9. **Optional but useful (15 s)** — Switch the device to French, relaunch the
   app, and trigger one permission alert to show it appears in French. This
   proves the localization is real and not a hardcoded English string.

### Common mistakes to avoid

- Do not skip the fresh install: an already-answered permission will never show
  its alert again, and the video would prove nothing.
- Do not select a language in the app that is different from the device one for
  shots 4–7, otherwise the ATT alert is intentionally deferred to the next launch
  and the reviewer would see nothing.
- Do not crop the alerts: the full text must be visible.
- Upload the video in the Resolution Center message as an attachment, and
  mention it in the reply text (already included above).
