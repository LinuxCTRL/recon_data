#!/bin/bash

# Automation script for Chaos-like dashboard
DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo "Usage: ./sync_recon.sh domain.com"
  exit 1
fi

REPO_DIR="/home/soufiane/work/bbh/recon_data"
BIN_DIR="/home/soufiane/work/bbh/bin"
mkdir -p "$REPO_DIR/$DOMAIN"

echo "[+] Starting recon for $DOMAIN"

# Run recon tools using local binaries
"$BIN_DIR/subfinder" -d "$DOMAIN" -silent | "$BIN_DIR/httpx" -silent -sc -title -td -j > "$REPO_DIR/$DOMAIN/subdomains.json"

# Extract simple list for backward compatibility
jq -r '.url' "$REPO_DIR/$DOMAIN/subdomains.json" > "$REPO_DIR/$DOMAIN/live_subdomains.txt"

COUNT=$(wc -l < "$REPO_DIR/$DOMAIN/live_subdomains.txt")
SIZE=$(du -h "$REPO_DIR/$DOMAIN/live_subdomains.txt" | cut -f1)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "[+] Found $COUNT live subdomains ($SIZE)"

# Update index.json using jq
# If the domain already exists, update its metadata; otherwise, add it.
jq --arg dom "$DOMAIN" --arg count "$COUNT" --arg size "$SIZE" --arg time "$TIMESTAMP" \
  'if any(.[]; .domain == $dom) then 
     map(if .domain == $dom then . + {count: $count, size: $size, updated_at: $time} else . end)
   else 
     . + [{domain: $dom, count: $count, size: $size, updated_at: $time}]
   end' "$REPO_DIR/index.json" > "$REPO_DIR/index.json.tmp" && mv "$REPO_DIR/index.json.tmp" "$REPO_DIR/index.json"

# Git operations
cd "$REPO_DIR"
git add .
git commit -m "Update recon for $DOMAIN - $COUNT live subdomains"
git push -u origin main # Uncomment after setting up remote

echo "[+] Sync finished for $DOMAIN"
