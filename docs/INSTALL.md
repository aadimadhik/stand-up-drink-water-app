# Installing DeskBreak on your iPhone (free Apple ID)

No App Store, no paid developer account. You need a Mac with Xcode and a USB cable.

---

## One-time setup

1. **Install Xcode** from the Mac App Store (Xcode 15 or newer). Open it once and
   let it finish installing components.

2. **Add your Apple ID** — Xcode → Settings → Accounts → **+** → Apple ID.
   Sign in with your normal Apple ID. Xcode creates a free "Personal Team" for you.

3. **Clone and open the project:**
   ```
   git clone https://github.com/aadimadhik/stand-up-drink-water-app.git
   cd stand-up-drink-water-app
   open DeskBreak.xcodeproj
   ```

4. **Set your team and bundle ID.** Select the **DeskBreak** target →
   **Signing & Capabilities**:
   - Tick *Automatically manage signing*
   - **Team**: your name (Personal Team)
   - **Bundle Identifier**: change `com.aadim.DeskBreak` to something unique to
     you, e.g. `com.<yourname>.DeskBreak`. If Xcode says the identifier is
     unavailable, change it again — Apple requires it to be globally unique.

5. **Connect your iPhone** by cable, unlock it, tap **Trust This Computer**.

6. **Pick your iPhone** in the run destination menu at the top of the Xcode window
   (not a Simulator — notification sounds and Focus behave differently there).

7. **Press ⌘R.** The build installs and launches on the phone.

8. **Trust the developer certificate** on the iPhone, the first time only:
   Settings → General → **VPN & Device Management** → tap your Apple ID →
   **Trust**. Then launch DeskBreak from the Home Screen.

9. **Allow notifications** when the app asks. The whole app is notifications —
   denying this leaves you with a stopwatch.

---

## The 7-day expiry

A free Apple ID signs the app for **7 days**. After that it refuses to launch with
"Unable to Verify App".

**The fix:** connect the iPhone to the Mac, open the project, press **⌘R** again.
It takes under a minute, and your settings, session and daily counts survive
because they live in the app's own storage.

Other limits of a free account: 3 sideloaded apps at a time, 10 device
registrations per week.

**If the weekly ritual gets annoying**, the $99/year Apple Developer Program
extends the signing to a full year and lets you install over the air via
TestFlight. Nothing in the code changes — it's a signing setting.

---

## What a free account cannot do

**Time Sensitive Notifications is a paid-account capability.** DeskBreak asks for
it at runtime (`interruptionLevel = .timeSensitive`), but iOS ignores the request
without the entitlement, so on a free build a Focus mode will silence your
reminders.

**Work around it once, and it behaves identically:**

> Settings → **Focus** → your Focus (e.g. Work) → **Apps** → **+** → DeskBreak

That allow-list is per Focus mode, so add it to every Focus you use while at your
desk. Do this before you rely on the app for a full working day.

---

## Verifying it actually works

Before trusting it with a real day, run these. They take about ten minutes and
each one checks a different failure mode.

1. **Basic delivery.** Settings → both intervals to **5 min** → Start → lock the
   phone. Both reminders arrive, with the two different tones.
2. **Focus.** Turn on a Focus mode and repeat. If nothing arrives, you skipped the
   allow-list step above.
3. **Force-quit.** Start a session, swipe the app away in the app switcher.
   Reminders still arrive — this is the proof that nothing depends on the app
   running.
4. **Snooze.** From the Lock Screen, swipe the alert and tap **Snooze 5 min**.
   A fresh alert arrives 5 minutes later.
5. **Done button.** Tap **Drank it** on an alert, then open the app. The
   "done today" count went up by one.
6. **Restart.** Start a session, restart the phone, wait for the next reminder.
   It still arrives, and the app shows the correct countdown when reopened.
7. **Long session.** Set 8 hours with 45/50 min intervals, Start, then check
   Settings → *Queued reminders*. It should read comfortably under 64.

---

## Regenerating project files

The Xcode project, the alert tones and the app icon are all generated, so nothing
binary is hand-maintained. From the repo root:

```
python3 scripts/generate_sounds.py      # rebuild the .wav tones
python3 scripts/generate_appicon.py     # rebuild the 1024px app icon
python3 scripts/generate_xcodeproj.py   # rebuild DeskBreak.xcodeproj from disk
```

Re-run the last one after adding or deleting a Swift file. Your signing team is
stored in Xcode's user data, not in the project file, so regenerating does not
lose it — but you will need to re-pick the Team and Bundle Identifier if you had
changed them in the project itself.

## Adding your own alert tone

Notification sounds must live in the app bundle and be **30 seconds or less** in
`.wav`, `.aiff` or `.caf` (linear PCM — MP3 is rejected). iOS offers no way to
reach your iPhone's built-in ringtones.

```
afconvert -f WAVE -d LEI16@44100 -c 1 mytone.mp3 DeskBreak/Resources/Sounds/mytone.wav
```

Then add an `AlertSound` entry in `DeskBreak/Services/SoundCatalog.swift` and
re-run `scripts/generate_xcodeproj.py`.
