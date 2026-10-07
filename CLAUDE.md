# CLAUDE.md

## Project

Native iOS analytics app for **nonprofits using Engaging Networks (EN)**. It reads the EN **Public Data Service** (read-only, public token) and turns it into dashboards, widgets, and **on-device AI insights** via Apple Intelligence (Foundation Models framework). No backend: all data, history, and AI inference stay on the device.

End users are nonprofit staff (development directors, digital/email managers, campaigners, EDs) — not analysts. Every screen should answer "how are we doing, and what should I do next?" in plain language.

Status: onboarding (`App/Onboarding/`), the **Pulse** tab (`Features/Pulse/`), the **Insights** tab (`Features/Insights/`, on hold since Oct 2026), the **Email** tab (`Features/Email/`) and the **Giving** tab (`Features/Giving/`) are built, inside a 5-tab shell (`App/MainTabView.swift`; More has the followed list, "Add a donation page" and Disconnect). `MainTabView` owns one `PulseViewModel` shared by Pulse and Insights, so the numbers are fetched once, plus one `GivingViewModel` and one `EmailViewModel`. `ENClient/` covers `EaSupporterCount`, `EaCampaignInfo`, `EventDetails`, `AccountReports` (newjoins, netdonoramounts, broadcaststats), `EaBroadcastInfo` (paged), `FundraisingSummaryByPage`, `FundraisingRollCall`, and reading a live page's `pageJson` (`pageDetails`). Email: rates over the last 30 complete days vs the 30 before, recent sends, best day to send, high-unsubscribe flags and a list-fatigue alert (`Analytics/EmailStats.swift`, `EmailRate.swift`). Giving: one donation page at a time (7 days / 30 days / whole campaign, a daily-total chart of the last 14 days including today, one-time vs recurring, recent donors), from pages added by link (`Features/Giving/AddDonationPageSheet.swift`, offered in onboarding step 2, Giving and More); `FollowedPage.pageId` is set only for those, and onboarding's Continue never removes them (they have their own card). Not built yet: goals + thermometer + pace, and the comps' Email filter chips (Appeals/Newsletters, would need `BroadcastMessageAttribute`). Facts come from `Analytics/`; `InsightRules.highlights` picks what's worth mentioning. Insights are written by Foundation Models (`Insights/InsightWriter.swift`: one request per fact; Swift sets the fact ID and severity) and checked by `Insights/InsightCheck.swift` (drops drafts with digits, unknown fact IDs, "we/our", or "this/last week"; templates fill any gaps). Without Apple Intelligence, `TemplateInsights` writes everything. Pulse's top card is a two-sentence briefing for the Executive Director when Apple Intelligence is on (`Insights/BriefingWriter.swift`, guided generation with a worked example, up to 3 tries); otherwise, or if every try fails `BriefingCheck`, it shows `TemplateInsights.pulse`. AI failures and rejected drafts are logged to subsystem `com.fursa.Compass`, category `AI` (read with `xcrun simctl spawn <udid> log show --info --predicate 'subsystem == "com.fursa.Compass"'`). The digest's no-digits rule rejects many drafts (the model keeps writing "half", "last week", "50%"), so the Insights tab often falls back to templates and says so. "Ask about your numbers" uses a `getWeeklyNumbers` tool, and falls back to listing the same figures in the instructions if tool calling fails (it fails on the iOS 27 simulator with a model-catalog asset error). SwiftData models: `FollowedPage`, `SupporterSnapshot`. Everything else below is the intended layout; update this file as it becomes real.

## Who's building this
I'm not a professional software developer — basic coding background, using Claude Code to do most of the implementation. Please:
- Make changes in small, single-purpose steps rather than big multi-file rewrites, so I can follow what changed and why.
- After each change, briefly explain in plain language what you did and why, not just show the diff.
- If something requires a manual step in Xcode (adding a capability, signing, adding a package dependency via Xcode's UI), say so explicitly and tell me exactly where to click.
- Prefer standard SwiftUI/Apple frameworks over third-party dependencies unless there's a clear reason not to.

## Tech stack

- SwiftUI, deployment target **iOS 27.0** (Foundation Models is available)
- Swift language mode 5 with **default actor isolation = MainActor** and Approachable Concurrency on (project build settings). Types are `@MainActor` unless marked otherwise: mark networking, decoding, and stats code `nonisolated` (or put it in an `actor`) so it runs off the main thread
- SwiftData for snapshots/cache, Swift Charts, WidgetKit, ActivityKit (Live Activities), App Intents, BackgroundTasks, MapKit, EventKit
- Foundation Models framework for insights; Accelerate / plain Swift for statistics
- Keychain for the EN token. No third-party dependencies without asking first.

## Intended layout

Xcode project: `Compass.xcodeproj`, single target and scheme `Compass`, bundle ID `com.fursa.Compass`. Sources live in `Compass/` (the inner folder). It is a **synchronized folder**: new files and subfolders created under `Compass/` are picked up by Xcode automatically, so don't edit `project.pbxproj` to add files.

Planned subfolders of `Compass/`:

```
App/            App entry, navigation, onboarding (token + region)
ENClient/       API client, service enum, row decoder, typed models
Store/          SwiftData models (snapshots), repositories, backfill
Analytics/      Pure-Swift stats: deltas, baselines, anomalies, forecasts, insight rules
Insights/       Foundation Models session, @Generable types, tools, fallback templates
Features/       Pulse, Fundraising, Email, Advocacy, Segments, Surveys, Events, Ops
Intents/        App Intents / Siri / Shortcuts
```

Need a manual Xcode step (File › New › Target), not just new folders:
- **Widget extension** (WidgetKit + Live Activities), which becomes its own top-level folder
- Capabilities (Signing & Capabilities tab): **Background Modes** (background fetch) and **App Groups** so the widget can read the app's snapshot data

## Engaging Networks Public API

Docs: https://developer.engagingnetworks.net/api/public/index.html#/ (OpenAPI source: `.../api/public/engagingnetworks.app.json`) and https://knowledge.engagingnetworks.net/datareports/public-data-services-using-a-token-public-api

### Request shape

```
GET https://{region}.engagingnetworks.app/ea-dataservice/data.service?service={Name}&token={publicToken}&contentType=json&...
```

- Regions: `ca` (Canada/Europe), `us`, `us2`, `test`. The user picks theirs at onboarding (the Data center picker shows US · US2 · Canada & EU · Test); store it with the token.
- When developing app, use the `test` region.
- **Test account (DEBUG builds only):** at the owner's request, `App/Onboarding/DebugTestAccount.swift` holds the owner's test-region token so the simulator's Connect screen starts filled in (pasting into the simulator is awkward). It's the one allowed exception to "never hardcode the token": keep it `#if DEBUG`, test region only, and never commit it (add it to `.gitignore` once this is a git repo). Don't copy the token anywhere else. `App/Onboarding/DebugDefaultPages.swift` (committed, DEBUG only) follows the owner's test-account donation pages 16105 (Watershed Donation), 12071 (IATS Donation Page) and 16315 (Alexey P2P donation page, type `p2pdonation`) once per install when connected with that account; Disconnect resets it. All three showed $0 in Oct 2026, likely because EN leaves test gifts out.
- **Demo mode (DEBUG builds only):** token `1` makes `ENClient` answer with fake data from `ENClient/ENDemoData.swift` (same JSON shape as EN) and seeds 12 weeks of supporter history. Use it to test without a real account. Real tokens are unaffected; release builds don't include it. Demo page links for Giving: page `71101` (Fall Appeal) and `71102` (Monthly giving) are donation pages, `71103` is a petition (rejected). The newest three demo email sends have high unsubscribes, so the list-fatigue alert shows.
- Always send `contentType=json` (default is XML).
- Token is a **public token** created by a Super Admin under Hello › Account settings › Tokens.

### Response shape (important)

JSON is a generic flat-file format, **not** typed objects, and every value is a string:

```json
{ "rows": [ { "columns": [ { "name": "sendCount", "value": "1234", "type": "..." } ] } ] }
```

Errors also come back as **HTTP 200** with `{"error": "..."}`; a bad token gives `Invalid token specified [<the token>]` (plus client IP), so never log or display that raw message.

Decode with one generic `ENRow` (`[name: value]` dictionary) and map to typed models in a separate step. Parse numbers/dates defensively; tolerate missing or extra columns and column-name casing differences (some services return UPPER_SNAKE names).

### Services

| Service | Key params | Use in app | Limits / notes |
|---|---|---|---|
| `EaSupporterCount` | — | Pulse headline | Point-in-time only → snapshot |
| `AccountReports` | `startDate`, `endDate` (**DD/MM/YYYY**), `resultType` = newjoins \| accounttotals \| netdonortransactions \| netdonoramounts \| broadcaststats | Pulse, trends, **history backfill** | Few rows per type |
| `FundraisingSummary` | `campaignId` | Totals per currency | |
| `FundraisingSummaryByPage` | `pageid`, `startDate`, `endDate` (**YYYY-MM-DD**) | Single vs recurring, pacing, backfill | USD/GBP/EUR/CAD/AUD only; excludes test gifts |
| `NetDonor` | `campaignId` | Page registrations, avg gift | |
| `FundraisingRollCall` | `campaignId`, `dataSet` | Live donor feed | Max 20 rows; may be disabled for UK/EU |
| `RollCall` | `campaignId`, `dataSet` (1=country, 2=city), `detailRows` | Participant map | Max 20 rows; may be disabled for UK/EU |
| `EaBroadcastInfo` | `broadcastId` or `startRow`/`endRow` | Email performance | Default newest 20; **max 100 rows/call** → paginate |
| `BroadcastMessageAttribute` | `detailRows` | Group broadcasts by attribute | Max 100 rows |
| `JourneyMessageDetails` | `workflowCount` | Automations map | |
| `EaEmailAOTarget` | `campaignId` | Advocacy funnel (hits → registrations → emails sent) | |
| `EaEmailAOTargetContact` | `campaignId`, `postcode` | Targets reached | |
| `ContactsByParty` | `constituencyDatabaseId` | Party breakdown | |
| `EaDataCapture` | `campaignId` | Data-capture campaign stats | |
| `EaCampaignInfo` | `campaignId`, `includeQuestions` | Campaign metadata | Spec says `campaignId` required; KB says optional — verify |
| `ProfileCount` | `profileName` | Segment size over time | Point-in-time → snapshot daily |
| `EaSupporterQuestionResponse` | `questionId`, `responseOrder` | Survey themes (AI) | Max 1,000 rows; contains first name/city |
| `EventDetails` | `pageStatus`, `publicOnly`, `sortOrder`, `eventTag` | Events list/map | Future events only |
| `ActiveJobs` | — | Ops status | |
| `EaAOContactData`, `EaAOContactDataByPostcode`, `EaReferenceData`, `SupporterData`, `DataApiResult` | — | **Not in scope** | `SupporterData` is an email lookup — do not build UI for it |

### API constraints to respect

- **Little history from the API.** Most services return current totals. The app builds history by writing a SwiftData snapshot on every refresh; `AccountReports` and `FundraisingSummaryByPage` can backfill past windows on first launch (fetch week by week).
- **Rate limits are undocumented.** Cache aggressively, dedupe in-flight requests, cap concurrency (~4), back off on errors, and never poll in a tight loop.
- **No service lists all pages.** The spec requires `campaignId` for `EaCampaignInfo` (it accepts several IDs, comma-separated, and returns their names). How pages get picked:
  - Events are listed automatically: `EventDetails` returns `PAGE_NAME`, `CAMPAIGN_ID`, `CAMPAIGN_PAGE_ID`.
  - Other pages: **the design assumes the user picks them from a dropdown list** (multi-select, searchable). This only works if `EaCampaignInfo` without `campaignId` really returns every campaign. Verify that first. If it doesn't, fall back to pasting a page link or ID (the page ID is in the URL `/page/{pageId}/...`) or sharing from Safari through a Share Extension.
  - `FundraisingSummaryByPage` returns the campaign `ID` and `NAME` for a page ID, so a donation page's link is enough to find its campaign.
  - Otherwise use `EaCampaignInfo` to show names for IDs the user entered.
  - **Verified (test account, Sep 2026):** `EaCampaignInfo` without `campaignId` returns every campaign (602 rows: Live, New, Closed, Deleted), with only `clientId`, `campaignId`, `campaignStatus`, `campaignName`, `campaignExportName`, `description` (no page type). The app falls back to adding pages by campaign ID if the list fails.
  - **Page IDs are not campaign IDs.** The number in a page link (`/page/{pageId}/…`) is a page ID; `EaCampaignInfo` returns nothing for it. Users will usually have page IDs, not campaign IDs.
  - **Verified:** live pages at `https://{region}.engagingnetworks.app/page/{pageId}/…` (no token needed) carry `<!-- Name:pageId:campaignId:clientId:… -->` and a JSON block with `"campaignId"`, `"campaignPageId"` and `"pageType"` (`donation`, `emailtotarget`, `advocacypetition`…). Inactive pages show "This page is currently inactive" and carry neither.
  - The ENS REST API can list pages by type, but it needs an IP-whitelisted API user, so it's not usable from a phone without a server. Out of scope.
  - **Verified (Oct 2026):** the live page's data is a `var pageJson = {"campaignPageId":…,"campaignId":…,"pageName":…,"pageType":…};` script block (`ENPageDetails`). `/page/{id}` redirects to `/page/{id}/-/1`; a campaign ID used as a page ID gives 404. The app always fetches pages from the account's own regional host, never from the host in a pasted link.
- **Verified `EaBroadcastInfo` (Oct 2026):** newest first; `broadcastDate` is **DD/MM/YYYY**; `startRow`/`endRow` are 1-based and inclusive, and asking for more than 100 rows is an error. Columns: `broadcastId`, `broadcastName`, `exportName`, `sendCount`, `openCount`, `clickCount`, `compCount`, `hardBounceCount`, `softbounceCount` (lowercase b), `unsubscribeCount`, `feedbackCount`, `optOut…`. Some rows report more opens or clicks than `sendCount` (even a click on a send of 0), so `EmailStats.Totals` caps each at the number sent. Test-account sends go to 1–2 people, so their rates are 0% or 100%.
- **Verified `FundraisingSummaryByPage` (Oct 2026):** needs a page ID (a campaign ID returns no rows); returns `ID` (campaign), `NAME`, `TOTAL_NUMBER`, `TOTAL_NUMBER_SINGLE`, `TOTAL_NUMBER_RECURRING` and `TOTAL_AMOUNT[_SINGLE|_RECURRING]_{USD,GBP,EUR,CAD,AUD}`; **no row at all** when the window has no gifts; accepts a start date as early as 2000-01-01 (used for "whole campaign") and a one-day window (start = end; the daily chart makes one call per day and caches days before yesterday for the session). Event pages work too: free tickets count as gifts of $0. Send its YYYY-MM-DD dates with `ENDateFormat.isoString(from:calendar:)` (the user's day), not the UTC version. Unverified: whether `TOTAL_AMOUNT_USD` is gifts made in USD or everything converted to USD; the app treats it as gifts in USD.
- **Verified `FundraisingRollCall` (Oct 2026):** columns `name`, `country`, `city`, `currency`, `amount`, `additionalComments`; returned 30 rows for one campaign (the docs say 20). The app never reads `additionalComments`, shows names as "Maria G.", and keeps donors in memory only.
- **Fields the API does not have** (never design around them): gift timestamps (`FundraisingRollCall` = name, city, amount from the last 7 days), per-target message counts (only total `emailsSent`; `EaEmailAOTargetContact` lists targets), survey response dates, campaign goals and deadlines. Goals and deadlines are entered by the user in the app. `TOTAL_NUMBER_RECURRING` counts recurring *gifts*, not donors.
- Services may be disabled per account or region. Treat an error or empty result as "feature unavailable" and hide the card rather than failing the screen.

## Design

UI comps: https://claude.ai/artifact/J7ZiJaN9Sf3kDsAFMZ6PaB (the design reference for all screens). No third-party branding.

- **Colors:** Teal `#0E5E6F` (accent: buttons, links, active tab, "good" changes) on a light tint `#E4EFED`; lighter teal `#5E949B` for secondary chart bars. Orange `#9A4309` on `#FBEDE3` for "needs attention" (`#B4530F` for chart marks). Text `#16181D`, secondary text `#5F6168`, screen background `#F5F4F0`, white cards, dividers `#E7E5DF`.
- **Good vs. bad:** show it with color *and* a ▲/▼ glyph; never color alone.
- **Time windows:** say "last 7 days" and "the 7 days before", never "this week" or "last week". Pulse compares the 7 complete days ending yesterday with the 7 days before those.
- **Tab bar:** grey outline icons, teal when selected. iOS fills tab symbols and colors them itself, so `MainTabView` draws each icon as a plain image (`TabIcon`).
- **Type:** Apple system fonts only. Screen titles use New York (serif, bold, 34pt large title); numbers use SF Rounded (semibold); body uses SF Pro with Dynamic Type.
- **Icons:** SF Symbols in the app (the comps draw simple line icons to stand in for them).

## Security & privacy (non-negotiable)

- Token lives only in the **Keychain**. Never hardcode, log, print, commit, or put it in UserDefaults, analytics, or crash reports. Redact `token=` from any logged URL.
- One token per org, entered by the user. Never ship a token in the binary or test fixtures (use `ENClient` mocks).
- Treat names, cities, and survey text as personal data: do not send them off device, do not persist them longer than needed, and keep them out of widgets and Lock Screen surfaces.
- No network calls other than the EN regional hosts.

## Analytics & AI rules

**Swift computes, the model narrates.** The on-device model is small (~4K-token context) and unreliable at arithmetic.

1. `Analytics/` computes every number: deltas, rates (open, click, click-to-open, unsubscribe, bounce, conversion), rolling baselines, z-score anomalies, simple linear or seasonal forecasts. Pure functions, fully unit tested.
2. Insight **rules** choose which facts matter and produce a compact `[Fact]` (id, metric, value, baseline, change, period). Keep it to ~20 facts per prompt.
3. Foundation Models turns facts into `@Generable` `Insight` values (`title`, `severity`, `factIDs`, `explanation`, `suggestedAction`). Use guided generation, not free-text parsing.
4. **The model never supplies numbers shown in the UI.** The UI renders figures from the referenced `factIDs`. Drop any insight that cites an unknown fact ID. One exception: Pulse's briefing may quote figures, but `BriefingCheck` rejects it unless every number in it (digits, or two–twelve spelled out) is one the app already shows for those facts.
5. For chat-style "why?" questions, use Foundation Models **tool calling** with tools that return precomputed figures only.
6. Always check `SystemLanguageModel.default.availability`. On unsupported devices, or when Apple Intelligence is off or the language is unsupported, fall back to template-based insights from the same rules. Every feature must work without AI.
7. Survey free text (themes, sentiment) is the one place raw text goes to the model: chunk it to fit the context window and aggregate the results in Swift.

Tone of generated copy: plain, encouraging, specific, nonprofit vocabulary (supporters, appeals, gifts, actions). No jargon, no invented benchmarks.

**Tested limits** (`PromptLab/`, email bounce-rate experiment, Sep 2026, on the macOS 26.7 model): an analyst-style prompt plus a 30-day vs last-year table (~2,600 tokens) runs out of the 4,096-token window before it finishes answering. Given raw counts, the model invents rates. Given precomputed rates, it attaches figures to the wrong rows, calls a one-send problem "systemic", and never links an import to the bounce spike, even when Swift hands it both findings. The thresholds and plans it writes are generic and change every run. What works (~3 s, ~800 tokens): Swift finds the problem, its scope, the likely causes and the thresholds; the model only words a headline and a short diagnosis.

## Features (priority order)

1. **Onboarding**: region, token (Keychain), test call, add campaign/page IDs
2. **Pulse**: supporters, new joins, raised, average gift, week-over-week; widget
3. **Email performance**: rates per broadcast, leaderboard, by attribute, day-of-week, list-fatigue alert
4. **Fundraising**: goal thermometer, pace vs goal and last year, single vs recurring, currencies
5. **Weekly AI digest** with a template fallback
6. Later: campaign-day Live Activity, Advocacy funnel + map, Segments (ProfileCount history), Survey themes, Events, Ops (ActiveJobs), App Intents ("How much did we raise this week?")

## Conventions

- `ENClient` is an `actor`; one method per service returning typed models; `async throws` with a typed `ENError`.
- Dates: two formatters for the two API formats. Name them after the API format (`ddMMyyyy`, `iso`), not after the service, and never mix them up. Store dates in UTC.
- Money: `Decimal` plus a currency code, never `Double`. Format with `FormatStyle.Currency`. Totals use the account's reporting currency, `AccountSettings.reportingCurrency`: USD for now, later a per-account setting.
- Views stay thin: `@Observable` view models per feature; no networking in views.
- Accessibility: Dynamic Type, VoiceOver labels on every chart (summarize the trend in words), don't encode meaning in color alone.
- Tests: Swift Testing (`@Test`). Required for `Analytics/`, row decoding, and date parsing. Use recorded JSON fixtures with fake data. Unit tests live in `CompassTests/` (fixtures in `Fixtures.swift`, dates pinned to UTC via `TestDates`); `ENClientDemoTests` exercises `ENClient` through demo mode, so no network. `CompassUITests/` is the UI test target (template only so far).

## Commands

```bash
# Build
xcodebuild -project Compass.xcodeproj -scheme Compass -destination 'generic/platform=iOS Simulator' build
# Unit tests. Use the iOS 27 simulator "iPhone 17 Pro"; the older 18.6 simulators can't run this app. Drop -only-testing to include the (slower) UI tests
xcodebuild -project Compass.xcodeproj -scheme Compass -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -only-testing:CompassTests test
# Prompt experiments on this Mac's own on-device model (Apple Intelligence must be on in macOS). Not part of the app. Reports go to PromptLab/Results/
swift run -c release --package-path PromptLab PromptLab
```

Apple Intelligence features only run on a simulator when the Mac itself has Apple Intelligence enabled. Otherwise the fallback path is what you'll see.

Git repository (branch `main`, no remote), started Oct 2026. `.gitignore` keeps out `DebugTestAccount.swift` and `data.txt` (both hold the test token), Xcode user data and build output. A fresh clone won't build until `DebugTestAccount.swift` is recreated locally. Commit after each working step so it can be reviewed and undone. Git commands that write to `.git` need to run outside the sandbox.


- Don't add a Co-Authored-By line to commit messages.