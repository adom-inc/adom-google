---
name: adom-google
description: "Programmatic read+write access to a user's WHOLE Google Workspace — Gmail, Contacts, Drive, Sheets, Docs, Slides, Calendar, Tasks, Google Chat — plus a generic `api` passthrough to hit ANY Google API. CLI + OAuth only (no browser automation). Public/open-source; used daily by the Adom team. Auth is the account-specific part — Adom employees use it out of the box; other orgs either self-host their own OAuth gateway or email support@adom.inc for a managed OAuth container (~$5/mo). On FIRST-RUN SETUP you MUST ask the user to pick safe mode (no delete) vs full mode (incl. delete) before authorizing. Use when setting up/installing adom-google, authorizing Google, reading Gmail attachments/.ics, creating/listing/searching Contacts, editing Sheets/Docs/Slides, Drive files, Calendar events, posting to Google Chat, or any Google Workspace automation. For a brand-new ORG that needs its own Google OAuth client (non-Adom team getting started), use the companion `adom-google-onboarding` skill — it drives the user's real browser through Google Cloud Console and auto-configures everything. Trigger words — adom-google, install adom-google, set up adom-google, configure adom-google, google workspace cli, edit google sheet/doc/slides, drive upload, calendar event, post to google chat, post to chat as me, message colby, send a chat, dm <person>, gmail attachment, google contacts, people api, safe mode vs full mode, google oauth gateway broker, google api passthrough, self-host oauth, managed oauth container, onboard my org to google, set up google workspace for my company/team, configure google oauth for <org>, get my company on adom-google, create our google cloud oauth client."
---

# adom-google

One CLI for a user's Google Workspace from inside an Adom container. **REST-direct** —
it calls the Google APIs straight, owns auth via the **Adom OAuth Gateway**, and stores a
long-lived refresh token `0600`. No browser automation, no per-user Google Cloud project.

```
adom OAuth layer   one shared Adom OAuth client + Gateway redirect → refresh token (0600)
adom-google        modular wrapper: gmail · contacts · (drive/calendar = +1 scope line)
Google REST APIs   called directly (gmail.googleapis.com, people.googleapis.com, …)
```

## Why REST-direct (not a base-CLI shim)

We evaluated wrapping a base CLI — Google's `googleworkspace/cli` (`gws`, Rust,
Discovery-driven, JSON, agent skills), `gog`/`gogcli` (Go), GAM/GAMADV-XTD3, the
Gemini CLI, and `gcloud`. Conclusion: **call the REST APIs directly.**

- **Auth is the part Adom must own anyway.** One shared internal OAuth client + the
  Gateway's static redirect + a long-lived refresh token is Adom-specific; no base CLI
  speaks it. Adopting one means reverse-engineering its keyring/credential format to
  inject our token — more work than one `requests.post` to the token endpoint.
- **The data surface we need is tiny and stable.** gmail.readonly attachment reads + a
  handful of People API calls. Each is one HTTPS request. A base CLI adds a process
  boundary, an install/version dependency, and output coupling for no benefit at this size.
- **No per-user GCP project.** REST-direct with the shared Adom client satisfies the hard
  constraint. `gws`/`gog`/GAM all push users toward their own OAuth client or `gcloud`.
- **Gemini CLI is the wrong layer** (an AI coding agent, not a Workspace data client) and
  **gcloud can't touch Workspace user data** (GCP-only). `gws` is the closest "official"
  Google Workspace CLI and is a reasonable **future accelerator** if we ever need broad
  Sheets/Docs/Chat coverage — but for Gmail+Contacts it's overkill.

The code is structured so a `gws` backend *could* be slotted behind the same subcommands
later; today the win is zero new runtime dependencies and a clean migration from adom-gmail.

## Onboarding a brand-new org (give a team its OWN Google client)

If a **non-Adom** org wants to get going on their own, they need their own Google OAuth client.
Don't make them slog through Google Cloud Console by hand — use the **`adom-google-onboarding`**
skill, which drives the user's real logged-in browser (adom-desktop `nbrowser_*`) through the
console, auto-fills the fields (especially the redirect URI), captures the new client, and wires
it in RELAY mode (their secret stays `0600` on their box; Adom only lends a shared callback URL).
Kick it off with `adom-google onboard --org <slug>` (or `--json` for the exact values). Adom
employees skip all this — they install `adom-google-adom` and just run `auth`.

## Install

`install.mjs` symlinks the CLI onto PATH automatically. Manual:

```bash
ln -sf <gallia>/skills/adom-google/bin/adom-google ~/.local/bin/adom-google
ln -sf <gallia>/skills/adom-google/bin/adom-gmail   ~/.local/bin/adom-gmail   # deprecation shim
```

Runtime: Python 3 + `requests` (already in the container). The Gateway WebSocket handshake
is implemented in the stdlib (no `ws`/`websockets` package).

## First-run setup — YOU MUST ASK THE USER which mode (REQUIRED)

When setting up adom-google on a user's container for the first time (it's unconfigured —
`adom-google setup` or any command prints a `Hint:` block saying so), **do NOT pick a mode
for them. Ask.** Use `AskUserQuestion` with these two options:

- **Safe mode (recommended default)** — read/organize Gmail, full Contacts, Calendar events,
  Tasks, post+read Google Chat, and only the Drive/Sheets/Docs/Slides files *this app
  creates*. Scopes: `gmail.modify, contacts, calendar.events, tasks, chat.messages,
  chat.spaces.readonly, drive.file`. The Google consent screen shows **no "see & delete ALL
  your files"** — nothing scary.
- **Full mode** — everything safe mode has, but the narrow Drive/Sheets/Docs/Slides/Calendar
  scopes are swapped for broad read/write/**delete** across **all** the user's existing
  files and calendars. Scopes add `drive, spreadsheets, documents, presentations, calendar`.
  Only if they explicitly want full control.

Both modes also expose the generic `adom-google api <url>` passthrough, which can hit **any**
Google API the granted scopes allow (Sheets/Docs/Slides/Drive/Calendar/Chat/Tasks/YouTube/…).

Then run exactly one:
```bash
adom-google auth          # safe mode  (user picked safe)
adom-google auth --full   # full mode  (user picked full — includes delete)
```
The CLI emits this same instruction as `Hint:` lines whenever it's unconfigured, so you'll
be reminded at the exact moment of need even if this skill has been compacted out of context.

## Auth — one consent, long-lived refresh token

```bash
adom-google auth            # SAFE mode (default): no "delete all" on the consent screen
adom-google auth --full     # FULL mode: broad access incl. delete (trusted users)
adom-google auth --manual   # fallback: desktop-client paste flow (combine with --full)
adom-google auth-code '<code>'   # finish --manual
adom-google status          # shows mode + what's authorised (never prints secrets)
```

### How Adom handles the OAuth (Gateway broker flow)

Google requires one fixed `redirect_uri`, but every container has a unique hostname. The
Adom OAuth Gateway gives one static callback for all containers **and** acts as a
confidential-client **token broker**, so the client secret never reaches user containers:

1. `adom-google auth` builds the Google consent URL with
   `redirect_uri = <your gateway>/callback` (from the resolved provider) and a random `state`,
   and opens a WebSocket to the Gateway registering `{state, app:"adom-google", exchange:true}`.
2. The user approves in their browser (their own Google Workspace account).
3. Google redirects to the Gateway `/callback`; the Gateway **does the code→token exchange
   itself** (using the secret it alone holds) and pushes `{type:"tokens", …}` over the WS.
4. The container stores only the **refresh token** `0600` — no client secret. Later refreshes
   go through the gateway's `POST /refresh`, so the secret stays on the gateway forever.

**The package ships NO provider** — no gateway URL, no client_id, nothing Adom-specific. The
provider (`{gateway_url, client_id, app}`) is resolved at runtime, later wins: bundled
`provider.json` → legacy `credentials.json` → `~/.config/adom-google/provider.json` → env
(`OAUTH_GATEWAY_URL`, `ADOM_GOOGLE_CLIENT_ID/SECRET/APP`). With none configured, every command
prints the NO_PROVIDER hint. Adom employees install the private **`adom-google-adom`** package,
which writes the Adom provider (gateway + Internal client_id) to `~/.config/adom-google/provider.json`;
self-hosters run `adom-google provider set --gateway <url> --client-id <id>`. The client secret is
never in any package — in broker mode it lives only on the gateway's `creds/<app>.json` (0600).

If the Gateway is down, `auth --manual` uses a desktop-client loopback paste flow (that one
exchanges locally and does need a client secret via `init`).

### Getting auth as a NON-Adom user (this tool is public)

The code is open source; the OAuth app + gateway are account-specific. If a user is **not**
on Adom's Workspace, the bundled Internal client won't let them sign in — Google blocks
non-adom.inc accounts at consent. Two options to surface to them:

1. **Managed by Adom (easiest):** email **support@adom.inc** — Adom stands up a dedicated
   OAuth gateway container for their org (~$5/mo) wired to a Google client for their domain;
   they then get the full adom-google capability set, same as the Adom team.
2. **Self-host (DIY):** fork the repo; create their own Google Cloud project + OAuth client
   (Internal to their Workspace), enable the APIs they need, run the open-source OAuth gateway
   (`john/service-oauth`) with their client secret in `creds/<app>.json`, then point the CLI at
   theirs: `adom-google provider set --gateway https://their-gateway --client-id <their-id>`
   (writes `~/.config/adom-google/provider.json`). Google **Chat** also needs a one-time
   Chat-app configuration (name/avatar/description) in the Cloud console's Chat API →
   Configuration tab, or `spaces.*` calls 404 with "Chat app not found".

## Commands

```bash
# Generic passthrough — ANY Google API, signed with the user's token. This is the workhorse:
# Sheets/Docs/Slides/Drive/Calendar/Chat/Tasks/YouTube all go through here, zero per-API code.
adom-google api <url> [-X METHOD] [-d '<json>'|@file] [-q key=val ...] [--raw]
#   e.g. create a sheet:   adom-google api -X POST https://sheets.googleapis.com/v4/spreadsheets -d '{"properties":{"title":"BOM"}}'
#        post to Chat:      adom-google api -X POST https://chat.googleapis.com/v1/spaces/<id>/messages -d '{"text":"shipped"}'
#        calendar event:    adom-google api -X POST https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=all -d '{...}'

# Gmail (read; behaviour-compatible with old adom-gmail)
adom-google gmail attachments <messageId>
adom-google gmail read <messageId> <attachmentId> [-o file]
adom-google gmail ics  <messageId>

# Contacts (People API; read + write)
adom-google contacts create --name "First Last" [--org O] [--title T] \
    [--email a@b.com ...] [--phone +1... ...] [--notes "..."] [--json]
adom-google contacts list [--limit N] [--json]
adom-google contacts search <query> [-v] [--json]

# Google Chat — posts as the SIGNED-IN USER (their own identity, NO attribution prefix).
# This is distinct from `adom-gchat`, which posts via an org webhook with "(on behalf of …)".
adom-google chat spaces [--json]                          # list your spaces (id · type · name)
adom-google chat dm <email> [--json]                      # resolve the 1:1 DM space with a person
adom-google chat send --to <space-id|email> "<text>"      # post; email auto-resolves the DM
#   "<text>" may be '-' (stdin) or '@file'; add --thread <key> to reply in a thread
adom-google chat read --from <space-id|email> [--limit N] [--json]   # recent messages

adom-google status     # mode (safe/full) + what's authorized (never prints secrets)
```

**`chat` vs [adom-gchat](/adom/adom-gchat):** adom-google posts as **you** and does the
**full Chat lifecycle** — post, read, edit, delete, react — as your own Google identity
(clean, no prefix). For an **attributed bot post** to a team space (deploys/alerts as
"Kel (on behalf of john)"), use **[adom-gchat](/adom/adom-gchat)**, the post-only webhook bot.
Rule of thumb: posting *as yourself* ⇒ `adom-google chat`; an *attributed bot announcement* ⇒
`adom-gchat`. The `chat.messages` + `chat.spaces.readonly` scopes are in both safe and full
mode, so this works out of the box once authorized.

We use Google Contacts to store **service identities** (portal/account metadata for an API
vendor), e.g. the JPMorgan Payments developer portal. Keep secrets (client secrets, portal
passwords) in a password manager — **never** in a contact's notes.

## Adding Drive / Calendar

Add the scope to `SCOPES` at the top of `bin/adom-google`, re-run `adom-google auth`, and
add a few REST calls against `www.googleapis.com/drive/v3` or `/calendar/v3`. Token refresh
and the `_request()` helper are already generic.

## Security

- Config `~/.config/adom-google/config.json` is created `0600`; the client secret and
  refresh token are never echoed to stdout/stderr or logs (`status` prints presence only).
- The Gateway only ever sees the short-lived auth `code`, never tokens or the client secret.

## Migration from adom-gmail

See [MIGRATION.md](MIGRATION.md). Short version: `adom-gmail` is now a forwarding shim;
its old `~/.config/adom-gmail/config.json` is auto-imported on first `adom-google` run
(gmail.readonly only — run `adom-google auth` once to add the `contacts` scope).
