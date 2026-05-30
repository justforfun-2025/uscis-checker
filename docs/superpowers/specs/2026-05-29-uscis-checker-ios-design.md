# USCIS Checker iOS App — Design Spec

**Date:** 2026-05-29

## Overview

A native SwiftUI iOS app that lets the user track multiple USCIS cases by receipt number. The app checks case status on demand via the public USCIS status endpoint (no login required) and fires a local push notification when a status change is detected.

---

## Architecture

Three layers with a SwiftUI UI on top:

- **Data layer — `CaseStore`:** An `ObservableObject` that owns an array of `CaseRecord` structs. Each `CaseRecord` holds: receipt number, optional nickname, last known status string, and last checked timestamp. Persisted to `UserDefaults` as Codable JSON. Shared app-wide as an `@EnvironmentObject`.

- **Network layer — `USCISClient`:** A thin `async/await` wrapper around `URLSession`. POSTs to `https://egov.uscis.gov/casestatus/mycasestatus.do` with `appReceiptNum=<receiptNumber>`, then parses the `<h1>` (status title) and first `<p>` (description) from the HTML response into a `CaseStatus` value. Takes `URLSession` as an injected parameter to support unit testing with mocks.

- **Notification layer — `NotificationManager`:** Requests `UNUserNotificationCenter` permission on first launch. When called with a nickname and new status, fires a local `UNNotificationRequest` immediately. Uses local notifications only — no APNs, no push entitlement, no server required.

- **UI layer:** SwiftUI views driven reactively by `CaseStore` as `@EnvironmentObject`.

---

## Screens

### 1. Case List (Home)
- Cards for each tracked case showing: receipt number, nickname (if set), status text, last-checked timestamp.
- Nav bar: "+" button (add case), refresh button (checks all cases).
- Inline error banner if a network error occurs during refresh; last known status is retained.

### 2. Add Case Sheet
- Two fields: receipt number (required, validated against USCIS format — 3-letter prefix from `{IOE, MSC, EAC, WAC, LIN, SRC, NBC}` followed by 10 digits, e.g. `IOE1234567890`), nickname (optional).
- "Check & Save" button: fetches status immediately to validate the receipt number before saving.
- Inline field error shown for invalid receipt number format.

### 3. Case Detail View
- Tapped from a case card.
- Shows full status description, receipt number, last-checked time.
- Per-case refresh button.
- Delete option (swipe or button) to remove the case.

---

## Data Flow

Refresh is triggered manually by the user (refresh button on case list or per-case refresh in detail view). The app also triggers a refresh automatically when it comes to the foreground after being backgrounded, so status is fresh each time the user opens the app.

On each refresh:

1. `CaseStore.refreshAll()` iterates each `CaseRecord` and calls `USCISClient.fetchStatus(receiptNumber:)`.
2. If the returned status differs from `lastStatus`, `CaseStore` updates the record and calls `NotificationManager.notify(caseNickname:newStatus:)`.
3. `NotificationManager` fires a local notification immediately.
4. `CaseStore` publishes changes; SwiftUI views re-render automatically.

---

## USCIS API

- **Endpoint:** `POST https://egov.uscis.gov/casestatus/mycasestatus.do`
- **Body param:** `appReceiptNum=<receiptNumber>`
- **Parsing:** Extract `<h1>` tag content (status title) and first `<p>` tag content (description) from HTML response.
- No API key or authentication required.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid receipt number format | Inline field error in Add Case sheet; no network call made |
| Network error / timeout | Inline error banner on case list; last known status and timestamp retained |
| USCIS returns unrecognizable response | Status shown as "Unable to retrieve status"; no crash |

---

## Testing

- `USCISClient` accepts an injected `URLSession` for unit testing with mocks.
- Unit tests cover: receipt number format validation, HTML parsing for known status formats, status-change detection logic in `CaseStore`.
- Manual testing covers the UI golden path (no UI test suite needed for this scope).

---

## Out of Scope

- Background periodic checks (user checks on demand)
- Login / authenticated my.uscis.gov access
- Android / cross-platform support
- Case history / timeline beyond current status
