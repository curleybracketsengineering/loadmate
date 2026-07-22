# Lyneqo Caravan & Motorhome iOS Submission Test Document

## Build Information
- **App Name:** Lyneqo Caravan & Motorhome
- **Platform:** iOS
- **Build Type:** App Store submission build
- **Tester:** Apple App Review / QA

## 1) Setup

### Device and OS
- iPhone running a currently supported iOS version.
- Stable internet connection (Wi-Fi or cellular).

### Installation
1. Install the submitted TestFlight/App Store review build.
2. Launch the app from the Home Screen.
3. If prompted, allow required permissions (if any are requested by the app).

### Expected Result
- App installs successfully and opens without crash.
- Initial screen renders correctly and remains responsive.

## 2) Loading Flow Validation

### Goal
Confirm that the core loading workflow can be created, updated, and completed without errors.

### Steps
1. Open the app and navigate to the primary loading workflow screen.
2. Create a new load entry using valid sample details.
3. Save the entry.
4. Re-open the saved entry and update at least one field (for example: notes, status, or item details).
5. Save changes and return to the list/dashboard view.
6. Confirm the new/updated load appears correctly in the list.
7. Mark the load as completed (or final state), if supported.

### Expected Result
- New load entry is created successfully.
- Edits persist after navigating away and returning.
- Updated values display correctly in list/detail views.
- No duplicate entries or data loss occurs.

## 3) Functional Testing Checklist

### Core Checks
- App launches to the expected initial screen.
- Main navigation works across all primary screens.
- Create, edit, and complete actions succeed for loading workflow.
- Data remains consistent after app background/foreground transitions.
- No blocking error alerts appear during normal usage.

### Basic Reliability Checks
1. Put the app in background, then return to foreground.
2. Force close and relaunch the app.
3. Verify recently saved load data is still present.

### Expected Result
- App remains stable and responsive.
- Previously saved data is retained after relaunch.
- No crashes or freezes during the above checks.

## 4) Known Notes for Review
- No special hardware accessories are required.
- No external login credentials are required for basic functional review, unless otherwise provided in App Store Connect notes.

## 5) Pass Criteria
The build is considered verified for submission if:
- Setup completes with successful install and launch.
- Loading workflow (create/edit/view/complete) works end-to-end.
- App remains stable during basic reliability checks.
