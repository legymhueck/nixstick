"""Regio-IT service tickets -> tasks in the Nextcloud list "Tickets".

Reads only the Subject and Date headers of mail from service@regioit.de in the
LOGINEO mailboxes (IMAP, read-only: nothing is marked read or moved) and keeps
one task per ticket number in the CalDAV task list:

  "Serviceanforderung# N - ..." / "... wurde im System aktiviert ..."  -> open task
  "... wurde abgeschlossen ..."                                         -> task completed

The task holds only the number and the subject (no mail text: data
protection). A task you complete or delete by hand is left alone: a deleted one
is recreated only while its ticket is still open and its mails are younger than
the window. Passwords come from GNOME Keyring entries of this script's own
(see `tickets-sync setup`), never from a file.
"""

import argparse
import base64
import contextlib
import datetime as dt
import email.header
import email.utils
import imaplib
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

IMAP_HOST = "mail.nrw.schule"
MAILBOXES = [
    "michael.lehnen@gymhueck.de",
    "itsupport@gymhueck.de",
    "ms365support@gymhueck.de",
    "prowiseadmin@gymhueck.de",
    "lms-support@gymhueck.de",
]
SENDER = "service@regioit.de"
NC_USER = "michael"
CALDAV = "https://rpi.bone-vibes.ts.net/remote.php/dav/calendars/michael/Tickets/"
SKIP_FOLDERS = re.compile(r"(?i)(trash|papierkorb|spam|junk|drafts|entw)")

TICKET = re.compile(
    r"Serviceanforderung#\s*(\d{5,})\s*#?\s*(?:-\s*)?"
    r"(?:wurde\s+(im System aktiviert|abgeschlossen)\s*#\s*)?(.*)",
    re.IGNORECASE,
)


def secret(account):
    r = subprocess.run(
        ["secret-tool", "lookup", "service", "tickets-sync", "account", account],
        capture_output=True,
        check=False,
        text=True,
    )
    return r.stdout.rstrip("\n") or None


def decode(h):
    return "".join(
        p.decode(c or "utf-8", "replace") if isinstance(p, bytes) else p
        for p, c in email.header.decode_header(h or "")
    )


def clean_title(t):
    t = re.sub(r"\s+", " ", t).strip(" #-")
    t = re.sub(r"\s*-?\s*Gymnasium Hückelhoven\s*//.*$", "", t).strip(" #-")
    return t


def scan_mailbox(addr, password, since, tickets):
    imap = imaplib.IMAP4_SSL(IMAP_HOST)
    try:
        imap.login(addr, password)
        _, folders = imap.list()
        for line in folders or []:
            line = line.decode()
            if "\\Noselect" in line:
                continue
            name = (
                line.rsplit(' "', 1)[-1].rstrip('"')
                if line.endswith('"')
                else line.split()[-1]
            )
            if SKIP_FOLDERS.search(name):
                continue
            if imap.select(f'"{name}"', readonly=True)[0] != "OK":
                continue
            _, data = imap.search(
                None, "FROM", f'"{SENDER}"', "SINCE", since.strftime("%d-%b-%Y")
            )
            ids = data[0].split()
            if not ids:
                continue
            _, msgs = imap.fetch(
                b",".join(ids), "(BODY.PEEK[HEADER.FIELDS (SUBJECT DATE)])"
            )
            for part in msgs:
                if not isinstance(part, tuple):
                    continue
                msg = email.message_from_bytes(part[1])
                subj = decode(msg.get("Subject"))
                m = TICKET.search(subj)
                if not m:
                    continue
                num, state, title = (
                    m.group(1),
                    (m.group(2) or "").lower(),
                    clean_title(m.group(3)),
                )
                date = (
                    email.utils.parsedate_to_datetime(msg.get("Date"))
                    if msg.get("Date")
                    else None
                )
                t = tickets.setdefault(num, {"title": "", "done": None, "first": date})
                if title and (not t["title"] or len(title) > len(t["title"])):
                    t["title"] = title
                if date and (t["first"] is None or date < t["first"]):
                    t["first"] = date
                if state == "abgeschlossen":
                    t["done"] = max(
                        filter(None, [t["done"], date or dt.datetime.now(dt.UTC)])
                    )
    finally:
        with contextlib.suppress(imaplib.IMAP4.error, OSError):
            imap.logout()


def dav(method, url, auth, body=None):
    req = urllib.request.Request(url, method=method, data=body)
    req.add_header("Authorization", "Basic " + auth)
    if body is not None:
        req.add_header("Content-Type", "text/calendar; charset=utf-8")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, ""


def ics_escape(s):
    return (
        s.replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\n", "\\n")
    )


def vtodo(num, t, done):
    now = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    created = (
        (t["first"] or dt.datetime.now(dt.UTC))
        .astimezone(dt.UTC)
        .strftime("%Y%m%dT%H%M%SZ")
    )
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//nixstick//tickets-sync//EN",
        "BEGIN:VTODO",
        f"UID:ticket-{num}@regioit",
        f"DTSTAMP:{now}",
        f"CREATED:{created}",
        f"SUMMARY:{ics_escape((num + ' ' + t['title']).strip())}",
        "CATEGORIES:Ticket",
    ]
    if done:
        stamp = done.astimezone(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
        lines += ["STATUS:COMPLETED", "PERCENT-COMPLETE:100", f"COMPLETED:{stamp}"]
    else:
        lines += ["STATUS:NEEDS-ACTION"]
    lines += ["END:VTODO", "END:VCALENDAR", ""]
    return "\r\n".join(lines).encode()


def run(days, dry):
    since = dt.date.today() - dt.timedelta(days=days)
    tickets = {}
    for addr in MAILBOXES:
        pw = secret(addr)
        if not pw:
            print(
                f"skip {addr}: no keyring entry (tickets-sync setup)", file=sys.stderr
            )
            continue
        try:
            scan_mailbox(addr, pw, since, tickets)
        except (imaplib.IMAP4.error, OSError) as e:
            print(f"{addr}: {e}", file=sys.stderr)
    nc = secret("nextcloud")
    if not nc:
        sys.exit("no keyring entry for nextcloud (tickets-sync setup)")
    auth = base64.b64encode(f"{NC_USER}:{nc}".encode()).decode()
    created = completed = 0
    for num, t in sorted(tickets.items()):
        url = f"{CALDAV}ticket-{num}.ics"
        status, body = dav("GET", url, auth)
        if status == 404:
            if t["done"]:
                continue  # closed before we ever saw it open: no task needed
            print(f"new  {num} {t['title']}")
            created += 1
            if not dry:
                dav("PUT", url, auth, vtodo(num, t, None))
        elif status == 200:
            if t["done"] and "STATUS:COMPLETED" not in body:
                print(f"done {num} {t['title']}")
                completed += 1
                if not dry:
                    dav("PUT", url, auth, vtodo(num, t, t["done"]))
        else:
            print(f"{num}: CalDAV answered {status}", file=sys.stderr)
    print(
        f"{len(tickets)} tickets seen, {created} new, {completed} completed"
        + (" (dry run)" if dry else "")
    )


def setup():
    print("Store the passwords once in GNOME Keyring (each command asks for one):\n")
    for a in MAILBOXES:
        print(
            f"  secret-tool store --label='tickets-sync {a}' service tickets-sync account {a}"
        )
    print(
        "  secret-tool store --label='tickets-sync nextcloud' service tickets-sync account nextcloud"
        "   # a Nextcloud app password named tickets-sync"
    )
    print("\nMailboxes without an entry are skipped.")


def main():
    p = argparse.ArgumentParser(prog="tickets-sync", description=__doc__.split("\n")[0])
    p.add_argument("command", nargs="?", default="run", choices=["run", "setup"])
    p.add_argument("--dry-run", action="store_true", help="only show what would change")
    p.add_argument(
        "--days", type=int, default=int(os.environ.get("TICKETS_DAYS", "60"))
    )
    a = p.parse_args()
    setup() if a.command == "setup" else run(a.days, a.dry_run)


if __name__ == "__main__":
    main()
