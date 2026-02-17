---
name: gog
description: Google Workspace CLI for Gmail, Calendar, Drive, Contacts, Tasks, Sheets, Docs, and Slides.
homepage: https://gogcli.sh
metadata:
  {
    "openclaw":
      {
        "emoji": "🎮",
        "requires": { "bins": ["gog"] },
        "install":
          [
            {
              "id": "brew",
              "kind": "brew",
              "formula": "steipete/tap/gogcli",
              "bins": ["gog"],
              "label": "Install gog (brew)",
            },
          ],
      },
  }
---

# gog

Use `gog` for Gmail, Calendar, Drive, Contacts, Tasks, Sheets, Docs, and Slides. Requires OAuth setup. For full command reference run `gog <service> --help` (e.g. `gog gmail --help`, `gog drive --help`) or `GOG_HELP=full gog --help`. Official docs: [gogcli.sh](https://gogcli.sh) and [GitHub](https://github.com/steipete/gogcli).

## Setup (once)

- `gog auth credentials /path/to/client_secret.json`
- `gog auth add you@gmail.com --services gmail,calendar,drive,contacts,tasks,docs,sheets,slides`
- `gog auth list` — list accounts; `gog auth list --check` — validate tokens
- Headless (no browser on machine): `gog auth add you@gmail.com --services user --manual` (paste redirect URL from local browser), or use `--remote --step 1` / `--step 2` for scripted flow.
- To add more services later: `gog auth add you@gmail.com --services sheets --force-consent` (if Google didn’t return a refresh token).

## Gmail

- **Search (threads):** `gog gmail search 'newer_than:7d' --max 10` — one row per thread
- **Search (per message):** `gog gmail messages search "in:inbox from:example.com" --max 20` — every email separately
- **Read thread:** `gog gmail thread get <threadId>`; add `--download` or `--download --out-dir ./attachments` for attachments
- **Read message:** `gog gmail get <messageId>`; `gog gmail attachment <messageId> <attachmentId> --out ./file.bin`
- **Send:** `gog gmail send --to a@b.com --subject "Hi" --body "Hello"` (plain); multi-line: `--body-file ./message.txt` or `--body-file -` (stdin); HTML: `--body-html "<p>Hello</p>"`
- **Reply (with quoted original):** `gog gmail send --reply-to-message-id <msgId> --quote --to a@b.com --subject "Re: Hi" --body "My reply"`
- **Drafts:** `gog gmail drafts create --to a@b.com --subject "Hi" --body-file ./message.txt`; `gog gmail drafts list`; `gog gmail drafts update <draftId> --subject "New" --body "..."`; `gog gmail drafts send <draftId>`
- **Labels:** `gog gmail labels list`; `gog gmail labels get INBOX --json`; `gog gmail labels create "My Label"`; modify/delete via `gog gmail labels modify` / `gog gmail labels delete` (see `gog gmail labels --help`)
- **Batch:** `gog gmail batch modify <id1> <id2> ... --add STARRED --remove INBOX`; `gog gmail batch delete <id1> <id2> ...`
- **Filters / settings / delegation / watch:** see `gog gmail --help` (filters list/create/delete; vacation, forwarding, sendas; delegates; watch for Pub/Sub).

## Calendar

- **List calendars:** `gog calendar calendars`; workspace users: `gog calendar users`
- **Events:** `gog calendar events <calendarId> --from <iso> --to <iso>`; or use `--today`, `--tomorrow`, `--week`, `--days 3` (relative)
- **Single event:** `gog calendar get <calendarId> <eventId>` or `gog calendar event <calendarId> <eventId>`
- **Search:** `gog calendar search "meeting" --today` (or `--tomorrow`, `--days N`, `--from`/`--to`)
- **Create:** `gog calendar create <calendarId> --summary "Title" --from <iso> --to <iso>`; optional `--event-color 7`
- **Update:** `gog calendar update <calendarId> <eventId> --summary "New Title" --event-color 4`
- **Colors:** `gog calendar colors` — lists IDs 1–11 and hex codes.

## Drive

- **List/search:** `gog drive ls --query "mimeType='application/pdf'" --max 10`; or `gog drive search "query" --max 10`
- **Upload:** `gog drive upload /path/to/file` (optional `--parent <folderId>`)
- **Download:** `gog drive download <fileId>` (optional `--out ./filename`)
- Permissions, folders, shared drives: see `gog drive --help`.

## Contacts

- **List:** `gog contacts list --max 20`
- **Search / create / update:** see `gog contacts --help` (directory and “other contacts” when available).

## Tasks

- Tasklists and tasks: list, create, add, update, mark done/undo, delete, clear. Use `gog tasks --help` for subcommands (e.g. list tasklists, list tasks in a list, add task, complete task). Use `--json` for scripting.

## Sheets

- **Read:** `gog sheets get <sheetId> "Tab!A1:D10" --json`
- **Write:** `gog sheets update <sheetId> "Tab!A1:B2" --values-json '[["A","B"],["1","2"]]' --input USER_ENTERED`
- **Append:** `gog sheets append <sheetId> "Tab!A:C" --values-json '[["x","y","z"]]' --insert INSERT_ROWS`
- **Clear:** `gog sheets clear <sheetId> "Tab!A2:Z"`
- **Metadata:** `gog sheets metadata <sheetId> --json`
- **Export (e.g. PDF):** `gog sheets export <sheetId> --format pdf --out ./sheet.pdf` (via Drive).

## Docs

- **Export:** `gog docs export <docId> --format txt --out /tmp/doc.txt` (or docx, pdf)
- **Read inline:** `gog docs cat <docId>`
- Create/copy: see `gog docs --help`. In-place edits require a Docs API client (not in gog).

## Slides

- **Export:** `gog slides export <presentationId> --format pptx --out ./deck.pptx` (or pdf). Create/copy: see `gog slides --help`.

## Calendar colors (quick reference)

- Use `gog calendar colors` to see all available event colors (IDs 1–11). Add to events with `--event-color <id>`.
- Event color IDs: 1 #a4bdfc, 2 #7ae7bf, 3 #dbadff, 4 #ff887c, 5 #fbd75b, 6 #ffb878, 7 #46d6db, 8 #e1e1e1, 9 #5484ed, 10 #51b749, 11 #dc2127.

## Email formatting

- Prefer plain text. Use `--body-file` for multi-paragraph messages (or `--body-file -` for stdin).
- Same `--body-file` pattern works for drafts and replies.
- `--body` does not unescape `\n`. If you need inline newlines, use a heredoc or `$'Line 1\n\nLine 2'`.
- Use `--body-html` only when you need rich formatting.
- HTML tags: `<p>` for paragraphs, `<br>` for line breaks, `<strong>` for bold, `<em>` for italic, `<a href="url">` for links, `<ul>`/`<li>` for lists.
- Example (plain text via stdin):

  ```bash
  gog gmail send --to recipient@example.com \
    --subject "Meeting Follow-up" \
    --body-file - <<'EOF'
  Hi Name,

  Thanks for meeting today. Next steps:
  - Item one
  - Item two

  Best regards,
  Your Name
  EOF
  ```

- Example (HTML list):
  ```bash
  gog gmail send --to recipient@example.com \
    --subject "Meeting Follow-up" \
    --body-html "<p>Hi Name,</p><p>Thanks for meeting today. Here are the next steps:</p><ul><li>Item one</li><li>Item two</li></ul><p>Best regards,<br>Your Name</p>"
  ```

## Notes

- **Account:** Set `GOG_ACCOUNT=you@gmail.com` (or use `--account`) to avoid repeating it. Use `gog auth alias set work work@company.com` for short names.
- **Scripting:** Prefer `--json` and `--no-input`. Use `GOG_JSON=1` to default to JSON.
- **Least-privilege:** `gog auth add ... --services drive,calendar --readonly` for read-only; for Drive only: `--drive-scope readonly` or `--drive-scope file`.
- **Sheets:** Pass values via `--values-json` (recommended) or inline rows.
- **Confirm** before sending mail or creating/updating events.
- **Thread vs message:** `gog gmail search` returns one row per thread; `gog gmail messages search` returns every individual message.
- **Official docs:** Full command list and options: [gogcli.sh](https://gogcli.sh), [GitHub steipete/gogcli](https://github.com/steipete/gogcli). Run `gog <service> --help` for subcommands.
