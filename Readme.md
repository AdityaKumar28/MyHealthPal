# MyHealthPal

A tiny, privacy‑friendly iOS app that shows your daily **Steps**, **Heart Rate**, and **Active Energy**, and lets you **scan food** with your camera to quickly log estimated calories using Google **Gemini**. It’s designed for personal use and open‑sourced (no App Store distribution).

---

## Table of Contents

- [Features](#features)
- [Screens & UX](#screens--ux)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
  - [HealthKit Permissions](#healthkit-permissions)
  - [Getting a Google Gemini API Key](#getting-a-google-gemini-api-key)
  - [Adding Your API Key in the App](#adding-your-api-key-in-the-app)
  - [Info.plist Entries](#infoplist-entries)
- [How Food Scanning Works (Gemini)](#how-food-scanning-works-gemini)
- [Building & Running](#building--running)
- [Troubleshooting](#troubleshooting)
- [Privacy & Security](#privacy--security)
- [Roadmap / Ideas](#roadmap--ideas)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Daily Health Metrics**
  - Steps (`HKQuantityTypeIdentifier.stepCount`)
  - Heart Rate (`HKQuantityTypeIdentifier.heartRate`) — Apple Watch required
  - Active Energy (`HKQuantityTypeIdentifier.activeEnergyBurned`)

- **Date Picker**
  - Graphical calendar sheet to pick any day; the screen refreshes to show metrics and logs for that date.

- **Food Scanning**
  - Tap the **camera** to snap your meal and get a **calorie estimate** + **short label** via Google Gemini.
  - If the image isn’t usable, the app shows a **scan failed** alert and doesn’t create a log.

- **Log Management**
  - Each log shows **calories** and **title/notes**.
  - **Edit** title/calories/notes or **Delete** a log (swipe actions).

- **Calorie Summary**
  - Displays **Intake**, **Spent** (active energy), and **Net** with a **Deficit/Surplus** tag.

- **Local Key Storage + Validation**
  - Paste your Gemini key in **Settings → AI Key**.
  - Tap **Save** to **validate** the key first; if valid, it’s stored locally.

- **Graceful Fallbacks**
  - If a metric isn’t available, the UI shows **0** instead of failing.

---

## Screens & UX

- **Home**  
  Title, selected date (under the title), metrics, calorie summary, and **Logged Foods** list.  
  Top‑right toolbar: **Calendar** (open date picker), **Camera** (scan), **Refresh**, **Settings**.

- **Settings → AI Key**  
  Paste / Clear / **Show‑Hide** the key, **Save** (validates before storing), and brief steps to obtain a Gemini key.

- **Food Edit Sheet**  
  Change title/description/calories. Save or cancel.

---

## Requirements

- **Xcode 15+**
- **iOS 16.0+** (uses `NavigationStack`, Swift Concurrency, graphical `DatePicker`)
- **Physical iPhone** for HealthKit & camera
- **Apple Watch** for continuous heart rate
- **Google Gemini API key** (free tier available)

---

## Quick Start

1. **Clone** this repo.
2. Open `MyHealthPal.xcodeproj` in **Xcode 15+**.
3. Ensure the target **Bundle Identifier** is unique (needed to run on device).
4. Select your **iPhone** device and press **Run** (`⌘R`).
5. Grant **Health** and **Camera** permissions on first launch.
6. Tap the **gear** → **AI Key** → Paste your Gemini key → **Save** (the app validates before storing).

> Tip: Open Apple’s **Health** app to confirm Steps / Active Energy / Heart Rate have data. Heart rate needs Apple Watch and a few minutes of data.

---

## Project Structure

```
MyHealthPal/
├── AI/
│   ├── AIKeyStore.swift            # Shared store for provider keys (UserDefaults)
│   └── AISettingsView.swift        # Paste/Clear/Show-Hide/Save (validation) + instructions
├── Assets/
│   ├── AppIcon.appiconset          # App icons (light/dark/tinted variants if provided)
│   └── [other assets]
├── ContentView.swift               # Home, calendar sheet, logs, unified alerts, navigation
├── FoodAnalysisService.swift       # Calls Gemini, strict JSON, parses to FoodAnalysisResult
├── FoodAnalysisError.swift         # Error enum for analysis failures
├── FoodLog.swift                   # Model for logged foods
├── FoodEditSheet.swift             # Edit title/description/calories
├── FoodScannerView.swift           # Camera capture → returns UIImage
├── HealthDataViewModel.swift       # State for steps/HR/energy + fetching per date
├── HealthKitManager.swift          # HealthKit authorization + queries
├── MyHealthPalApp.swift            # App entry point (NavigationStack root)
└── Info.plist                      # Permissions and (optional) ATS
```

---

## Configuration

### HealthKit Permissions

On first run, iOS asks to allow **read** access to:

- **Step Count**
- **Heart Rate**
- **Active Energy Burned**

Change later in **Health app → Sources → MyHealthPal**.  
Heart rate typically comes from **Apple Watch**; without a watch, HR may be 0.

### Getting a Google Gemini API Key

1. Go to **https://aistudio.google.com/** and sign in.
2. Create/select a project and click **Get API key**.  
   (Alternatively: **Google Cloud Console → APIs & Services → Credentials**.)
3. Create an **API key**. Optionally restrict it.
4. Ensure **Generative Language API** is **enabled** for that project.

### Adding Your API Key in the App

- Run the app, tap **gear → AI Key**.
- Paste your key, optionally toggle **Show/Hide**.
- Tap **Save**:
  - App hits `GET https://generativelanguage.googleapis.com/v1beta/models?key=...` to **validate**.
  - If valid, it stores to `UserDefaults` and pops a success alert.

> Storage is `UserDefaults` for simplicity. Swap to **Keychain** for stronger protection if you prefer.

### Info.plist Entries

These must exist in your target’s Info.plist:

```xml
<!-- Camera -->
<key>NSCameraUsageDescription</key>
<string>To scan your food using the camera.</string>

<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>To read your steps, heart rate, and calories.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>To save your food intake and nutrition.</string>

<!-- (Optional) ATS example if you customize networking.
     HTTPS to generativelanguage.googleapis.com does NOT require an exception. -->
<!--
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>generativelanguage.googleapis.com</key>
    <dict>
      <key>NSIncludesSubdomains</key><true/>
      <key>NSTemporaryExceptionMinimumTLSVersion</key><string>TLSv1.2</string>
    </dict>
  </dict>
</dict>
-->
```

> **Build error tip:** If you see **“Multiple commands produce … Info.plist”**, you’re generating Info.plist twice (once by Xcode build settings and once as a physical file). See [Troubleshooting](#troubleshooting).

---

## How Food Scanning Works (Gemini)

- The app sends your **photo** + a strict **prompt** to Gemini’s *Generate Content* endpoint.
- The model must respond with **one line of JSON** (no markdown):
  - Success: `{"calories": <integer>, "label": "<short name>"}`  
  - Failure: `{"error": "ErrorInScanning"}`
- The app parses that JSON into `FoodAnalysisResult` and opens an **edit sheet** so you can adjust.

**Endpoints used**

- **Validate key (Settings screen)**  
  `GET https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_KEY`

- **Analyze image**  
  `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=YOUR_KEY`

---

## Building & Running

1. Open in **Xcode 15+**.
2. Select the **MyHealthPal** scheme and your connected **iPhone**.
3. Press **Run** (`⌘R`).
4. Grant **Health** & **Camera** permissions.
5. Add your **Gemini API key** under **Settings → AI Key**.

### App Icons

- Place icons in **Assets.xcassets → AppIcon**.
- Include all iPhone sizes. Optional: light/dark/tinted variants.

---

## Troubleshooting

### “No data available for the specified predicate”
- Select a **date that has data** in Health (Steps/Active Energy reset daily).
- Heart Rate requires **Apple Watch**.
- The app falls back to **0** to stay responsive.

### Camera not opening
- Check **Settings → Privacy → Camera** and allow **MyHealthPal**.

### AI key alert not showing / navigation issues
- The app uses a unified SwiftUI alert and `NavigationStack` push to settings (iOS 16+).

### Ambiguous use of `init()` in `MyHealthPalApp.swift`
- Usually a duplicate symbol (e.g., two `ContentView`s). Keep entry minimal:
```swift
@main
struct MyHealthPalApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### “Multiple commands produce … Info.plist”
- You’re generating Info.plist twice. Choose **one** approach:
  - **Approach A (recommended)**: Keep your **Info.plist file**.  
    In **Build Settings**: set **Generate Info.plist File = No**.
  - **Approach B**: Let Xcode generate it.  
    Set **Generate Info.plist File = Yes** and **remove** your manual Info.plist (and from *Copy Bundle Resources*).

### Calendar warning
- “UICalendarView's height is smaller …” is harmless with the current sheet layout.

### Validation/network errors when saving key
- Confirm the **key** is correct and **Generative Language API** is **enabled** for the project.
- Ensure network access isn’t blocked by VPN/content filters.

---

## Privacy & Security

- API key is stored **locally** in `UserDefaults` (no server). Consider **Keychain** for stronger protection.
- Only the photo you scan is sent to Google’s API. No analytics, ads, or tracking.
- Health data is **read‑only** and never leaves the device.

---

## Roadmap / Ideas

- Persist food logs (Core Data/SQLite) instead of in‑memory.
- Nutrients/macros estimation and favorites.
- Alternate AI providers and provider picker.
- Widgets / Live Activities for today’s summary.
- Export logs to CSV.

---

## Contributing

PRs welcome! Please keep it SwiftUI‑first with Swift Concurrency, and prefer **Swift Package Manager** for dependencies.

1. Fork → create a feature branch → open a PR.
2. Keep UI/UX consistent with the current look.
3. Don’t commit secrets.

---

## License

MIT — see `LICENSE`. No warranty.

---

### Acknowledgements

- Apple **HealthKit**, **SwiftUI**
- Google **Gemini** (Generative Language API)
