---
name: gcloud-readonly
description: Use before any `bq` or `gcloud` call that reads the company BigQuery data lake or analytics (dbt) datasets, e.g. querying platform events, dimensions, applications or jobs. Gives the env prefix for the read-only service account so no `gcloud auth login` is needed. Not for writes, IAM, KMS/sops or other GCP projects; those still need Patrick's own login.
---

# Read-only gcloud / bq

A read-only service account lives in its own gcloud config dir. Prefix every call:

```sh
CLOUDSDK_CONFIG=$HOME/.config/gcloud-claude bq ls --projects          # the projects it can read
CLOUDSDK_CONFIG=$HOME/.config/gcloud-claude bq ls <project>:
CLOUDSDK_CONFIG=$HOME/.config/gcloud-claude bq query --use_legacy_sql=false --format=csv 'SELECT ...'
```

Shell aliases `bq-ro` and `gcloud-ro` do the same for Patrick's terminal. Use the explicit prefix in Bash calls.

Never use bare `gcloud`/`bq` for these reads: that is Patrick's user login, which expires through the Workspace re-auth policy.

## What it can do

- Read BigQuery data in the prod data lake and prod analytics projects.
- Run query jobs in the config's default project, which is billed for them.
- No writes, no other projects, no staging. Permission errors there are expected; ask Patrick instead of retrying.

The data holds personal data. Select only the columns the question needs.

## How the key gets there

`key.json` is an agenix secret (`gcloud-claude-key` in `modules/darwin/secrets.nix`), symlinked to the agenix RAM disk. The config reads it through `auth/credential_file_override`. Never run `gcloud auth activate-service-account` here: it copies the key into `credentials.db` on disk.

## Rotate or revoke

Runs under Patrick's own login (bare `gcloud`). Write the new key to a temp file, never to the symlink.

```sh
SA=$(jq -r .client_email ~/.config/gcloud-claude/key.json)
gcloud iam service-accounts keys list --iam-account $SA
gcloud iam service-accounts keys create /tmp/k.json --iam-account $SA
age -r "<pubkey from nix-secrets/secrets.nix>" -o ~/nix-secrets/gcloud-claude-key.age /tmp/k.json && rm /tmp/k.json
# commit + push nix-secrets, `nix flake update secrets` in nix-config, build-switch
gcloud iam service-accounts keys delete <OLD_KEY_ID> --iam-account $SA
```
