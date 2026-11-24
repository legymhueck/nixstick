// Filen cloud sync on the stick -- printable handout.
// Build: typst compile docs/tips/filen.typ docs/tips/out/filen.pdf  (out/ is git-ignored;
// mkdir -p docs/tips/out first, or <leader>re in Neovim)

#set document(title: "Filen sync on the stick")
#set page(paper: "a4", margin: (x: 2cm, y: 2cm), numbering: "1 / 1")
#set text(size: 10.5pt, lang: "en")
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

= Filen sync on the stick

The folder `~/filen` syncs *two-way* with the *whole* Filen drive. The sync is
off until you switch it on. Once on, it keeps running in the background and
comes back after every login and reboot until you switch it off.

#table(
  columns: (auto, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Local folder*], [`~/filen` (created on the first start)],
  [*Cloud folder*], [`/`: the whole Filen drive],
  [*Mode*], [two-way: changes and deletions go both ways],
  [*Program*], [`filen-cli` (official Filen CLI, same sync engine as the desktop app)],
  [*Configuration*], [`common/filen.nix` in `~/nixos`],
)

== 1. Log in once

```sh
filen
```

Enter your Filen email, password and, if enabled, the 2FA code. Answer *yes*
when it asks whether to save the credentials. They are stored in
`~/.config/filen-cli/.filen-cli-keep-me-logged-in` on the encrypted stick. Leave the
interactive prompt with `exit`.

== 2. Switch on, switch off

```sh
filen-sync on        # start syncing; stays on after reboots
filen-sync off       # stop syncing; the files in ~/filen stay
filen-sync status    # Switch: on/off, plus the service state
filen-sync log       # follow the sync log live (Ctrl+C quits)
```

`filen-sync on` refuses to start while there is no saved login (step 1).

== Good to know

- *The first sync downloads the whole drive.* Check that it fits on the stick
  before switching on: `df -h ~` (free on the stick) against `filen statfs` (used on the drive).
- *Deleting is synced.* A file deleted in `~/filen` is deleted in the cloud too
  (and the other way round). Deleted files land in Filen's trash online; there
  is no local trash (it broke the sync when Filen ran on two systems).
- *Hidden files and folders* (names starting with a dot) are not synced.
- *Offline is fine.* Without a network the service retries every 30 seconds
  and catches up once you are online.
- *The desktop stays responsive.* The sync runs at idle I/O priority, because
  the stick can only do one thing at a time.
- *On a foreign PC* nothing changes: the files only live on the stick.

== When something goes wrong

#table(
  columns: (1fr, 1.4fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Symptom*], [*What to do*],
  [`filen-sync on` says "Not logged in"], [Run `filen`, log in, save the credentials.],
  [Status says "inactive" / "start condition unmet"], [The switch is off or the login is missing: `filen-sync on`.],
  [Errors in `filen-sync log` after a password change], [`filen logout`, then `filen` to log in again, then `filen-sync on`.],
  [Sync stuck or confused], [`filen-sync off`, then `filen-sync on`.],
)

== Other things `filen` can do

```sh
filen ls /                  # list the drive
filen download /Doc.pdf .   # fetch one file without syncing
filen upload file.pdf /     # upload one file
filen help                  # everything else (mount, WebDAV, ...)
```

== Changing the setup

The folder pair is in `common/filen.nix` (`syncPairs.json`). For example, to
sync only one cloud folder, set `remote = "/Folder"`. Then `rebuild` and
`filen-sync off && filen-sync on`.
