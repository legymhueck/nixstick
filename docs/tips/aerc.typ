// aerc mail on the stick -- printable tutorial: set up once, then daily use.
// Build: typst compile docs/tips/aerc.typ docs/tips/out/aerc.pdf  (out/ is git-ignored;
// mkdir -p docs/tips/out first, or <leader>re in Neovim)

#set document(title: "Mail with aerc on the stick")
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

= Mail with aerc on the stick

aerc is a mail program for the terminal. It reads mail straight from the
server (IMAP): nothing is copied onto the stick, so it needs a network. Sending
goes through msmtp; mail written while offline waits in a queue. The mail
password is never stored in plain text: it lives in `pass`, encrypted with
your own GPG key.

#table(
  columns: (auto, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Reading*], [aerc over IMAP (no local copy of the mailbox)],
  [*Sending*], [msmtp via its queue `msmtpq` (offline mail goes out later)],
  [*Password*], [`pass show mail/<address>`, decrypted with your GPG key],
  [*Key passphrase*], [asked in a small window, then remembered for 8 hours],
  [*Configuration*], [`common/mail.nix` in `~/nixos`],
)

Setup happens once per stick: steps 1 to 4. Everything after that is daily use.

== 1. Collect the account details

You need four things from your provider's help pages ("IMAP settings" or
"mail client setup"):

- the *address* and the *login name* (usually the address itself),
- the *IMAP server* (port 993, SSL/TLS),
- the *SMTP server* (port 465 SSL/TLS, or 587 STARTTLS),
- the *password*. With two-factor login, create an *app password* in the
  provider's web settings and use that instead of the normal password. Some
  providers (GMX, web.de) also need IMAP switched on in the web settings first.

#table(
  columns: (auto, 1fr, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Provider*], [*IMAP (993)*], [*SMTP*],
  [mailbox.org], [`imap.mailbox.org`], [`smtp.mailbox.org`, 465],
  [Posteo], [`posteo.de`], [`posteo.de`, 465],
  [GMX], [`imap.gmx.net`], [`mail.gmx.net`, 465],
  [web.de], [`imap.web.de`], [`smtp.web.de`, 587 STARTTLS],
  [Gmail], [`imap.gmail.com`], [`smtp.gmail.com`, 465 (app password)],
)

Proton needs the Proton Mail Bridge, Microsoft (Outlook, Office 365) only
allows OAuth logins: neither works with this setup as it is.

== 2. Create your GPG key

```sh
gpg --full-generate-key
```

Accept the default (ECC, Curve 25519) with Enter, choose an expiry (`0` = never),
give your name and the mail address, then a *passphrase* in the window that
opens. This passphrase protects every password in `pass`: pick a good one and
do not lose it. Show the key afterwards:

```sh
gpg --list-secret-keys --keyid-format long
```

== 3. Store the mail password in pass

```sh
pass init 074F6A977E7F6334     # the key ID from step 2 (once for the whole store)
pass insert mail/michael.lehnen@gymhueck.de   # type the ACCOUNT's password twice
pass show mail/michael.lehnen@gymhueck.de     # test: asks for the GPG passphrase
```

*Two different passwords* are involved, and they are easy to mix up:

#table(
  columns: (auto, auto, 1fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Password*], [*Where you type it*], [*What it does*],
  [*Mail account password*],
  [once, at `pass insert mail/<address>`],
  [Logs in to the mail server, the same one any mail program would use. pass keeps it encrypted; aerc and msmtp fetch it themselves.],

  [*GPG key passphrase*],
  [in the pop-up window, about every 8 h],
  [Unlocks your GPG key (step 2) so pass can decrypt the mail password.],
)

So `pass insert` always wants the *account's* password, and the pop-up window
always wants the *GPG passphrase*. Some servers want an app password instead of
the normal login password: the school account (LOGINEO NRW, `mail.nrw.schule`)
uses a long generated password, the one aerc's own account wizard
(`:new-account`) also asks for. Store exactly that one.

`mail/michael.lehnen@gymhueck.de` is *one* entry, the whole string is its
name. `mail/` is a folder that groups the mail passwords; everything after the
slash, `@` and dots included, is the entry. pass keeps it as one encrypted
file: `~/.local/share/password-store/mail/michael.lehnen@gymhueck.de.gpg`.

The configuration looks the password up as `mail/<address>`, so every address
gets exactly one entry of its own. `pass` alone lists all entries as a tree:

```
Password Store
└── mail
    └── michael.lehnen@gymhueck.de
```

== 4. Enter the account and rebuild

The accounts are in `~/nixos/common/mail.nix`, one block per address:

```nix
gymhueck = mkAccount {
  primary = true;                      # default sender, first tab
  address = "michael.lehnen@gymhueck.de";
  host = "mail.nrw.schule";            # IMAP 993 and SMTP 465 on this host
  folders.inbox = "INBOX";             # the server's name for the inbox
};
```

The name in front (`gymhueck`) is the account's tab in aerc and its name for
msmtp. `mkAccount` fills in the rest: login name = address, password from
`pass show mail/<address>`, TLS on ports 993 and 465.

*Another address:* store its password (`pass insert mail/<address>`), copy the
block with a new name and *without* `primary = true`:

```nix
verein = mkAccount {
  address = "m.lehnen@example.org";
  host = "mail.example.org";
  # different servers or SMTP on 587:
  # imap.host = "imap.example.org";
  # smtp = { host = "smtp.example.org"; port = 587; tls.useStartTls = true; };
};
```

Then apply it and test both directions:

```sh
rebuild                                # nh os switch
msmtp --serverinfo -a gymhueck         # SMTP test: lists the server's abilities
aerc                                   # IMAP: the folders appear on the left
```

In aerc each account is a tab at the top: `Ctrl+n` / `Ctrl+p` switch between
them. When writing, `Alt+n` / `Alt+p` change the sender account.

Finally send yourself a test mail (`m`, see below).

== Daily use

Start with `aerc`. The screen has the folder list on the left and the message
list on the right. `?` shows every key in the current view; `:` opens the
command line (with Tab completion); `Ctrl+c` or `q` quits.

=== Message list

#keys(
  [`j` `k` / arrows], [next / previous message],
  [`g` / `G`], [first / last message],
  [`J` / `K`], [next / previous folder],
  [`c`], [change to a folder by name (Tab completes)],
  [`Enter`], [open the message (in Drafts: continue the draft)],
  [`m`], [write a new message],
  [`rr` / `Rr`], [reply to all / to the sender only],
  [`rq` / `Rq`], [the same, quoting the original],
  [`d`], [delete (asks first; moves to Trash)],
  [`a`], [archive (moves to the folder Archive)],
  [`v` / `Space`], [mark / mark and go on; `d` and `a` then act on all marked],
  [`/` / `n` `N`], [search on the server / next and previous hit],
  [`\`], [filter the list (`Esc` clears it)],
  [`T`], [threads on or off],
)

=== Reading a message

#keys(
  [`j` `k`], [scroll],
  [`J` / `K`], [next / previous message],
  [`Ctrl+j` / `Ctrl+k`], [next / previous part (text, HTML, attachments)],
  [`o`], [open the current part: PDFs in zathura, pictures in the image viewer, HTML in Firefox],
  [`S`], [save the attachment: `S ~/Downloads/` then Enter],
  [`Ctrl+l`], [open a link from the mail in the browser (Tab lists them)],
  [`f`], [forward],
  [`H`], [show all headers],
  [`q`], [back to the list],
)

HTML mail is shown as plain text (w3m, without loading anything from the
internet, so no tracking pixels). For the original layout press `Ctrl+j`
until the HTML part is selected, then `o`.

=== Writing

`m` (or a reply key) asks for the header fields: *To*, *Subject*, then `Tab`
moves to the next field and Neovim opens for the text. Several recipients are
separated by commas; `Cc` and `Bcc` can be added with `:header Cc address`.
Write the text, then `:wq`. The review screen follows:

#keys(
  [`y`], [send],
  [`a`], [attach a file: `a ~/Documents/file.pdf` (Tab completes the path)],
  [`d`], [remove an attachment],
  [`e`], [back to the text],
  [`v`], [preview as the recipient will see it],
  [`p`], [postpone: save as draft (continue later from Drafts with `Enter`)],
  [`n`], [discard without asking],
)

A sent message is also saved in the folder Sent.

=== Tabs

Every open message and every draft is a tab at the top: `Ctrl+n` / `Ctrl+p`
switch tabs, so you can read one mail while writing another.

== Offline

aerc needs a network to read. Mail you *send* while offline is not lost: msmtp
puts it into a queue (`~/.msmtp.queue`). Once you are online again, send the
queue:

```sh
msmtp-queue -d       # list the queued mail
msmtp-queue -r       # send everything in the queue now
```

== Safety

- *Back up the GPG key*: it exists only on this stick. Without it, every
  password in `pass` is unreadable. Export it to an encrypted place (a VeraCrypt
  container, the encrypted backup drive), never to Filen in plain text:
  ```sh
  gpg --export-secret-keys -a > ~/mount/gpg-key.asc
  ```
  On a new stick: `gpg --import gpg-key.asc`, copy
  `~/.local/share/password-store` over, and `pass` works again.
- *On a foreign PC* nothing is written to it: the mail stays on the server, the
  key and the password stay on the encrypted stick.
- Changing the mail password: `pass edit mail/<address>`,
  then restart aerc.

== When something goes wrong

#table(
  columns: (1fr, 1.4fr),
  stroke: 0.5pt + luma(170),
  inset: 6pt,
  [*Symptom*], [*What to do*],
  [aerc hangs at "Connecting", no messages arrive], [The account URL uses `imap://` (or `smtp://`) on port 993 (465): those ports speak TLS from the start and need `imaps://` / `smtps://`. Happens with aerc's own account wizard (`:new-account`), not with `common/mail.nix`.],
  [`aerc` shows no account / the old example], [`rebuild` not run after changing `common/mail.nix`.],
  [Login failed / authentication error], [Is the *account's* password in pass, not the GPG passphrase or another password? Check with `pass show mail/<address>`; replace with `pass insert -f mail/<address>`. With two-factor login an *app password* is needed; check the login name.],
  [No passphrase window, aerc hangs on connect], [Run `pass show mail/<address>` in a terminal once: the window appears, the passphrase is then cached for 8 h.],
  [Sending fails], [`msmtp --serverinfo -a <account>`. Port 587 needs `tls.useStartTls = true`, 465 must not have it.],
  [Sent mail does not appear in Sent], [The provider names it differently (e.g. `Sent Items`): set `folders.sent = "Sent Items";` in the account block, `rebuild`. The same for `folders.drafts`, `folders.trash`.],
  [`a` (archive) complains], [The folder Archive does not exist: create it in the provider's web mail, or don't use `a`.],
  [aerc opens without a selected folder], [Set `folders.inbox = "INBOX";` in the account block, `rebuild`.],
)

Help inside aerc: `:help` (overview), `:help keys`, or `man aerc`.
