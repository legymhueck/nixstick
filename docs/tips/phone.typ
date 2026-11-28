// Phone (Pixel 6, 1&1) -- printable cheat sheet: dial codes, settings paths and
// ADB commands to check calls (VoLTE, Wi-Fi calling) and debloat state.
// Build: typst compile docs/tips/phone.typ docs/tips/out/phone.pdf  (out/ is git-ignored;
// mkdir -p docs/tips/out first, or <leader>re in Neovim)

#set document(title: "Phone checks")
#set page(paper: "a4", margin: (x: 2cm, y: 2cm), numbering: "1 / 1")
// Carlito/JetBrains Mono (TrueType): the Kyocera FS-3820N fails on Typst's default Libertinus (CFF fonts).
#set text(font: "Carlito", size: 10.5pt, lang: "en")
#show raw: set text(font: ("JetBrains Mono NL", "DejaVu Sans Mono"))
#set par(justify: true)
#set heading(numbering: none)
#show heading.where(level: 1): set text(size: 18pt)
#show heading.where(level: 2): it => block(above: 1.3em, below: 0.6em, text(size: 12.5pt, it.body))
#show raw.where(block: true): it => block(
  width: 100%,
  inset: 8pt,
  radius: 3pt,
  stroke: 0.5pt + luma(170),
  fill: luma(245),
  it,
)

#let keys(..rows) = table(
  columns: (auto, 1fr),
  stroke: none,
  inset: (x: 4pt, y: 3pt),
  fill: (_, y) => if calc.odd(y) { luma(246) },
  ..rows.pos().flatten(),
)

= Phone checks

Pixel 6, Android 17, SIM from 1&1 (it roams on Vodafone where 1&1 has no own
cell). Google's updates for the Pixel 6 ended in October 2026; the last
security patch is 2026-10-05. Language: English (Germany) = English menus with
German formats (section 2).

== 1. Dial codes (type them in the Phone app)

#keys(
  [`*#*#4636#*#*`], [Testing menu. *Phone information* → ⋮ (top right) → *IMS service status* shows whether VoLTE and Wi-Fi calling work (section 3).],
  [`*#06#`], [Shows the IMEI (needed for a lost phone or a SIM swap).],
  [`*#21#`], [Is every call forwarded? (unconditional call forwarding)],
  [`*#61#` / `*#62#` / `*#67#`], [Forwarding when you don't answer / are unreachable / are busy (usually to the voicemail).],
  [`*#43#`], [Is call waiting on?],
  [`##002#`], [Delete *all* call forwarding (voicemail too). Only if calls end up somewhere strange.],
)

== 2. Settings paths

#keys(
  [Wi-Fi calling], [Settings → Network and Internet → SIMs → 1&1 → *Wi-Fi Calling*: "Use Wi-Fi calling" on, "Calling preference" = *Call over Wi-Fi* (prefer Wi-Fi).],
  [VoLTE], [No switch: 1&1 keeps it always on, so Android hides it. Check it in the IMS status instead.],
  [Network type], [Same page → *Preferred network type* = 5G (recommended).],
  [2G protection], [Same page → *2G network protection* on (2G stays allowed for emergency calls).],
  [Language], [Settings → System → Languages → *English (Germany)* first, Deutsch second (keyboard spell check). Change the order with the ⋮ next to a language.],
  [Formats], [Same page → Regional preferences: Region *Germany*, Temperature *Celsius*, Measurement system *Metric* (set it explicitly, "Use default" is not enough), First day of week *Monday*. Date dd.mm.yyyy, 24 h and 1.234,5 come from the region.],
)

== 3. IMS status: what it should say

#table(
  columns: (auto, auto, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Line*], [*Expected*], [*Meaning*],
  [IMS registration], [Registered], [Phone is logged in to the call service of 1&1.],
  [Voice over LTE], [Available], [VoLTE works.],
  [Voice over Wi-Fi], [Available at home], [Wi-Fi calling works on this Wi-Fi.],
  [UT interface], [Available], [Call forwarding codes (section 1) work.],
)

*At school (Wi-Fi "GymHueck") Voice over Wi-Fi says "Unavailable".* That is
normal: the school network blocks the encrypted tunnel to 1&1 (IPsec, UDP ports
500 and 4500). Calls then go over LTE automatically. On the home Fritz!Box it
should register; a small Wi-Fi-calling icon appears next to the signal bars.

If it says "Not registered": switch airplane mode on and off once, wait a
minute, check again.

== 4. Connecting from the stick (ADB)

On the phone once: Settings → About phone → tap *Build number* 7 times →
System → Developer options → *USB debugging* on. Plug in, tap *Allow* on the
phone. `,` (comma) runs a program from nixpkgs without installing it.

```sh
, adb devices                          # "device" = ok, "unauthorized" = tap Allow
, scrcpy --no-audio                    # show and control the phone screen in a window
, adb exec-out screencap -p > s.png    # one screenshot
```

== 5. Checking calls over ADB

```sh
# open the testing menu (then ⋮ → IMS service status on the phone)
, adb shell am start -n com.android.phone/.settings.RadioInfo
# which Wi-Fi is the phone on?
, adb shell dumpsys wifi | grep -m1 -o 'mWifiInfo SSID: [^,]*'
# Wi-Fi calling tunnel: "IN BRINGUP" for a long time = the Wi-Fi blocks it
, adb shell dumpsys activity service com.google.android.iwlan | grep -A2 'APN: ims'
# does 1&1 allow VoLTE / Wi-Fi calling? (the block after "Phone Id = 0")
, adb shell dumpsys carrier_config \
    | grep -E 'Phone Id|carrier_(volte|wfc_ims)_available_bool'
# re-register IMS: airplane mode on and off
, adb shell cmd connectivity airplane-mode enable; sleep 5
, adb shell cmd connectivity airplane-mode disable
```

Which package does what:

#keys(
  [`com.shannon.imsservice`], [VoLTE, Wi-Fi calling, emergency calls (modem). *Never disable.*],
  [`com.google.android.ims`], [Carrier Services: only RCS ("chat features" in Google Messages). Can be disabled without breaking calls.],
  [`com.google.android.iwlan`], [The Wi-Fi calling tunnel. Never disable.],
)

== 6. Debloating over ADB

*Android 17 refuses* `pm uninstall --user 0` *for system apps without root*
("only root can delete system app for a particular user"). System apps can only
be *disabled*; apps from the Play Store or F-Droid can still be uninstalled.

```sh
, adb shell pm list packages -3        # apps you installed
, adb shell pm list packages -s        # system apps
, adb shell pm list packages -d        # disabled apps
, adb uninstall <package>              # uninstall an app you installed
# system app: drop its Play update, disable it, clear its data
, adb uninstall <package>              # on a system app: removes only the update
, adb shell cmd package uninstall-system-updates <package>   # the same, explicitly
, adb shell pm disable-user --user 0 <package>
, adb shell pm clear <package>
, adb shell pm enable <package>        # undo a disable
```

Never touch: Play Services (`com.google.android.gms`), Play Store, `com.android.*`
core packages, Phone, Messages, anything with _ims_, _telephony_, _carrier_,
_iwlan_ or _provision_ in its name, and the Samsung/Shannon modem services.

== 7. Linux Terminal (Debian)

Android's own terminal app (*Terminal*, `com.android.virtualization.terminal`) runs a real Debian 13 in a small VM:
8 cores, about 1 GB RAM, `apt` with all Debian packages. Set up on 2026-11-26 with `docs/tips/phone-debian-setup.sh`
(updates, automatic security updates, tools, English with German formats, Berlin time, Tailscale, SSH key). The
VM does *not* use the phone's Tailscale connection, so it runs its own: device *pixel-debian*. Termux stays for
quick jobs (starts at once, uses the phone's network).

#keys(
  [`ssh rpi`], [The Pi (key `droid@pixel-debian` is in `authorized_keys` of `michael`).],
  [`/mnt/shared`], [The phone's storage (`phone` jumps there), e.g. `/mnt/shared/Download`.],
  [`update`], [`apt update` + `full-upgrade` + `autoremove`.],
  [`tailscale status`], [Tailscale inside the VM; log in again: `sudo tailscale up --hostname=pixel-debian`.],
  [Tools], [git, rsync, curl, tmux, htop, ncdu, Neovim (`vim`), ripgrep (`rg`), `fd`, jq, Python 3 with venv/pip.],
)

Run the setup again (it is safe to repeat), from the stick with the phone on ADB:

```sh
, adb push docs/tips/phone-debian-setup.sh /sdcard/Download/vm/setup.sh
# in the terminal:  bash /mnt/shared/Download/vm/setup.sh   (log: Download/vm/setup.log)
```

== 8. Calendar and tasks (Nextcloud on the Pi)

Own appointments and tasks live in Nextcloud on the Pi (calendars *Schule*, *Privat*, *Eltern*, *Familie*;
task lists *Aufgaben*, *Tickets*). DAVx5 syncs them into Android; *Fossify Calendar* shows the appointments,
*Tasks.org* the tasks (both from F-Droid). The Nextcloud app is not needed. Everything runs over Tailscale, so
Tailscale must be connected.

*DAVx5 account (once).* Install Tasks.org first, then DAVx5 offers task sync. DAVx5 → *Add account* →
*Nextcloud* → server address `https://rpi.bone-vibes.ts.net` → *Login* → log in in the browser → *Grant access*
→ close the tab → account name `Nextcloud` → *Finish*. In the account, tab *CalDAV*: switch on *Aufgaben*,
*Eltern*, *Familie*, *Privat*, *Schule*, *Tickets* (not *Archiv*, not *Contact birthdays*; the CardDAV tab stays off, contacts come from Google) → *Synchronise now*.
If DAVx5 asks for permissions: *Manage permissions* → allow calendar and tasks (over ADB:
`pm grant at.bitfire.davdroid android.permission.WRITE_CALENDAR`, the same for `READ_CALENDAR`,
`org.tasks.permission.READ_TASKS`, `org.tasks.permission.WRITE_TASKS`). The login creates its own app password
(Nextcloud → Settings → Security lists it as DAVx5). Tailscale must be connected, otherwise DAVx5 says "Unable
to resolve host".

*Fossify Calendar.* Settings → *CalDAV sync* on → tick the four Nextcloud calendars. Until the old appointments
have moved, the own Google calendars are ticked too (`michael.lehnen@gmail.com`: main calendar, Schule,
Familie, Feiertage; `le.gymhueck@gmail.com`: GymHueck); untick them there later. Settings → *Default calendar* =
*Privat (Nextcloud)*, so new appointments never land in Google. Birthdays: ⋮ → *Add contact birthdays* → *Add
new birthdays automatically* on (they come from the contacts; Google's own birthday calendar is not visible to
other apps). Colors per calendar: Settings → *Manage event types*. Everything here is free, nothing to buy.

*Tasks.org.* The lists *Aufgaben* and *Tickets* appear under *Nextcloud* in the side menu; default list for new
tasks (Settings → Task defaults) is *Aufgaben*. Sync and widgets are free; the paid upgrade only adds
Tasks.org's own cloud, sharing and mail-to-task.

*Keep it syncing.* DAVx5 and Tailscale are exempt from Data saver and battery optimisation (Settings → Apps →
the app → *Mobile data* → *Unrestricted data usage*, *App battery usage* = Unrestricted; over ADB:
`cmd netpolicy add restrict-background-whitelist <uid>`, `dumpsys deviceidle whitelist +<package>`). Before that,
Tailscale went to sleep and DAVx5 could not reach the Pi.

*School page (home screen page 2).* Long-press the Thunderbird widget → *Remove* (only the widget; the app
stays, it is the mail program for the LOGINEO mailboxes and the tickets). Long-press an empty spot → *Widgets* →
Fossify Calendar → *Event list* (or *Monthly*) → drop it at the top and pull it to full width and about two
thirds of the height. Optional below it: Tasks.org widget with the list *Tickets*. In the bottom row the school
apps: Moodle, Untis, Wörterbücher, Thunderbird.

*Fixed dock.* Home settings → Suggestions → *Suggestions on Home screen* off, otherwise Google swaps suggested apps into free dock slots. Adding a widget that will not drop: long-press the app icon → *Widgets* → tap the widget → *Add* (Fossify then asks for its settings, confirm with *OK*).

== 9. Changes so far

#table(
  columns: (auto, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Date*], [*Change*],
  [before 2026-11],
  [Disabled: YouTube Music, Verizon and OMA-DM carrier packages, Glasses, Supervision and others. Removed: Samsung Health, Galaxy Wearable, Private Space.],

  [2026-11-26],
  [ReVanced (YouTube, GmsCore, Manager) uninstalled, stock YouTube enabled again. SafetyCore uninstalled (Google may push it again: check `pm list packages | grep safetycore`). YouTube Music: Play update removed, disabled, data cleared. Carrier Services (`com.google.android.ims`) enabled again. Checked: VoLTE registered, Wi-Fi calling on with "prefer Wi-Fi", blocked only on the school Wi-Fi. Uninstalled Google Fit, Lens (the Files scanner runs in Play Services and still works) and Google One. Language English (Germany) with metric, Celsius, Monday. Uninstalled Fitbit and the Samsung Galaxy Wearable leftovers (Accessory, Gear plugin; the `com.samsung.slsi.telephony.*` modem packages stay). Feeder (RSS) installed from F-Droid as the Google News replacement; on the stick: NewsFlash. Shared feed list `~/filen/feeds.opml` (24 feeds, incl. video feeds of Tagesschau, Tagesthemen, 100 Sekunden, heute, heute journal). Uninstalled Google News and BR24 (no working feed any more). Photos moved to Immich: Immich app backs up Camera, Screenshots, WhatsApp, Markup (144/144, notifications allowed for background backup); Google Photos: Play update removed, disabled, data cleared (`pm enable com.google.android.apps.photos` undoes it). The cloud library at photos.google.com is not emptied yet. Private DNS: leftover host name `dns0.eu` (service ended 2025) removed, mode stays Automatic (`settings delete global private_dns_specifier`); DNS comes from Tailscale (Pi-hole). Tailscale exit node `rpi` is preselected but off; the stale "DNS unavailable" warning cleared by reconnecting. Uninstalled (unused for months): DroidFS, NetAnalyzer, Network widget, ADAC Pannenhilfe, Libby, Google Translate (DeepL stays). Huawei AI Life + HMS Core stay for the FreeBuds 4i (noise cancelling, gestures, firmware). Caches trimmed (`pm trim-caches 999G`, about 140 MB). Removed never-opened stubs: Obtainium (Play/GitHub build; the F-Droid build stays), GPS Status 1, Clipious, one Chromium web app. Stores checked by installer (`dumpsys package <pkg> | grep installerPackageName`): F-Droid installed and updates Syncthing-Fork, Feeder, IronFox, Droid-ify and Obtainium; Accrescent, Droid-ify and Obtainium install none of the current apps; Termux (0.118.3, 2025-06), NewPipe and RustDesk were sideloaded and get no automatic updates. Accrescent uninstalled: its only app in use, IronFox, comes from F-Droid (IronFox repo, updated 2026-11-19). Droid-ify and Obtainium uninstalled too (no app was installed by them); F-Droid is the only store besides Play. Charging limited to 80 % (Settings → Battery → Charging optimisation; `settings put secure charge_optimization_mode 1`, 0 = Adaptive Charging). Developer option "Mobile data always active" off (`settings put global mobile_data_always_on 0`). Wi-Fi scanning off (Settings → Location → Location services → Wi-Fi scanning; `settings put global wifi_scan_always_enabled 0`, Bluetooth scanning was already off). pCloud uninstalled (Filen is the cloud; it was exempt from battery optimisation). Uninstalled "Vocabulary" (`com.nomtek`, English vocabulary trainer from 2022, not opened this year). Second profile `legymhueck` (user 10, full secondary user, last used 2026-10-25) deleted with all its apps and data (`pm remove-user 10`); only the main profile is left. Ente Auth uninstalled (its codes stay in the Ente account, web: auth.ente.io). Google Home uninstalled. Keep: GMX and web.de apps (they confirm logins for those accounts, Thunderbird cannot replace them). Termux 0.118.3 is F-Droid's current stable build and F-Droid-signed, so F-Droid updates it in place; its packages: `pkg upgrade` inside Termux. Google system apps not opened in 2026: Play update removed (`cmd package uninstall-system-updates`), disabled, data cleared: Recorder, Google TV, ARCore, Ambient streaming, Pixel relationships, AI icons, Pixel Stand (dreamliner), Emoji wallpaper, Magic Portrait, Creative Assistant, BetterBug, Now Playing, Tips (Android Auto stays). Uninstalled heute, WDR, 7TV (Feeder has the broadcast video feeds). About 640 MB freed. Linux Terminal enabled and set up (section 7): Debian 13.7, Tailscale device pixel-debian, key `droid@pixel-debian` on the Pi (`ssh rpi` checked).],
  [2026-11-28],
  [Calendar and tasks from Nextcloud on the Pi (section 8): Fossify Calendar and Tasks.org installed from F-Droid; DAVx5 account `Nextcloud` (four calendars, lists Aufgaben and Tickets); the old DAVx5 account `michael.lehnen@gymhueck.de` (LOGINEO, 0 calendars) deleted. DAVx5 and Tailscale exempt from Data saver and battery optimisation. Fossify shows the Nextcloud calendars plus the own Google calendars until the move, default calendar Privat, contact birthdays added.],
  [2026-11-28 (later)],
  [Brave uninstalled; its 1909 bookmarks exported first to `~/filen/privat/lesezeichen/brave-handy-2026-11-28.html` (Brave → Bookmarks → ⋮ → Export bookmarks). Home screen suggestions in the dock off. Fossify Calendar event list widget on home page 2. Google Tasks uninstalled (Tasks.org replaces it; tasks kept in the Google account stay there).],
)
