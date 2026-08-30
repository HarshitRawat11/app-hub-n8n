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

## Setup — filling in `.env` (task N-03)

**Step 1.** Copy the template:

```bash
cp .env.example .env
```

**Step 2.** Verify it is gitignored *before* putting a real key in it:

```bash
git check-ignore -v .env
```

Expect `.gitignore:2:.env	.env`. If it prints **nothing**, stop — the file is not ignored and anything you paste in could be committed.

**Step 3.** Get the API key from n8n: open the UI → **Settings** → **n8n API** → **Create an API key**. Set an expiry if your version offers one. Copy it.

**Step 4.** Open `.env` in an editor and fill in both values:

```
N8N_BASE_URL=http://localhost:5678
N8N_API_KEY=<paste here>
```

`N8N_BASE_URL` must have **no trailing slash** — the script appends `/api/v1/...` directly.

**Step 5.** Confirm it loads, without printing the value:

```bash
set -a && . ./.env && set +a && [ -n "$N8N_API_KEY" ] && echo "key set (${#N8N_API_KEY} chars), base=$N8N_BASE_URL"
```

`${#VAR}` gives a variable's length — enough to confirm it loaded and looks plausible, without revealing it.

**Step 6.** Confirm git still does not see it:

```bash
git status --short
```

`.env` must not appear.

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

### Backing up the encryption key (task N-05)

n8n encrypts stored credentials with a key generated on first launch. It is **not** in this repo and must never be.

**Why this is the single most important backup in the n8n setup:** lose the key and every stored credential becomes undecryptable. The workflows survive; every connection they use has to be re-authorised by hand. It also has to be supplied as-is when n8n moves onto EKS (`N-06`) — a fresh instance generates a *new* key, which would orphan every existing credential.

n8n runs locally as:

```bash
docker run -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

So the key lives in the **`n8n_data`** Docker volume, at `/home/node/.n8n/config`. It survives container restarts and recreation — but not `docker volume rm n8n_data`.

**Step 1.** Find your container name:

```bash
docker ps --format "{{.Names}}\t{{.Image}}" | grep -i n8n
```

**Step 2.** Check whether the key is set as an environment variable — if it is, that value is the key and the config file may not exist:

```bash
docker exec <n8n-container> printenv N8N_ENCRYPTION_KEY
```

**Step 3.** Otherwise read it from the config file. **Run this yourself; do not paste the output into a chat window:**

```bash
docker exec <n8n-container> cat /home/node/.n8n/config
```

The `encryptionKey` field is the value to save.

**To avoid it appearing on screen at all**, pipe straight to the clipboard:

```bash
docker exec <n8n-container> cat /home/node/.n8n/config | clip
```

**Step 4.** Paste it into your password manager, labelled clearly (e.g. "n8n encryption key — app-hub"). Not into this repo, not into a note file in the project, not into a chat.

**Step 5.** Sanity-check that you can find it again in six months. That is the entire point of the exercise.

---

## Reference

- [n8n API authentication](https://docs.n8n.io/api/authentication/) — the `X-N8N-API-KEY` header
- [n8n public API](https://docs.n8n.io/api/) — endpoint reference. Note the public API is `/api/v1/...`; the `/rest/...` paths seen in forum posts are the internal API the UI uses and change without notice
- [Export and import workflows](https://docs.n8n.io/workflows/export-import/)
- [CLI commands](https://docs.n8n.io/hosting/cli-commands/)
- [Setting a custom encryption key](https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/)
