#!/bin/sh
set -euo pipefail

# --- 1) Repositories einrichten ---
export WORKSPACE_REPOSITORY="$INPUT_REPOSITORY"
export CRAWLER_REPOSITORY="$INPUT_CRAWLER"
export OUTPUT_REPOSITORY="$INPUT_OUTPUT"
unset INPUT_REPOSITORY

# --- 2) Crawler klonen ---
echo "Cloning crawler..."
mkdir -p /crawler
export INPUT_REF="$INPUT_CRAWLERREF"
export GITHUB_WORKSPACE="/crawler"
export GITHUB_REPOSITORY="$CRAWLER_REPOSITORY"
node /checkout.js

# --- 3) Crawler-Dependencies installieren ---
echo "Installing crawler dependencies..."
cd /crawler
npm install

# --- 4) Workspace klonen ---
echo "Cloning workspace..."
mkdir -p /workspace
export INPUT_REF="$INPUT_CURRENT_BRANCH"
export GITHUB_WORKSPACE="/workspace"
export GITHUB_REPOSITORY="$WORKSPACE_REPOSITORY"
node /checkout.js

# --- 5) .env in Crawler injecten ---
echo "Injecting .env from workspace..."
touch /workspace/.env
cp /workspace/.env /crawler/.env

# --- 6) Output-Repo klonen (mit Actor-PAT) ---
echo "Cloning output with Actor-PAT..."
mkdir -p /output
export INPUT_REF="$INPUT_BRANCH"
export GITHUB_WORKSPACE="/output"
export GITHUB_REPOSITORY="$OUTPUT_REPOSITORY"
export GITHUB_TOKEN="$INPUT_TOKEN"      # Override für checkout.js
node /checkout.js

# --- 7) Crawler ausführen ---
echo "Running crawler..."
export OUTPUT="/output/$INPUT_OUTPUTFOLDER"
export EMAIL="$INPUT_EMAIL"
export PASSWORD="$INPUT_PASSWORD"
node /crawler/index.mjs

# --- 8) Änderungen committen ---
echo "Committing changes..."
cd /output
git add .
git commit -m "$INPUT_COMMITMESSAGE"

# --- 9) Push changes als Actor ---
echo "Pushing changes as $INPUT_ACTOR to $OUTPUT_REPOSITORY..."

# Remote-URL auf Actor-PAT umbiegen
git remote set-url origin "https://$INPUT_ACTOR:$INPUT_TOKEN@github.com/$OUTPUT_REPOSITORY.git"

# Ungültige credential.helper-Einträge dürfen fehlschlagen
git config --unset-all credential.helper || true

# Debug-Ausgabe: Kontrolle der Origin-URL
git remote -v

# Push durchführen, Helper lokal deaktivieren, optional mit --force
if [ "${INPUT_FORCE:-false}" = "true" ]; then
  git -c credential.helper= \
      push origin "HEAD:${INPUT_BRANCH}" --force
else
  git -c credential.helper= \
      push origin "HEAD:${INPUT_BRANCH}"
fi

exit 0
