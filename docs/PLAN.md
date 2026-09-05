# DeskBreak — Plan (Water + Stand-Up Reminder, iOS)

Personal-use iOS app. Not for App Store distribution.

---

## 1. The one architectural decision that matters

**The app does not run a background timer. It pre-schedules local notifications and then does nothing.**

iOS suspends apps within seconds of the screen locking. Any design that says "the app keeps
counting in the background and fires an alert" is wrong on iOS and will fail silently. The
correct model:

1. User taps **Start**.
2. App computes every reminder moment for the session and hands them to `UNUserNotificationCenter`.
3. App is suspended/killed — **the system**, not the app, delivers the alerts on time.
4. User taps **Stop/Pause** → app removes pending notification requests.

This is why the "lock the phone and forget it" requirement works without any background modes,
audio hacks, or battery drain.

### Two scheduling strategies

| | Repeating trigger | Pre-scheduled batch (**chosen**) |
|---|---|---|
| API | `UNTimeIntervalNotificationTrigger(interval: X, repeats: true)` | N one-shot triggers |
| Slots used | 2 total | up to ~60 |
| Message text | identical every time | can be varied: "Glass #4 — 1.2 L so far" |
| Work-hours end | can't auto-stop | trivially bounded |
| Cost | none | must be refreshed |

**Decision: pre-scheduled batch.** Schedule a rolling horizon (default 8 h) of discrete
notifications at Start, capped at 55 requests (iOS hard limit is 64 pending per app — going over
means iOS silently drops the oldest). Re-top-up the queue on every `applicationDidBecomeActive`.
Water at 45 min and stand at 50 min over 8 h = ~20 requests. Comfortable.

---

## 2. Hard iOS constraints to accept up front

These are platform limits, not implementation choices. Design around them, don't fight them.

**2.1 You cannot use your iPhone's ringtones (Radar, Marimba, Reflection…).**
There is no public API to read the system ringtone library. `UNNotificationSound(named:)` only
accepts a file that ships inside your app bundle or sits in `Library/Sounds/`.
Constraints on that file: **≤ 30 seconds**, and format **.caf / .aiff / .wav** (linear PCM,
MA4, µ-law or a-law). MP3 is not accepted.

*Workaround that actually gives you "your" tone:* bundle 6–8 short `.caf` files. You can convert
anything (including a tone you like) on a Mac with:
```
afconvert -f caff -d LEI16@44100 -c 1 input.wav Sounds/water_chime.caf
```
Settings screen then offers: System Default, Chime, Marimba-ish, Bell, Water Drop, Bowl, Ping,
Vibrate-only — with a preview button per sound. Water and Stand get **independent** sound
selection so you can tell them apart while looking away from the screen.

**2.2 Focus / Do Not Disturb will swallow reminders** unless you set
`content.interruptionLevel = .timeSensitive`. Add the *Time Sensitive Notifications* capability
in Xcode. Without this, the app is useless during a "Work" Focus — which is exactly when you need it.

**2.3 Notification sound plays once, for a few seconds.** No repeating/escalating alarm without
either (a) Critical Alerts, which require a special Apple entitlement request that personal apps
do not get approved for, or (b) scheduling 3 nudges 60 s apart as a "persistent" mode. Option (b)
is the pragmatic one — make it a toggle.

**2.4 Notification permission is one-shot.** If denied, all you can do is deep-link to Settings.
Ask at first launch with a one-screen rationale, not cold on app open.

**2.5 Silent mode.** A notification sound respects the ring/silent switch. Nothing to do about it
short of Critical Alerts. Note it in the app's onboarding so you don't blame the app.

---

## 3. Scope

### v1 (build this)
- Home: big Start / Pause / Stop control, live countdown to *next* water and *next* stand,
  session elapsed time.
- Settings: water interval, stand interval, sound per reminder type, session length /
  work-hours end, persistent-nudge toggle, quiet-hours toggle.
- Notification actions on the alert itself: **Done** and **Snooze 5 min** (`UNNotificationAction`)
  so you can log without unlocking into the app.
- Local persistence of settings and today's counts.

### v2 (only if v1 sticks)
- Live Activity / Dynamic Island showing the next-break countdown on the Lock Screen.
- Daily/weekly adherence stats.
- HealthKit water logging.
- Apple Watch haptic (the honest best answer for "I didn't notice the alert").

### Explicitly out of scope
Accounts, cloud sync, App Store review, iPad layout, watchOS app in v1.

---

## 4. Technical stack

- **SwiftUI**, iOS 17.0 minimum, Swift 5.9. Single target, no dependencies.
- **UserNotifications** for everything time-related.
- **`@AppStorage` / UserDefaults** for settings — this is a single-user app with ~10 settings;
  SwiftData or Core Data is over-engineering.
- **Xcode 15+** on macOS.

### File layout
```
DeskBreak/
├── DeskBreakApp.swift              // @main, notification delegate wiring
├── Models/
│   ├── ReminderKind.swift          // .water / .stand — titles, bodies, category IDs
│   ├── ReminderSettings.swift      // Codable settings, @AppStorage-backed
│   └── SessionState.swift          // startedAt, isPaused, pausedAt, counters
├── Services/
│   ├── NotificationScheduler.swift // permission, build & schedule batch, cancel, top-up
│   ├── NotificationDelegate.swift  // foreground presentation + Done/Snooze actions
│   └── SoundCatalog.swift          // bundled sound list + AVAudioPlayer preview
├── Views/
│   ├── HomeView.swift              // Start/Pause/Stop, dual countdown rings
│   ├── SettingsView.swift          // intervals, sounds, session length
│   └── SoundPickerView.swift       // per-kind picker with preview
├── Resources/Sounds/*.caf          // 6–8 bundled alert tones
└── Info.plist
```

### Core of the scheduler
```swift
func scheduleSession(kind: ReminderKind,
                     every interval: TimeInterval,
                     from start: Date,
                     until end: Date,
                     sound: UNNotificationSound,
                     maxRequests: Int) {
    var fireDate = start.addingTimeInterval(interval)
    var n = 1
    while fireDate <= end && n <= maxRequests {
        let content = UNMutableNotificationContent()
        content.title = kind.title                    // "Time to drink water"
        content.body  = kind.body(occurrence: n)      // "Glass #4 · 3h 45m at the desk"
        content.sound = sound
        content.interruptionLevel = .timeSensitive    // pierces Focus
        content.categoryIdentifier = kind.categoryID  // enables Done / Snooze buttons
        content.threadIdentifier = kind.rawValue      // groups on Lock Screen

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(
            identifier: "\(kind.rawValue)-\(n)", content: content, trigger: trigger))

        fireDate = fireDate.addingTimeInterval(interval); n += 1
    }
}
```
Pause = `removePendingNotificationRequests` + store remaining offset. Resume = reschedule from now
using the stored offset. Stop = remove all + reset counters.

### Test plan (manual, this is a personal app)
1. Set both intervals to 1 min, Start, lock the phone → both alerts arrive on time with correct,
   distinct sounds.
2. Turn on a Work Focus → alerts still break through (validates `.timeSensitive`).
3. Force-quit the app from the app switcher → alerts still arrive (validates the no-background design).
4. Snooze from the Lock Screen → new alert in 5 min, original not repeated.
5. Set 8-hour session with 45/50 min intervals → `getPendingNotificationRequests` count stays under 64.
6. Restart the phone mid-session → pending notifications survive.

---

## 5. Installing on your iPhone without the App Store

**Prerequisite for every path below: a Mac running Xcode.** There is no supported way to build
and sign an iOS app without macOS. If you don't have one, see Path C.

### Path A — Free Apple ID + Xcode (₹0, recommended to start)
1. Install Xcode from the Mac App Store.
2. Xcode → Settings → Accounts → add your normal Apple ID (no paid enrolment).
3. Open the project → target → Signing & Capabilities → *Automatically manage signing* → pick
   your Personal Team → set a unique Bundle Identifier, e.g. `com.aadim.deskbreak`.
4. Add capability: **Time Sensitive Notifications**.
5. Plug the iPhone in via USB, trust the Mac, select it as the run destination, press **⌘R**.
6. On the iPhone: Settings → General → VPN & Device Management → trust your developer certificate.

Limits: certificate expires in **7 days** — reconnect to the Mac and press ⌘R again to refresh
(settings and data are preserved). Max 3 sideloaded apps at a time, 10 device registrations per week.

### Path B — Paid Apple Developer Program ($99/yr)
Identical steps, but the provisioning profile lasts **1 year**, so no weekly re-signing. Also
unlocks TestFlight (install over the air, 90-day builds, no cable). If this app becomes part of
your daily routine, this is the option that removes the friction. Given you're running several
businesses, $99/yr to stop babysitting a certificate is probably the right trade.

### Path C — SideStore / AltStore (no Mac *after* first setup)
Uses the same free-Apple-ID mechanism, but refreshes the 7-day certificate **wirelessly from the
phone itself**. You still need a computer once to generate a pairing file, and you still need
someone with a Mac to produce the signed `.ipa` in the first place. Realistically: use Path A/B
to build, and SideStore only if the weekly cable ritual becomes annoying.

**Rejected:** enterprise certificates and paid signing services — TOS-violating, revocable, and
they'd be handling your Apple ID.

---

## 6. Risks and blind spots

1. **No Mac = hard blocker.** Confirm this before any code is written. Renting a cloud Mac
   (MacStadium, Scaleway) is possible but a poor fit for a weekly re-sign ritual.
2. **The 7-day expiry is the real adoption risk**, not the code. An app that dies every Monday
   won't build the habit you're trying to build. Budget for Path B.
3. **Alert fatigue.** Two alerts every ~45 min is ~20 interruptions in a working day. Mitigation:
   snooze action, a "deep work" pause, and honest intervals (60/50 rather than 30/25 to start).
4. **You may not build the habit anyway.** The notification is the easy part; the behaviour
   change is the hard part. The Done button + daily count exists so you get feedback, not just nagging.
5. **Cheaper alternatives you should rule out first:** the built-in Clock app's repeating alarms,
   the Apple Watch's Stand ring + Water Reminder shortcuts, or a Shortcuts Personal Automation
   with a time trigger. If one of those covers 80% of the need, building this is a hobby project,
   not a productivity one — which is a fine reason to build it, just be clear which it is.

---

## 7. Build order

1. Xcode project skeleton, bundle ID, signing, deploy an empty app to the phone — **prove the
   install path works before writing features.**
2. Notification permission flow + one hardcoded 60-second reminder.
3. `NotificationScheduler` with the batch algorithm; verify pending count.
4. HomeView with Start/Pause/Stop and dual countdowns.
5. SettingsView with intervals persisted via `@AppStorage`.
6. Bundle the `.caf` sounds; SoundPickerView with preview.
7. Notification actions (Done / Snooze) + daily counters.
8. Run the six manual tests in §4. Ship to yourself.
