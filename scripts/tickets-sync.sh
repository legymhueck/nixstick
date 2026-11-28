#!/usr/bin/env bash
# Regio-IT tickets -> tasks in the Nextcloud list "Tickets". The logic is in
# tickets-sync.py next to this file (TICKETS_SYNC_PY comes from
# common/tickets.nix). `tickets-sync setup` shows the one-time keyring entries.
exec python3 -I "$TICKETS_SYNC_PY" "$@"
