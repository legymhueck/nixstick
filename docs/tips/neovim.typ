// Neovim keymaps cheat sheet -- printable, one A4 page.
// Source of truth: dotfiles/nvim/lua/m/{init,plugins,lsp,run,ai}.lua; update this sheet when a keymap changes.
// Build: typst compile docs/tips/neovim.typ docs/tips/out/neovim.pdf  (out/ is git-ignored;
// mkdir -p docs/tips/out first, or <leader>re in Neovim)

#set document(title: "Neovim keymaps")
#set page(paper: "a4", margin: (x: 1.6cm, y: 1.5cm), columns: 2)
#set columns(gutter: 1cm)
#set text(size: 9.5pt, lang: "en")
#set heading(numbering: none)
#show heading.where(level: 1): it => place(top, scope: "parent", float: true, block(below: 0.8em, text(
  size: 17pt,
  it.body,
)))
#show heading.where(level: 2): it => block(above: 1.1em, below: 0.5em, text(size: 11.5pt, it.body))
#show raw.where(block: false): box.with(fill: luma(240), inset: (x: 2pt), outset: (y: 2pt), radius: 2pt)

#let keys(..rows) = table(
  columns: (auto, 1fr),
  stroke: none,
  inset: (x: 4pt, y: 3pt),
  fill: (_, y) => if calc.odd(y) { luma(246) },
  ..rows.pos().flatten(),
)

= Neovim keymaps

`␣` = leader = Space; local leader is `,`. Press `␣` and wait: which-key shows the groups. `␣sk` searches every
keymap inside Neovim.

== Basics

#keys(
  [`␣w`], [save],
  [`␣q`], [close window],
  [`Esc`], [clear search highlight],
  [`Ctrl-h/j/k/l`], [window left / down / up / right (also from a terminal)],
  [`Alt-j` / `Alt-k`], [move line or selection down / up],
  [`Ctrl-/`], [terminal on / off],
  [`Esc Esc`], [leave terminal mode],
)

== Files and search

#keys(
  [`␣␣`], [find file],
  [`␣/`], [grep in project],
  [`␣,`], [open buffers],
  [`␣e`], [file tree],
  [`-`], [folder as a buffer (oil): edit names like text],
  [`␣sr`], [recent files],
  [`␣sp`], [PDFs (zathura), git-ignored exports too],
  [`␣sh`], [help pages],
  [`␣sk`], [keymaps],
  [`␣sd`], [diagnostics],
  [`␣ss`], [symbols in file],
  [`␣sw`], [word under cursor],
)

== Code (LSP)

#keys(
  [`gd`], [go to definition],
  [`␣cr`], [rename symbol],
  [`␣ca`], [code action],
  [`␣cd`], [show diagnostic],
  [`␣cf`], [format (also a selection)],
)

== Git

#keys(
  [`␣gg`], [Lazygit],
  [`␣gb`], [blame line],
  [`␣gp`], [preview change],
  [`]h` / `[h`], [next / previous change],
)

== Run and export

#keys(
  [`␣rr`], [run file (Python / Java)],
  [`␣rp`], [preview (Typst / Marp / Markdown); Typst: live PDF in zathura, toggle],
  [`␣re`], [export PDF to `out/` next to the file],
  [`␣ro`], [open the exported PDF (zathura)],
  [`␣rh`], [export HTML],
  [`␣rx`], [export PPTX (Marp)],
)

== AI: Claude

#keys(
  [`␣ac`], [Claude on / off],
  [`␣af`], [focus Claude],
  [`␣ar`], [resume a Claude session],
  [`␣aC`], [continue the last session],
  [`␣ab`], [add current file],
  [`␣as`], [send selection (visual mode)],
  [`␣aa`], [accept Claude's change],
  [`␣ad`], [reject Claude's change],
)

== AI: Copilot

#keys(
  [`␣at`], [suggestions on / off],
  [`␣ag`], [Copilot CLI],
  [`Alt-]` / `Alt-[`], [next / previous suggestion (insert mode)],
)

== AI: opencode

#keys(
  [`␣oo`], [opencode on / off],
  [`␣oa`], [ask about this (line or selection)],
  [`␣os`], [prompts and commands],
  [`go`], [add range (operator, e.g. `goip`)],
  [`goo`], [add current line],
)

== Spelling

#keys(
  [`zg` / `zw`], [add word as good / wrong (`zug`, `zuw` undo); list in `dotfiles/nvim/spell/`],
)
