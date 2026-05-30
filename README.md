# USCIS Checker

A native iOS app for tracking multiple USCIS cases by receipt number. Built with SwiftUI for iOS 17+.

Check your case status on demand from the app — no logging into my.uscis.gov each time. Get a local notification when a tracked case's status changes.

## Features

- Track multiple cases by receipt number
- On-demand status check via the public `egov.uscis.gov` endpoint (no account needed)
- Automatic refresh when the app comes to the foreground
- Local notification when a case status changes
- Case detail view with the full USCIS description
- Cases persist between launches (stored in `UserDefaults`)

## How it works

USCIS's case status page (`https://egov.uscis.gov/`) is a Next.js app fronted by Cloudflare. Plain `URLSession` requests get blocked by Cloudflare's bot challenge, so the app uses a hidden `WKWebView` to:

1. Load the page so Cloudflare's JS challenge clears and sets the clearance cookie.
2. Call the case-status Next.js Server Action via `fetch()` from inside the page (cookies travel automatically).
3. Parse the line-prefixed JSON response and extract `actionCodeText` / `actionCodeDesc` from `detailsEng`.

See `USCISChecker/Network/WebStatusFetcher.swift`.

## Build & run

Requirements: Xcode 16+, iOS 17+ simulator or device.

```bash
brew install xcodegen
xcodegen generate
open USCISChecker.xcodeproj
```

Then press **Cmd+R**. To install on your own iPhone, set your Apple ID team in **Signing & Capabilities** — a free Apple ID works for personal devices.

## Tests

```bash
xcodebuild test \
  -scheme USCISChecker \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

Covers receipt-number validation, HTML parsing, Codable round-trips, and `CaseStore` add/delete/refresh/persistence — 23 tests.

## Project layout

```
USCISChecker/
├── App/                     App entry point
├── Models/                  CaseStatus, CaseRecord (Codable)
├── Validation/              Receipt number format check
├── Network/                 WebStatusFetcher (WKWebView) + protocol + legacy USCISClient
├── Notifications/           UNUserNotificationCenter wrapper
├── Store/                   CaseStore (ObservableObject + UserDefaults persistence)
└── Views/                   CaseListView, CaseCardView, AddCaseSheet, CaseDetailView
```

## If status fetching breaks

If the app starts returning errors for every case, USCIS has probably redeployed and the Next.js Server Action hash changed. To get the new one:

1. Open `https://egov.uscis.gov/` in a browser
2. Open DevTools → Network tab
3. Look up any case status
4. Find the `POST egov.uscis.gov/` request and copy the `next-action` header value
5. Update `nextActionId` in `USCISChecker/Network/WebStatusFetcher.swift`

## License

Personal project — no license declared.
