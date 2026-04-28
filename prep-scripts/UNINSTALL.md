# Uninstall / Rollback Guide

Steps to completely reverse the Claude Code with Bedrock installer (`install.sh`).

## What the installer does

1. Creates `~/claude-code-with-bedrock/` and copies binaries + config into it
2. Adds a `[profile claudecode-dev-us-east-1]` entry to `~/.aws/config`
3. Copies/overwrites `~/.claude/settings.json` with OTEL settings (if monitoring enabled)

---

## Step 1: Remove the installed binaries and config

```bash
rm -rf ~/claude-code-with-bedrock/
```

This removes:
- `credential-process` — the authentication binary
- `otel-helper` and `otel-helper-bin` — the monitoring helper binaries
- `config.json` — the embedded configuration

---

## Step 2: Remove the AWS CLI profile

Open `~/.aws/config` in a text editor:

```bash
nano ~/.aws/config
```

Find and delete the block that looks like this:

```
[profile claudecode-dev-us-east-1]
credential_process = /Users/your-username/claude-code-with-bedrock/credential-process --profile claudecode-dev-us-east-1
region = us-east-1
```

Also delete any blank lines left behind. Save and exit (`Ctrl+X`, `Y`, `Enter` in nano).

The installer also creates a backup at `~/.aws/config.bak` — you can restore it if needed:

```bash
cp ~/.aws/config.bak ~/.aws/config
```

---

## Step 3: Restore Claude Code settings (if monitoring was installed)

The installer may have overwritten `~/.claude/settings.json`. If you had existing Claude Code settings before installing, restore them.

If you had no prior settings, simply delete the file:

```bash
rm ~/.claude/settings.json
```

If you want to remove only the OTEL-related entries (and keep other settings), open the file and remove the `env` block entries for `OTEL_EXPORTER_OTLP_ENDPOINT`, `AWS_REGION`, and the `CLAUDE_CODE_OTEL_HELPER` path.

---

## Verify everything is removed

```bash
# Should return "No such file or directory"
ls ~/claude-code-with-bedrock/

# Should show no ClaudeCode profile
cat ~/.aws/config | grep -A3 "claudecode-dev-us-east-1"

# Check settings.json is clean
cat ~/.claude/settings.json
```
