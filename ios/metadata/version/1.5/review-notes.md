HOW TO REVIEW THE APP
Mood-E recommends movies from the user's current mood (12 emotions) via the TMDB API. The core flow is free and needs no account: diary, watchlist and planner stay on the device.

1. Complete onboarding, pick an emotion on the Mood tab, follow the 3 steps (emotion, goal, era).
2. Home shows a new "Quiz of the day" card (Premium): tap to play, long-press to hide it for today.
3. Tendenze tab: trending movies, plus Consigli, an anonymous community board. Safeguards: profanity filtering in 6 languages (client and server), per-post Report (auto-hidden after 3 reports), Hide, daily posting limits. Users are only a random nickname (e.g. RetroReel84): no personal data, no photos or videos, no direct messaging.
4. SUBSCRIPTION: Mood-E Premium, auto-renewable monthly (moode_premium_monthly, RevenueCat + StoreKit). Paywall: Settings > Mood-E Premium > Passa a Premium, or any Premium feature. It shows plan name, localized price, billing period (per month), what Premium unlocks, Restore Purchases, and working Terms of Use (EULA) and Privacy Policy links. The mood-to-movie flow stays free with ads (AdMob banner/interstitial/rewarded), removed for Premium subscribers.

DEMO ACCOUNT
Sign-in required: NO. There is no login gate: on a fresh install every screen is reachable without an account, so no demo credentials exist.
Sign-in (Settings > Account) only syncs a user's own data across their devices, via Sign in with Apple and Google only. The app has no username/password pair, so none can be supplied here. To test sync, use your own Apple ID; nothing else depends on it. Premium can be reviewed with a StoreKit sandbox account. Questions: gourbergnine07@gmail.com.

WHAT IS NEW IN VERSION 1.5

1. GERMAN AND PORTUGUESE. Interface, legal and support pages now in 6 languages (IT, EN, ES, FR, DE, PT), switchable in Settings > Language. Permission purpose strings localized for all 6 via InfoPlist.strings.

2. QUIZ OF THE DAY. Home suggests one quiz picked from the user's own history, fixed for the day; new quizzes with saved results and history.

3. RATING REQUEST (new here, described in full for transparency).
- Native StoreKit API only (the requestReview environment action). We never link out to the store to ask for a rating, never show a custom rating dialog, and never pre-qualify the user with a question before the system sheet.
- Called only after a positive action (a search that returned results, or marking a movie as watched), and only once one of these milestones is first reached: a 7-day streak, 5 movies marked as watched, the first real badge unlocked, or the app opened on 3 distinct days.
- Each milestone can ask at most once, ever. We also cap requests at 3, four months apart; iOS applies its own annual limit on top, so a call may correctly show nothing.
- Suppressed for several minutes after an error, an empty search or a deletion, so it never follows a frustrating moment.
- Settings > Support also has a "Rate Mood-E" row, which intentionally opens the App Store review page in Safari rather than forcing the native sheet: a button must always produce a visible result.
The sheet will most likely NOT appear during a short review session on a fresh install. This is intended.

4. DIARY. Entries are tappable to reopen a movie's page and removable; each saved movie shows how the user found it.

5. DEVELOPER WEBSITE. The Marketing URL of all 6 localizations points to the app's public website, hosting privacy policy, terms and support pages.

PERMISSIONS
Tracking: right after onboarding. Location: Cinema tab, then Allow. Camera and Photo Library: Home, then Scansiona un poster. Until tracking is answered we serve non-personalized ads only and never access the IDFA. A permission request is deliberately postponed to the next launch when the in-app language differs from the device language, so no alert appears in a language the user did not choose.

No changes to the subscription, paywall, ads or data collected since 1.4.
