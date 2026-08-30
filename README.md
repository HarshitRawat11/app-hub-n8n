# n8n — workflow automation

Workflow source for the self-hosted n8n instance that runs alongside app-hub. Part of the [app-hub](https://github.com/HarshitRawat11) project.

This repo holds **workflow definitions as code** — the JSON exported from n8n, version-controlled so changes are reviewable and recoverable. It does not hold credentials.

---

## Layout

```
n8n/
├── .env.example        # Template for connection settings — copy to .env
├── .env                # Your real API key. GITIGNORED. Never commit.
├── workflows/          # One JSON file per workflow, pulled from the instance
└── scripts/
    └── pull-workflows.sh   # Fetch all workflows from the API into workflows/
```

---

## Setup

```bash
cp .env.example .env
```

Then open `.env` and fill in:

- `N8N_BASE_URL` — your instance, no trailing slash (e.g. `http://localhost:5678`)
- `N8N_API_KEY` — from **Settings → n8n API → Create an API key** in the n8n UI

`.env` is gitignored. Verify that before you paste anything into it:

```bash
git check-ignore -v .env
```

If that prints a rule, you're safe. If it prints nothing, stop and fix `.gitignore` first.

---

## Pulling workflows

`jq` lives in WSL, not on Windows, so run this from WSL:

```bash
wsl -e bash -lc "cd /mnt/c/Users/harshit.rawat/Documents/Projects/app-hub/n8n && ./scripts/pull-workflows.sh"
```

This writes one file per workflow into `workflows/`, stripping `createdAt`, `updatedAt`, and `versionId` so that re-pulling an unchanged workflow produces an empty diff rather than noise.

**Alternative — the n8n CLI.** Self-hosted only, and it needs the container running:

```bash
docker exec -it <n8n-container> n8n export:workflow --all --separate --output=/tmp/workflows/
```

`--separate` gives one file per workflow instead of a single array — much better for git.

---

## Before every commit

Exported workflow JSON contains credential **names and IDs**, not the secret values — n8n keeps those encrypted in its own database, and they never appear in a workflow export.

But a secret you typed directly into a node parameter — an API key pasted into an HTTP Request header, a token embedded in a URL — is just a parameter, and it *does* get exported. Check:

```bash
grep -riE '(api[-_]?key|token|secret|password|bearer)' workflows/ | grep -vi '"name"'
```

Hits that look like real values mean that secret belongs in an n8n credential instead of a node parameter. Move it there and re-pull.

---

## Security rules

These are not optional. The n8n API key grants full read, write, and execute access to every workflow on the instance — and your workflows are the connections to everything else you've wired up.

- **Never commit `.env`.** It is gitignored; keep it that way.
- **Never paste the API key into a chat window**, including with Claude Code. Commands reference `$N8N_API_KEY`; the value stays on disk.
- **Never run `curl -v`** against the API. Verbose mode prints request headers — API key included — straight into the terminal and the session transcript.
- **Never `cat` or `echo` `.env`** or the variables sourced from it.
- **Never commit credential exports.** `n8n export:credentials` writes real secrets, and with `--decrypted` writes them in plain text. `.gitignore` blocks `credentials/` and `*credentials*.json` — do not weaken those rules.
- Set an expiry on the API key if your n8n version supports it.

If the key is ever exposed: revoke it in **Settings → n8n API** immediately and issue a new one. Revocation is instant and cheap; assuming it was fine is not.

### On the encryption key

n8n encrypts stored credentials with an encryption key generated on first launch and kept in `~/.n8n`. It is not in this repo and must not be.

It matters for one reason: **if you lose it, every stored credential becomes undecryptable** and has to be re-entered by hand. Back it up somewhere outside this repo — a password manager is the right place. Restoring an n8n instance without it restores the workflows but none of their connections.

---

## Reference

- [n8n API authentication](https://docs.n8n.io/api/authentication/) — the `X-N8N-API-KEY` header
- [n8n public API](https://docs.n8n.io/api/) — endpoint reference. Note the public API is `/api/v1/...`; the `/rest/...` paths seen in forum posts are the internal API the UI uses and change without notice
- [Export and import workflows](https://docs.n8n.io/workflows/export-import/)
- [CLI commands](https://docs.n8n.io/hosting/cli-commands/)
- [Setting a custom encryption key](https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/)
