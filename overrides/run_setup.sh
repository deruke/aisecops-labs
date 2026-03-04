#!/bin/bash
set -e

echo "Running CTF setup script (aisecops-labs)..."
cd /app

# Debug: Show current directory and contents
echo "Current directory: $(pwd)"
echo "Contents of /app:"
ls -la /app/

# Check if setup.py exists
if [ ! -f "setup.py" ]; then
    echo "ERROR: setup.py not found in /app"
    echo "Looking for setup.py in subdirectories:"
    find /app -name "setup.py" -type f
    exit 1
fi

echo "Processing all template files for environment variable substitution..."

# Use find to locate all .template files in the current directory and all subdirectories.
find . -type f -name "*.template" | while read template_file; do
    clean_template_file="${template_file#./}"
    output_file="${clean_template_file%.template}"
    echo "  Substituting: ${clean_template_file} -> ${output_file}"
    envsubst < "${clean_template_file}" > "${output_file}"
done

echo "Post-processing config for aisecops-labs..."

# Post-process the generated JSON:
# 1. Set access_control={} on all models (make them visible to non-admin users)
# 2. Add OpenAI API endpoint to pipelines config (if configured)
python3 - << 'PYSCRIPT'
import json
import os

config_file = "ctf_config.json"

with open(config_file, "r") as f:
    config = json.load(f)

# Fix 1: Make all models visible to all users
# In Open WebUI: access_control=None means PUBLIC (no restrictions)
# access_control={} means PRIVATE (restricted, nobody granted)
# So we force None to ensure models are visible to non-admin users
for model in config.get("models", []):
    model["access_control"] = None
print("  Set access_control=None on all models (public / no restrictions)")

# Fix 2: Add OpenAI API to pipelines config if configured
openai_url = os.environ.get("OPENAI_API_BASE_URL", "").strip()
openai_key = os.environ.get("OPENAI_API_KEY", "").strip()
if openai_url and openai_key:
    config["pipelines_config"]["base_urls"].append(openai_url)
    config["pipelines_config"]["api_keys"].append(openai_key)
    print(f"  Added OpenAI API endpoint: {openai_url}")
else:
    print("  No OpenAI API configured (using Ollama mode)")

with open(config_file, "w") as f:
    json.dump(config, f, indent=4)

print("  Config post-processing complete")
PYSCRIPT

echo "Starting setup..."
python3 setup.py -c ctf_config.json

if [ $? -ne 0 ]; then
    echo "Setup failed!"
    exit 1
fi

echo "Post-setup: Fixing connection visibility and model access for non-admin users..."

# Post-setup fixes:
# 1. Remove connection_type="external" from OpenAI API connections (admin-only restriction)
# 2. Grant public read access to all challenge models via AccessGrants system
#    (Open WebUI uses AccessGrants table, not the old access_control model field)
python3 - << 'POSTSETUP'
import requests, json, os, time

base_url = os.environ.get("OPENWEBUI_URL", "http://open-webui:8080")

# Authenticate as admin
resp = requests.post(f"{base_url}/api/v1/auths/signin", json={
    "email": os.environ.get("CTF_ADMIN_EMAIL"),
    "password": os.environ.get("CTF_ADMIN_PASSWORD")
})
token = resp.json()["token"]
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# --- Fix 1: Remove connection_type="external" from OpenAI connections ---
resp = requests.get(f"{base_url}/openai/config", headers=headers)
config = resp.json()

print(f"  Current OpenAI connections: {len(config.get('OPENAI_API_BASE_URLS', []))}")

fixed_configs = {}
for key, val in config.get("OPENAI_API_CONFIGS", {}).items():
    if isinstance(val, dict) and val.get("connection_type") == "external":
        fixed = {k: v for k, v in val.items() if k != "connection_type"}
        fixed_configs[key] = fixed
        print(f"  Connection [{key}]: removed connection_type=external")
    else:
        fixed_configs[key] = val

config["OPENAI_API_CONFIGS"] = fixed_configs

resp = requests.post(f"{base_url}/openai/config/update", json=config, headers=headers)
if resp.status_code == 200:
    print("  OpenAI connection config updated - all connections accessible to users")
else:
    print(f"  WARNING: Failed to update config: {resp.status_code} {resp.text[:200]}")

# --- Fix 2: Grant public read access to all challenge models ---
# Open WebUI now uses an AccessGrants table system. Models are only visible to
# non-admin users if they have an AccessGrant record. We set principal_id="*"
# (wildcard = public) with read permission on every challenge model.
print("  Setting public read access on all challenge models...")

# Get all models (as admin)
resp = requests.get(f"{base_url}/api/v1/models/list?page=1", headers=headers)
if resp.status_code != 200:
    print(f"  WARNING: Failed to list models: {resp.status_code}")
else:
    models_data = resp.json()
    items = models_data.get("items", models_data) if isinstance(models_data, dict) else models_data

    public_read_grants = [
        {"principal_type": "user", "principal_id": "*", "permission": "read"}
    ]

    granted = 0
    for model in items:
        model_id = model.get("id") if isinstance(model, dict) else getattr(model, "id", None)
        model_name = model.get("name", model_id) if isinstance(model, dict) else getattr(model, "name", model_id)
        if not model_id:
            continue

        resp = requests.post(
            f"{base_url}/api/v1/models/model/access/update",
            json={
                "id": model_id,
                "name": model_name,
                "access_grants": public_read_grants,
            },
            headers=headers,
        )
        if resp.status_code == 200:
            granted += 1
        else:
            print(f"  WARNING: Failed to grant access for {model_id}: {resp.status_code} {resp.text[:100]}")

    print(f"  Granted public read access on {granted} models")

POSTSETUP

echo "Setup completed successfully!"
