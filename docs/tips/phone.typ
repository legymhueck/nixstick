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
, adb shell pm disable-user --user 0 <package>
, adb shell pm clear <package>
, adb shell pm enable <package>        # undo a disable
```

Never touch: Play Services (`com.google.android.gms`), Play Store, `com.android.*`
core packages, Phone, Messages, anything with _ims_, _telephony_, _carrier_,
_iwlan_ or _provision_ in its name, and the Samsung/Shannon modem services.

== 7. Changes so far

#table(
  columns: (auto, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Date*], [*Change*],
  [before 2026-11],
  [Disabled: YouTube Music, Verizon and OMA-DM carrier packages, Glasses, Supervision and others. Removed: Samsung Health, Galaxy Wearable, Private Space.],

  [2026-11-26],
  [ReVanced (YouTube, GmsCore, Manager) uninstalled, stock YouTube enabled again. SafetyCore uninstalled (Google may push it again: check `pm list packages | grep safetycore`). YouTube Music: Play update removed, disabled, data cleared. Carrier Services (`com.google.android.ims`) enabled again. Checked: VoLTE registered, Wi-Fi calling on with "prefer Wi-Fi", blocked only on the school Wi-Fi. Uninstalled Google Fit, Lens (the Files scanner runs in Play Services and still works) and Google One. Language English (Germany) with metric, Celsius, Monday. Uninstalled Fitbit and the Samsung Galaxy Wearable leftovers (Accessory, Gear plugin; the `com.samsung.slsi.telephony.*` modem packages stay). Feeder (RSS) installed from F-Droid as the Google News replacement; on the stick: NewsFlash. Shared feed list `~/filen/feeds.opml` (24 feeds, incl. video feeds of Tagesschau, Tagesthemen, 100 Sekunden, heute, heute journal). Uninstalled Google News and BR24 (no working feed any more). Photos moved to Immich: Immich app backs up Camera, Screenshots, WhatsApp, Markup (144/144, notifications allowed for background backup); Google Photos: Play update removed, disabled, data cleared (`pm enable com.google.android.apps.photos` undoes it). The cloud library at photos.google.com is not emptied yet. Private DNS: leftover host name `dns0.eu` (service ended 2025) removed, mode stays Automatic (`settings delete global private_dns_specifier`); DNS comes from Tailscale (Pi-hole). Tailscale exit node `rpi` is preselected but off; the stale "DNS unavailable" warning cleared by reconnecting. Uninstalled (unused for months): DroidFS, NetAnalyzer, Network widget, ADAC Pannenhilfe, Libby, Google Translate (DeepL stays). Huawei AI Life + HMS Core stay for the FreeBuds 4i (noise cancelling, gestures, firmware). Caches trimmed (`pm trim-caches 999G`, about 140 MB). Removed never-opened stubs: Obtainium (Play/GitHub build; the F-Droid build stays), GPS Status 1, Clipious, one Chromium web app. Stores checked by installer (`dumpsys package <pkg> | grep installerPackageName`): F-Droid installed and updates Syncthing-Fork, Feeder, IronFox, Droid-ify and Obtainium; Accrescent, Droid-ify and Obtainium install none of the current apps; Termux (0.118.3, 2025-06), NewPipe and RustDesk were sideloaded and get no automatic updates. Accrescent uninstalled: its only app in use, IronFox, comes from F-Droid (IronFox repo, updated 2026-11-19). Droid-ify and Obtainium uninstalled too (no app was installed by them); F-Droid is the only store besides Play. Charging limited to 80 % (Settings → Battery → Charging optimisation; `settings put secure charge_optimization_mode 1`, 0 = Adaptive Charging). Developer option "Mobile data always active" off (`settings put global mobile_data_always_on 0`). Wi-Fi scanning off (Settings → Location → Location services → Wi-Fi scanning; `settings put global wifi_scan_always_enabled 0`, Bluetooth scanning was already off). pCloud uninstalled (Filen is the cloud; it was exempt from battery optimisation). Uninstalled "Vocabulary" (`com.nomtek`, English vocabulary trainer from 2022, not opened this year). Second profile `legymhueck` (user 10, full secondary user, last used 2026-10-25) deleted with all its apps and data (`pm remove-user 10`); only the main profile is left. Ente Auth uninstalled (codes stay in the Ente account, web: auth.ente.io); 2FA codes live in Proton Authenticator.],
)
