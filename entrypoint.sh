#!/bin/sh
set -euo pipefail

# Repositories
export WORKSPACE_REPOSITORY="$INPUT_REPOSITORY"
export CRAWLER_REPOSITORY="$INPUT_CRAWLER"
export OUTPUT_REPOSITORY="$INPUT_OUTPUT"
unset INPUT_REPOSITORY

# 1) Clone crawler
echo "Cloning crawler..."
mkdir -p /crawler
export INPUT_REF="$INPUT_CRAWLERREF"
export GITHUB_WORKSPACE="/crawler"
export GITHUB_REPOSITORY="$CRAWLER_REPOSITORY"
node /checkout.js

# Install crawler dependencies
echo "Installing crawler dependencies..."
cd /crawler
npm install

# 2) Clone workspace
echo "Cloning workspace..."
mkdir -p /workspace
export INPUT_REF="$INPUT_CURRENT_BRANCH"
export GITHUB_WORKSPACE="/workspace"
export GITHUB_REPOSITORY="$WORKSPACE_REPOSITORY"
node /checkout.js

# Inject .env into crawler
echo "Injecting .env from workspace..."
touch /workspace/.env
cp /workspace/.env /crawler/.env

# 3) Clone output, dabei GITHUB_TOKEN auf Actor-PAT setzen
echo "Cloning output with Actor-PAT..."
mkdir -p /output
export INPUT_REF="$INPUT_BRANCH"
export GITHUB_WORKSPACE="/output"
export GITHUB_REPOSITORY="$OUTPUT_REPOSITORY"
export GITHUB_TOKEN="$INPUT_TOKEN"        # Override für checkout.js
node /checkout.js

# 4) Run crawler
echo "Running crawler..."
export OUTPUT="/output/$INPUT_OUTPUTFOLDER"
export EMAIL="$INPUT_EMAIL"
export PASSWORD="$INPUT_PASSWORD"
node /crawler/index.mjs

# 5) Commit changes
echo "Committing changes..."
cd /output
git add .
git commit -m "$INPUT_COMMITMESSAGE"

# 6) Push changes als Actor
echo "Pushing changes as $INPUT_ACTOR to $OUTPUT_REPOSITORY..."
# Remote-URL überschreiben und Credential-Helper abstellen
git remote set-url origin "https://$INPUT_ACTOR:$INPUT_TOKEN@github.com/$OUTPUT_REPOSITORY.git"
git config --unset-all credential.helper
git remote -v    # Debug: zeigt jetzt die Actor-URL

# Push, optional mit --force
if [ "${INPUT_FORCE:-false}" = "true" ]; then
  git push origin "HEAD:$INPUT_BRANCH" --force
else
  git push origin "HEAD:$INPUT_BRANCH"
fi

exit 0
