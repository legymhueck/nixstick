// zathura cheat sheet -- printable, one A4 page.
// Build: typst compile docs/tips/zathura.typ docs/tips/out/zathura.pdf  (out/ is git-ignored;
// mkdir -p docs/tips/out first, or <leader>re in Neovim)

#set document(title: "zathura cheat sheet")
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

= zathura cheat sheet

== Open

#keys(
  [`zathura file.pdf`], [from the shell (also EPUB, DjVu, PostScript)],
  [`xdg-open file.pdf`], [default viewer; Double Commander uses it too],
  [`o` / `O`], [open another file (`O`: from the file's folder)],
  [`q`], [quit],
)

== Move

#keys(
  [`j` `k` / `h` `l`], [scroll down / up / left / right],
  [`Space` / `Shift+Space`], [one screen down / up],
  [`Ctrl+d` / `Ctrl+u`], [half a screen down / up],
  [`J` / `K`], [next / previous page],
  [`gg` / `G`], [first / last page],
  [`42G`], [page 42],
  [`Ctrl+o` / `Ctrl+i`], [jump back / forward (after `G`, links, search)],
  [`ma` / `'a`], [set mark _a_ / jump to it],
)

== Search

#keys(
  [`/text` / `?text`], [search forward / backward],
  [`n` / `N`], [next / previous hit],
)

== Zoom and layout

#keys(
  [`+` / `-` / `=`], [zoom in / out / 100 %],
  [`Ctrl+scroll`], [zoom with the mouse],
  [`s`], [fit width (the default on open)],
  [`a`], [fit the whole page],
  [`d`], [two pages side by side (toggle); `D`: page 1 alone (book view)],
  [`r`], [rotate 90°],
  [`F11`], [fullscreen],
  [`F5`], [presentation mode (one page, black border; `F5` back)],
)

== Contents and links

#keys(
  [`Tab`], [table of contents; `j` `k` move, `l` `h` open / close, `Enter` go, `Tab` back],
  [`f`], [follow a link: type the number shown],
  [`F`], [show where a link points],
)

== Look and text

#keys(
  [`Ctrl+r`], [dark mode (recolor; colors keep their hue)],
  [select with mouse], [copies to the clipboard (`Ctrl+V` pastes)],
  [`R`], [reload (happens on its own when the file changes)],
  [`Ctrl+n`], [show / hide the status bar],
)

== Commands (type `:`)

#keys(
  [`:print`], [print],
  [`:write copy.pdf`], [save a copy],
  [`:bmark name` / `:blist`], [save a bookmark / list them (`:bdelete name`)],
  [`:info`], [document information (title, author, pages)],
)

== From Neovim

#keys(
  [`<leader>re`], [export PDF (Typst, Marp, Markdown) to `out/` next to the file],
  [`<leader>ro`], [open that PDF in zathura; export again and the window updates],
  [`<leader>sp`], [pick from all PDFs in the folder (git-ignored exports too)],
  [open a `.pdf`], [picker, explorer or `nvim file.pdf`: opens in zathura],
  [`gx`], [on a path or URL: open it with the default program],
)

== Workflow: write a `.typ`, watch the result

*A. Live preview while writing*
+ Open the `.typ` file, press `<leader>rp`.
+ The browser shows the document and updates as you type (no saving needed);
  clicking in it jumps to that spot in the source.
+ `<leader>rp` again turns it off.

*B. The real PDF in zathura* (print layout, the file itself)
+ `<leader>re` writes `out/<name>.pdf`.
+ `<leader>ro` opens it in zathura; put the windows side by side
  (`Super+Alt+Left/Right` moves a window to the other monitor).
+ Edit, `<leader>re` again: zathura reloads and keeps your page.

Write with A, check with B at the end, then print: `:print` in zathura or
`lp out/name.pdf`.

== Settings

`common/apps.nix` (`programs.zathura.options`), applied with `nh os switch`.
Colors follow the wallpaper: Noctalia writes `~/.config/zathura/noctaliarc`
and updates open windows.
All options: `man zathurarc`.
