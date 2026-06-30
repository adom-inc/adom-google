# adom-google

**Drive your entire Google Workspace from the terminal — and let your AI do it.**

One CLI (and one clean surface for an AI agent) that reads and writes **Gmail, Drive,
Sheets, Docs, Slides, Calendar, Tasks, Contacts, and Google Chat** — plus a generic
`api` passthrough that hits **any** Google API at all. No per-user Google Cloud project,
no client secrets copied onto anyone's machine, one consent click, and you're driving the
whole board.

> **Used every day at [Adom](https://adom.inc).** The entire Adom team runs adom-google as
> part of their daily workflow — filing quotes into Sheets, generating briefs in Docs,
> posting to Chat, dropping Calendar events, reading invoice attachments out of Gmail — all
> from the terminal and through Claude. It just works. This page is the same tool they use,
> released for everyone.

---

## Why this exists

The official Google connectors let an AI *read* your mail and calendar. They don't let it
*do the work* — create a spreadsheet, fill a doc template, build a deck, manage Drive
sharing, post to a Chat space. adom-google does, across the whole suite, with a single
token and zero per-API glue code:

```bash
adom-google api -X POST https://sheets.googleapis.com/v4/spreadsheets -d '{"properties":{"title":"BOM"}}'
adom-google api -X POST https://docs.googleapis.com/v1/documents -d '{"title":"Project brief"}'
adom-google api -X POST https://www.googleapis.com/calendar/v3/calendars/primary/events -d '{"summary":"Kickoff","start":{...},"end":{...}}'
adom-google api -X POST https://chat.googleapis.com/v1/spaces/<id>/messages -d '{"text":"shipped"}'
adom-google api  https://www.googleapis.com/drive/v3/files -q q="name contains 'invoice'"
```

That's the magic: **any Google endpoint is one `adom-google api` call away**, signed with
your token. Typed shortcuts (`gmail`, `contacts`) wrap the common flows; the passthrough
covers everything else.

---

## How the auth works (read this — it's the whole trick)

Google OAuth for a fleet of machines is normally painful: every container has a different
hostname, every user would need their own Cloud project, and the client secret would end up
copied everywhere. adom-google solves all three with a tiny **OAuth gateway service
container** that acts as a **confidential-client token broker**:

1. You run `adom-google auth`. It opens **one** Google consent screen (your own Workspace
   account). You click **Allow** once.
2. Google redirects to the gateway's single fixed callback. The **gateway** does the
   code → token exchange **and** every future refresh — because the **client secret lives
   only on the gateway**, never on your machine.
3. Your container stores just a refresh token (`0600`). It asks the gateway for fresh access
   tokens as needed. **No secret ever touches your machine, ever.**

One consent, long-lived, secret stays in exactly one hardened place. (Architecture +
source for the gateway: [`adom/service-oauth`](https://wiki.adom.inc/adom/service-oauth).)

---

## Getting your own auth — pick your path

The **code** is open source and ships with **no OAuth provider baked in** — it has no idea
which gateway or Google client to use until you give it one. That "provider" (gateway URL +
client_id) is the only account-specific piece. Four ways to get one:

### 1. You're at Adom → just use it
```bash
adom-wiki pkg install adom/adom-google-adom   # pulls the CLI + drops the Adom provider config
adom-google setup                  # asks: safe mode (no delete) or full mode?
adom-google auth                   # one Allow click — done
```
(`adom-google-adom` is a tiny private, Adom-only package that writes the Adom provider; the
public `adom-google` package contains none of Adom's infrastructure.)

### 2. Any other org → self-serve onboarding (the AI sets up Google *for* you)
This is the one most teams want. You don't touch the Google Cloud Console — **your AI drives
your own browser through it**, auto-filling every field, while you watch and click the couple
of buttons Google reserves for a human:

```bash
adom-wiki pkg install adom/adom-google         # the open-source CLI
adom-google onboard --org <your-org>   # the AI takes it from here
```

Your team gets its **own** Google OAuth client (you own it, you control it), and your
**client secret never leaves your machine** — Adom only lends a shared callback URL. Full
walkthrough with screenshots below: **[Onboarding your org](#onboarding-your-org--the-ai-sets-up-google-for-you)**.

### 3. Prefer we run it for you → managed
Email **support@adom.inc**. We stand up a dedicated OAuth gateway container for your org
(~**$5/month**) wired to a Google client for your domain; your whole team gets the full
capability set with zero console wrestling and zero secret management on your side.

### 4. Self-host the gateway too → fully DIY (free, most control)
Fork this repo and run the open-source gateway yourself:
- A Google Cloud project + OAuth client (Internal to your Workspace for long-lived tokens),
  with all nine APIs enabled (the onboarding flow's one-click enable URL does this for you).
- The open-source OAuth gateway ([`adom/service-oauth`](https://wiki.adom.inc/adom/service-oauth))
  on a small container, with your client's secret in `creds/<app>.json`.
- Point the CLI at **your** gateway + client (writes `~/.config/adom-google/provider.json`, 0600):
  ```bash
  adom-google provider set --gateway https://your-gateway.example --client-id <your-client-id>
  adom-google provider show     # verify what's resolved (env > provider.json > bundled)
  ```

---

## Onboarding your org — the AI sets up Google *for* you

> **Why this is a big deal.** Once your team is connected, your AI can **read your email**,
> **post in Google Chat on your behalf**, **compose Google Docs**, **build Google Sheets and
> Slides**, and **search Google Drive** — all from the terminal, all in one workflow. Teams
> describe it as a *game-changer*: the AI stops being a chat box and becomes a coworker that
> actually operates your Workspace. The only thing standing between a new org and that unlock
> is a Google Cloud OAuth client — normally a 20-field console slog. So we made the AI do it.

**What happens:** you run one command and the AI drives **your real, logged-in browser**
(via the Adom browser extension / native browser) straight through Google Cloud Console. It
auto-fills the project name, enables all nine APIs in a single click, configures the consent
screen, and — the part everyone fat-fingers — **pastes the exact redirect URI** into your new
OAuth client. You just watch and press the two buttons Google insists a human press (*Create*,
*Allow*). Five minutes, start to finish, and it's gorgeous.

**What you end up with:** your **own** Google OAuth client (Internal to your Workspace — you
own and control it), and your **client secret stays on your machine** (`0600`). Adom's gateway
only relays the one-time sign-in code back to you over a WebSocket — *it never sees your
secret*. (OAuth callbacks are near-zero load, so one Adom container can host the callback for
many orgs at once — that's all the gateway does for you: lend a public callback URL.)

### Step by step

```bash
adom-google onboard --org acme        # prints the plan + the exact values; the skill drives the rest
```

**1 — The plan.** `onboard` lays out every step and the exact values (so nothing is guessed).
The AI reads `adom-google onboard --json` for the machine-readable version it types into the console.

![adom-google onboard prints the step-by-step plan and the exact redirect URI, API list, and consent settings](/blob/app/adom-google/docs/onboard-1-plan.png)

**2 — Enable all nine APIs in one click.** The AI opens the one-shot enable URL (Gmail, Drive,
Sheets, Docs, Slides, Calendar, Tasks, People, Chat all pre-selected) and clicks **Enable** —
nine APIs, one screen, instead of nine separate visits.

![The AI driving Google Cloud Console to enable all nine Workspace APIs at once](/blob/app/adom-google/docs/onboard-2-enable-apis.png)

**3 — Auto-fill the redirect URI (the error-prone part).** When it creates your OAuth client
(*Web application*), the AI pastes the **Authorized redirect URI** verbatim — one wrong
character here is the classic `redirect_uri_mismatch`, so it's never left to hand-typing.

![The AI pasting the exact Authorized redirect URI into the new OAuth client](/blob/app/adom-google/docs/onboard-3-redirect-uri.png)

**4 — Capture the client + authorize.** The AI reads your new Client ID + secret from the final
dialog, stores them on **your** machine (`onboard finish`, secret `0600`), asks you safe-vs-full,
then runs `adom-google auth` — you click **Allow** once and you're live.

![adom-google authorized and driving the whole Workspace after onboarding](/blob/app/adom-google/docs/onboard-4-authorized.png)

The Chat API also needs a one-time "Chat app" config (name/avatar) so `chat spaces` works — the
AI handles that in the same sitting. Full agent playbook: the bundled
**[adom-google-onboarding](/blob/app/adom-google/skills/adom-google-onboarding/SKILL.md)** skill.

---

## What you can drive — the whole board

Every Google Workspace surface, with typed shortcuts for the common flows and the generic
`api` passthrough for everything else. `adom-google setup` asks each user to pick **safe**
(default — nothing scary on the consent screen) or **full** (broad, includes delete):

| App | What you can do | Safe mode | Full mode |
|---|---|---|---|
| **Gmail** | read messages, attachments & `.ics` invites, labels, trash, organize | read + organize | read + organize |
| **Contacts** (People) | create / list / search contacts, store service identities | full read/write | full read/write |
| **Calendar** | create / move / delete events, invite guests, list agenda | events | + manage calendars |
| **Tasks** | create / list / complete task lists & tasks | full | full |
| **Google Chat** | post to spaces, list spaces, read space messages | post + read | post + read |
| **Drive** | upload / download / search / share / organize files | only files this app creates | **all** files incl. delete |
| **Sheets** | create spreadsheets, read/write cells, formulas, formatting | only sheets it creates | **all** spreadsheets |
| **Docs** | create docs, insert/replace text, fill templates | only docs it creates | **all** documents |
| **Slides** | build decks, add slides, replace text/images | only decks it creates | **all** presentations |
| **Any other Google API** | YouTube, Forms, Apps Script, Admin SDK, Photos… | via `api` passthrough | via `api` passthrough |

**Safe mode** uses the narrow scopes (`gmail.modify`, `contacts`, `calendar.events`,
`tasks`, `chat.messages`, `chat.spaces.readonly`, `drive.file`) — the consent screen shows
**no "see & delete ALL your files."** **Full mode** swaps in the broad scopes (`drive`,
`spreadsheets`, `documents`, `presentations`, `calendar`) for whole-board
read/write/delete.

Either way, `api` reaches **any** Google endpoint — your real ceiling is just the scopes you
granted plus your own Google permissions (admin APIs only work for admins).

### See it in action

Read from one app, write to another — in a single flow. Here your AI reads an invoice
attachment out of **Gmail** and posts a summary straight into a **Google Chat** space:

![adom-google reading a Gmail attachment and posting the result into Google Chat](/blob/app/adom-google/docs/chat-reads-email.png)

---

## Recipes — one prompt per app

Talk to your AI in plain English. Each line below is something you'd actually *say*; under it
is the `adom-google` call your agent runs to make it happen. Everything not shown is still one
`api` call away.

**Gmail** — *"Grab the invoice PDF from that email and save it."*
```bash
adom-google gmail attachments <messageId>                 # list parts
adom-google gmail read <messageId> <attId> -o invoice.pdf
```

**Contacts** — *"Save this new fab vendor; put the portal login in the notes."*
```bash
adom-google contacts create --name "Jane Fab" --org "Fab Co" --notes "portal login in 1Password"
```

**Calendar** — *"Put a Rev C bring-up on my calendar Tuesday 2pm and invite the team."*
```bash
adom-google api -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=all" \
  -d '{"summary":"Rev C bring-up","start":{"dateTime":"2026-06-23T14:00:00","timeZone":"America/Chicago"},
       "end":{"dateTime":"2026-06-23T15:00:00","timeZone":"America/Chicago"},
       "attendees":[{"email":"team@yourco.com"}]}'
```

**Tasks** — *"Add 'order solder stencil' to my list."*
```bash
adom-google api -X POST "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks" \
  -d '{"title":"Order solder stencil"}'
```

**Chat** — *"Message Colby that the boards shipped."* — posts as **you** (no webhook prefix):
```bash
adom-google chat spaces                       # find your spaces / space ids
adom-google chat send --to colby@adom.inc "Rev C boards shipped"   # email auto-resolves the DM
adom-google chat send --to spaces/AAQAxxxx "Standup in 5"            # or a space id
adom-google chat send --to spaces/AAQAxxxx @release-notes.md          # @file / '-' = stdin
adom-google chat read --from colby@adom.inc --limit 10               # recent messages
```
> **`chat` vs [adom-gchat](https://wiki.adom.inc/adom/adom-gchat):** adom-google posts as
> **you** and does the **full Chat lifecycle** — post, read, edit, delete, react, as your own
> Google identity (clean, no prefix). For an **attributed bot post** to a team space
> (deploys/alerts as *"Kel (on behalf of …)"*), use
> **[adom-gchat](https://wiki.adom.inc/adom/adom-gchat)** — the post-only webhook bot. Two
> tools, one boundary: post as yourself with adom-google, the attributed bot with adom-gchat.

**Drive** — *"Find every Gerber zip, then upload my new one."*
```bash
adom-google api "https://www.googleapis.com/drive/v3/files" -q q="name contains 'gerber'"
adom-google api -X POST "https://www.googleapis.com/upload/drive/v3/files?uploadType=media" \
  --upload-file rev-c-gerbers.zip --content-type application/zip
```

**Sheets** — *"Make a Rev C BOM and drop in the first rows."*
```bash
adom-google api -X POST "https://sheets.googleapis.com/v4/spreadsheets" -d '{"properties":{"title":"Rev C BOM"}}'
adom-google api -X PUT "https://sheets.googleapis.com/v4/spreadsheets/<id>/values/A1?valueInputOption=RAW" \
  -d '{"values":[["Ref","Part","Qty"],["C1","100nF 0402","12"]]}'
```

**Docs** — *"Start a bring-up checklist doc."*
```bash
adom-google api -X POST "https://docs.googleapis.com/v1/documents" -d '{"title":"Rev C bring-up checklist"}'
```

**Slides** — *"Spin up a board-review deck."*
```bash
adom-google api -X POST "https://slides.googleapis.com/v1/presentations" -d '{"title":"Rev C board review"}'
```

**YouTube** — *"Upload the 3D walkthrough of my latest circuit board as unlisted."*
```bash
# 1) start a resumable upload with the metadata — returns an upload URL in the Location header
adom-google api -X POST \
  "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status" \
  -d '{"snippet":{"title":"Rev C — 3D board walkthrough",
                  "description":"Flythrough rendered from the tscircuit / chipfit 3D viewer"},
       "status":{"privacyStatus":"unlisted"}}'

# 2) PUT the rendered .mp4 to that upload URL — binary body via --upload-file
adom-google api -X PUT "<upload-url>" --upload-file board-walkthrough.mp4 --content-type video/mp4
```
> The YouTube recipe needs the **YouTube Data API v3** enabled and the `youtube.upload` scope on
> your client (it rides the very same gateway). Pair it with the tscircuit/chipfit 3D viewer's
> recording and a board becomes a shareable flythrough on YouTube in two commands.

**…anything else** — Forms, Apps Script, Photos, Admin SDK, Maps — same pattern: `adom-google api <url>`.

---

## Commands

```bash
# Generic passthrough — any Google API
adom-google api <url> [-X METHOD] [-d '<json>'|@file] [-q key=val ...]

# Contacts (People API) — store service identities, look people up
adom-google contacts create --name "..." [--org O] [--email a@b.com] [--notes "..."]
adom-google contacts list | search <query>

# Gmail (read) — attachment bytes + .ics invites the connectors can't reach
adom-google gmail attachments <messageId> | read <messageId> <attId> | ics <messageId>

# Google Chat — post/read as YOURSELF (no webhook "(on behalf of)" prefix)
adom-google chat spaces | dm <email> | read --from <space|email>
adom-google chat send --to <space-id|email> "<text>|-|@file" [--thread <key>]

adom-google status     # what's authorized (never prints secrets)
```

## Security

- **No client secret on your machine** — the gateway holds it and brokers every exchange/refresh.
  In broker mode the secret lives only on the gateway's `creds/<app>.json` (0600); the package
  ships none.
- Refresh token stored `0600`; secrets are never echoed to stdout/stderr or logs.
- The gateway only ever sees a short-lived auth code or a refresh token over an authenticated
  channel — never your data.

### Where your credentials live (and what's safe to commit)

Nothing secret is ever stored in this repo or any package. Two local files hold your state,
both outside the repo, both `0600`:

```jsonc
// ~/.config/adom-google/config.json   — your live auth (NEVER committed)
{ "refresh_token": "***", "mode": "safe", "scopes": ["…"], "broker": true }

// ~/.config/adom-google/provider.json — which gateway/client to use (no secret)
{ "gateway_url": "https://<your-gateway>", "client_id": "<public-oauth-client-id>", "app": "adom-google" }
```

The `client_id` is a **public** OAuth identifier by design and the gateway URL is just a
hostname — neither is a cryptographic secret, so a `provider.json` is safe to ship. The
**client secret, refresh token, and access tokens are never committed** anywhere (they live
only in the gateway and your `0600` config). The wiki page is a git repo: anything committed
is permanent and would be exposed if a private page ever went public — so we mask every value
in docs and commit only shapes.

---

## Open source (MIT) — fork it, improve it, publish it back

adom-google is **open source under the [MIT License](LICENSE)**. Use it, change it, ship it —
do whatever you want with the code. The whole reason it lives on the wiki is so the community
improves it *together*:

1. **Fork & hack to your heart's content.** Every wiki page is a real git repo (see the **Files**
   tab), and `adom-wiki pkg install adom/adom-google` drops the full source on your machine. Add a
   subcommand, wire up another Google API, fix a bug, change anything you like.
2. **Publish your changes back so everyone benefits.** Bump the version in `package.json`, then:
   ```bash
   adom-wiki pkg publish --org <you>        # builds a tarball + pushes it to the wiki page
   ```
   Your improvement is instantly live for the **entire community** to `adom-wiki pkg install`. That's
   the model — everyone pulls from, and pushes to, the same page. Send a fix, ship a feature,
   and every other user (and every Adom employee) picks it up.

### One caveat — *only* when Adom hosts your OAuth

The **code** is 100% yours under MIT, forever. The one thing that isn't is **Adom's hosted OAuth
gateway** — and that caveat applies **only if you use it**:

- **Adom-hosted path** (Adom employees via `adom-google-adom`, or any org on the managed
  ~$5/mo plan): your sign-in and token refresh run through **Adom's cloud gateway**, and the
  shared client's Google API calls count against **Adom's quota**. That gateway + quota is an
  **Adom service, subject to change** (rate limits, availability, terms).
- **Self-hosted path** (you run your own gateway + Google client — see *Getting your own auth*):
  it's **entirely yours** — your gateway, your Google client, your quota. **No Adom dependency
  whatsoever**, nothing Adom can change out from under you.

So: want zero strings attached? Self-host. Want zero setup? Use Adom's hosted gateway and accept
that it's a service Adom runs.

---

Built and battle-tested at **[Adom](https://adom.inc)**. Questions, or want us to host your
org's OAuth? **support@adom.inc**.

> [Read the full SKILL.md source](/blob/app/adom-google/SKILL.md)
