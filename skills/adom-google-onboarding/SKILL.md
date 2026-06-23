---
name: adom-google-onboarding
description: Hand-hold a brand-new ORG through standing up its OWN Google Workspace OAuth client so adom-google works for their whole team — read mail, post Google Chat on their behalf, build Slides/Sheets/Docs, search Drive. You drive the user's REAL logged-in browser (adom-desktop nbrowser_* extension; pup native-mode fallback) to Google Cloud Console, AUTO-FILL the fields (especially the error-prone redirect URI), capture the new client_id + client_secret, and wire it in RELAY mode (their secret stays 0600 on their box; Adom only lends its shared callback URL — it never sees the secret). Use when a NON-Adom org wants to get going themselves — triggers: onboard my org/company to adom-google, set up google workspace for my team, configure google oauth for <company>, get my company on adom-google, self-serve google setup, "we want to use adom-google at <org>", set up the google cloud project, create our oauth client. (For an Adom EMPLOYEE, skip all this — they install adom-google-adom and just run auth. This skill is for everyone else.)
---

# adom-google — Org Onboarding (drive the browser, auto-configure Google)

Goal: take a new org from *nothing* to *"the AI is reading our mail, posting in Chat, and building
decks"* in one guided sitting. The hard part — creating a Google Cloud OAuth client — is normally a
20-field console slog. You do it FOR them: drive their real browser, auto-fill every field, pause only
for the clicks Google forces a human to make. Pristine, billboard-grade setup.

## The architecture you're wiring (know this cold)

- The org creates **their own** Google Cloud project + OAuth client (Internal to their Workspace).
- Their OAuth client's **Authorized redirect URI = Adom's shared gateway `/callback`** — a public,
  multi-tenant **relay**. Any org can register a one-time `state` over its WebSocket and get the auth
  code relayed back. Near-zero load; no per-org config on the gateway.
- The org's **client secret stays on the org's own container** (`~/.config/adom-google/provider.json`,
  `0600`) in **RELAY mode** (`broker:false`). Adom's gateway only relays the `code`; the org's CLI
  exchanges it and refreshes locally with their own secret. **Adom never holds their secret.**
- Result: the org owns everything; Adom just lends a callback URL. (Adom *employees* use BROKER mode
  via `adom-google-adom`, where the secret lives on the gateway — different package, not this flow.)

## Get the exact values FIRST (single source of truth)

```bash
adom-google onboard --org <slug> --json
```

Returns `redirect_uri`, `enable_apis_url` (one click → all 9 APIs), `apis[]`, `scopes_safe/full`,
`consent` (User type = **Internal**, app name), and `console{}` deep links. **Every field you type
comes from here** — never hand-author a redirect URI or API id.

## Which browser surface

You need the user's **real, logged-in Google admin session**. Use the **extension** (`nbrowser_*`) —
it IS their everyday Chrome/Edge with their Workspace login + device enrollment already active. Pup
Chrome-for-Testing has no logins; pup *native-mode* is the fallback if the extension is unavailable.

```bash
adom-desktop --target AdomLapper nbrowser_status     # connected? which browser?
```

If "not connected": the target profile has no open Chrome window — ask the user to open Chrome (any
window) in the profile that's signed into their Workspace, then `nbrowser_rescan`. Fallback to pup:
`adom-desktop browser_open_window '{"sessionId":"gcp","nativeBrowser":"chrome","nativeProfile":"Default","url":"https://console.cloud.google.com"}'`.

> ⚠ **Confirm the signed-in account first.** Drive to `https://console.cloud.google.com`, screenshot,
> and verify the top-right account is the user's **Workspace admin** (not a personal @gmail). Creating
> the project under the wrong account is the #1 way this goes sideways. If wrong, have them switch
> accounts in Chrome before continuing.

## Drive loop (repeat for every step)

1. `nbrowser_navigate` to the deep link from the config.
2. `nbrowser_screenshot` → **read it** (don't assume the DOM; Google Console mutates constantly).
3. Act with **trusted** input: `nbrowser_type {selector,text}` to fill, `nbrowser_click {selector}` to
   click. Selectors are modal-aware; prefer visible text / `aria-label` (`[aria-label="Create"]`,
   `button:has-text("Enable")`). If a selector misses (`elementsMatched:0`), screenshot again and try a
   coordinate click (`nbrowser_input_dispatch {type:"click",x,y}`) off the screenshot.
4. `nbrowser_screenshot` again to confirm the result before moving on.
5. Narrate with `nbrowser_caption {text:"Step 3/6 — enabling APIs…"}` so the user follows along, and
   `desktop_bring_to_front {titleContains:"Google Cloud"}` so they can watch.
6. **Shotlog every screenshot** with a description and hand the user the phone URL (per the all-screenshots
   rule) so they can audit each step from their phone.

### Always pause for the human on these (Google requires a real click; never fake it)
- Account chooser / re-auth prompts.
- The final **Create** on the OAuth client.
- The OAuth consent screen **Publish/Save** if a confirm dialog appears.
Show a screenshot, say exactly what to click, wait, then continue. Auto-fill everything *up to* these.

## The six steps

**1 · Project.** Navigate `console.project_create`. Auto-fill the project name
(`type` into the Project name field) e.g. `adom-workspace`. Pause for the user to click **Create**.
Wait for the create to finish (poll screenshots / the notifications bell), then make sure the new
project is the **active** project (project picker, top bar).

**2 · Enable all nine APIs in one click.** Navigate to `enable_apis_url` (it pre-selects all 9). Screenshot.
Click **Enable**. This is the single biggest time-saver — one screen instead of nine. Confirm "APIs enabled."

**3 · OAuth consent screen → Internal.** Navigate `console.consent_screen`. Choose **User type = Internal**
(critical — Internal = only their Workspace can sign in, and gives long-lived refresh tokens). Auto-fill
App name (`consent.app_name`), user support email (their admin), developer contact (their admin). Save.
*(Internal apps need no verification and skip the scary "unverified app" screen.)*

**4 · Create the OAuth client.** Navigate `console.create_client`. Application type = **Web application**.
Auto-fill Name (`consent.client_name`). Then the load-bearing move: **AUTO-FILL the Authorized redirect
URI** with `redirect_uri` from the config — paste it verbatim, never make the user type it (one wrong
char = `redirect_uri_mismatch` later). Screenshot to prove it matches. Pause for the user to click **Create**.

**5 · Capture the credentials.** The post-create dialog shows **Client ID** + **Client secret**. Read them:
`nbrowser_eval` to scrape the dialog text, and ALSO screenshot as a backup. Verify the client_id ends in
`.apps.googleusercontent.com` and the secret looks like `GOCSPX-…`. Then store them — **secret to the CLI,
never echoed into chat**:

```bash
adom-google onboard finish --org <slug> --client-id "<id>" --client-secret "<secret>"
```

This writes `provider.json` (`0600`, `broker:false`). The secret lives only on the user's box.

**6 · Chat app config (once).** Navigate `console.chat_config` (Chat API → Configuration). Set an app
name + avatar + "Make available to … your domain." Without this, `chat spaces` 404s "Chat app not found."
This is the one step pure-data tools skip; do it so `adom-google chat` works out of the box.

## Authorize + verify (the payoff)

ASK the user **safe vs full** (use AskUserQuestion — never pick for them; safe = no "delete all" on the
consent screen, the recommended default). Then:

```bash
adom-google auth            # safe   (or: adom-google auth --full)
```

Print the consent URL; drive their browser to it (`nbrowser_navigate`), screenshot the consent, pause
for **Allow**. The gateway relays the code; the CLI exchanges it locally. Then prove it works — small,
real, delightful:

```bash
adom-google status                                   # mode + "Auth: relay (your secret 0600 here…)"
adom-google chat spaces                              # lists their spaces
adom-google api https://www.googleapis.com/drive/v3/about?fields=user   # "you're signed in as …"
```

End by showing them ONE magic moment — e.g. compose a Google Doc or post a Chat message — so the
"oh, this is a game-changer" lands immediately.

## Gotchas
- **Wrong Google account** under the project → everything downstream is wrong. Verify in step 0.
- **redirect_uri mismatch** at `auth` time → the client's Authorized redirect URI ≠ `redirect_uri`. Re-open
  the OAuth client, fix the field (auto-fill again), save, retry `auth`. This is why step 4 auto-fills.
- **Internal vs External**: always Internal for an org. External forces app verification + a scary screen.
- **Extension "not connected"** = no open Chrome window in the signed-in profile. Open one, `nbrowser_rescan`.
- **Secrets**: never print the client_secret or refresh token to the transcript/logs. Pass the secret
  straight into `onboard finish`. Screenshots of the secret dialog → shotlog them privately; don't paste
  the secret text into chat.
- **Don't auto-click Create/Allow/Publish** — Google wants a human there, and the user *should* see what
  they're approving. Auto-fill up to the button; let them press it.

## Why this matters (say it to the user)
Once they're authed, their AI can read their email, post Google Chat **on their behalf**, compose Google
Docs, build Google Sheets and Slides, and search Google Drive — all from the terminal. That's the
workflow unlock teams fall in love with. You just made the painful part painless.

Related: [adom-google](/adom/adom-google) (the CLI + full command set) · the `driving-the-extension`
skill (nbrowser_* deep reference) · [adom-gchat](/adom/adom-gchat) (attributed bot posts).
