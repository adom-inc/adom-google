# Migrating `adom-gmail` → `adom-google`

`adom-google` is a superset of `adom-gmail`. The migration is designed to be zero-touch.

## What changed

| Old (`adom-gmail`)                 | New (`adom-google`)                          |
|------------------------------------|----------------------------------------------|
| `adom-gmail attachments <id>`      | `adom-google gmail attachments <id>`         |
| `adom-gmail read <id> <att> [-o]`  | `adom-google gmail read <id> <att> [-o]`     |
| `adom-gmail ics <id>`              | `adom-google gmail ics <id>`                 |
| `adom-gmail init <id> <secret>`    | `adom-google init <id> <secret>`             |
| `adom-gmail auth`                  | `adom-google auth` (Gateway) / `auth --manual` |
| `adom-gmail auth-code '<code>'`    | `adom-google auth-code '<code>'`             |
| —                                  | `adom-google contacts create/list/search`    |
| scope: `gmail.readonly` only       | `gmail.readonly` + `contacts` (extensible)   |
| auth: localhost loopback paste     | **Adom OAuth Gateway** (loopback as fallback) |

## Nothing breaks

- **`adom-gmail` still works.** It's now a thin shim (`bin/adom-gmail`) that prints a
  deprecation line and `exec`s the matching `adom-google` subcommand. The original script
  is preserved at `the source repo (git history)`.
- **Old config is auto-imported.** On first `adom-google` run, if
  `~/.config/adom-google/config.json` is absent but `~/.config/adom-gmail/config.json`
  exists, its `client_id` / `client_secret` / `refresh_token` are imported and tagged with
  `scopes: [gmail.readonly]`.

## One action to unlock contacts

The imported refresh token only carries `gmail.readonly`, so People API calls would `403`.
Run **`adom-google auth`** once to re-consent with the full scope set
(`gmail.readonly` + `contacts`). After that, `contacts create/list/search` work and Gmail
keeps working unchanged.

## Rollback

`cp the source repo (git history) ~/.local/bin/adom-gmail` restores the original standalone tool.
Its config at `~/.config/adom-gmail/config.json` is untouched by the migration.
