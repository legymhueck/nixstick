// Filen cloud sync on the stick -- printable handout.
// Build: typst compile docs/tips/filen.typ docs/tips/out/filen.pdf  (out/ is git-ignored;
// mkdir -p docs/tips/out first, or <leader>re in Neovim)

#set document(title: "Filen sync on the stick")
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

= Filen sync on the stick

The stick runs the same Filen sync as the main system: `~/filen` syncs *two-way* with the *whole* Filen drive
(`filen-cli`, service `filen-sync`, `common/filen.nix`). Everything that is not stick-specific (setting it up,
the rules for what goes into Filen, troubleshooting, `filen` commands) is described once, in German, in the main repo
nixos: `docs/setup/cloud-sync.typ` (on the stick cloned under `~/GitHub/nixos_full/nixos`).

== Short version

```sh
filen                # once: log in, answer "yes" to saving the credentials, then exit
filen-sync on        # start syncing; stays on after reboots
filen-sync off       # stop syncing; the files in ~/filen stay
filen-sync status    # Switch: on/off, plus the service state
filen-sync log       # follow the sync log live (Ctrl+C quits)
```

== Only on the stick

- *Space:* the first sync downloads the whole drive. Before switching on, compare `df -h ~` (free on the stick)
  with `filen statfs` (used on the drive).
- *Speed:* the sync runs at idle I/O priority, because the stick can only do one thing at a time; the desktop stays
  responsive, the sync waits.
- *Foreign PCs:* nothing changes there; the files only live on the encrypted stick.
- *Student data:* the drive may hold student data for a limited time (folder `schule`, rule in `cloud-sync.typ`).
  They land on the stick too and stay there after `filen-sync off`, protected only by the stick's LUKS encryption.
