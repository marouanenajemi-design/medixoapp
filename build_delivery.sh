#!/usr/bin/env bash
# =============================================================================
#  ClinicFlow — Delivery Package Builder
#  Run this script from the project root to produce a clean ZIP for the buyer.
#  Usage:  bash build_delivery.sh
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="clinicflow_delivery_$(date +%Y%m%d)"
OUTPUT_DIR="$HOME/Desktop"
OUTPUT_ZIP="$OUTPUT_DIR/${PACKAGE_NAME}.zip"

echo "======================================================"
echo "  ClinicFlow Delivery Package Builder"
echo "======================================================"
echo "  Project:    $PROJECT_DIR"
echo "  Output:     $OUTPUT_ZIP"
echo "======================================================"

# ------------------------------------------------------------------
# STEP 1 — Safety checks: abort if sensitive files are still present
# ------------------------------------------------------------------
echo ""
echo "[1/6] Running security checks..."

ABORT=false

if [ -f "$PROJECT_DIR/config/master.key" ]; then
  echo "  FAIL: config/master.key exists — REMOVE before delivery!"
  ABORT=true
fi

if [ -f "$PROJECT_DIR/config/master.key.bak" ]; then
  echo "  FAIL: config/master.key.bak exists — REMOVE before delivery!"
  ABORT=true
fi

if [ -f "$PROJECT_DIR/config/credentials.yml.enc.bak" ]; then
  echo "  FAIL: config/credentials.yml.enc.bak exists — REMOVE before delivery!"
  ABORT=true
fi

if [ -f "$PROJECT_DIR/tmp/local_secret.txt" ]; then
  echo "  WARN: tmp/local_secret.txt found — will be excluded from ZIP"
fi

if [ -d "$PROJECT_DIR/heroku" ]; then
  echo "  INFO: heroku/ directory found — will be excluded from ZIP (275 MB)"
fi

if [ "$ABORT" = true ]; then
  echo ""
  echo "  Aborting. Remove the files listed above, then re-run this script."
  echo "  Run the cleanup commands below first:"
  echo ""
  echo "    rm -f config/master.key config/master.key.bak config/credentials.yml.enc.bak"
  echo ""
  exit 1
fi

echo "  OK: No critical sensitive files detected."

# ------------------------------------------------------------------
# STEP 2 — Clean runtime directories
# ------------------------------------------------------------------
echo ""
echo "[2/6] Cleaning runtime directories..."

rm -rf "$PROJECT_DIR/tmp/cache"
rm -rf "$PROJECT_DIR/tmp/pids"
rm -rf "$PROJECT_DIR/tmp/sockets"
rm -rf "$PROJECT_DIR/tmp/storage"
rm -f  "$PROJECT_DIR/tmp/local_secret.txt"
rm -f  "$PROJECT_DIR/tmp/restart.txt"
rm -f  "$PROJECT_DIR/log/development.log"
rm -f  "$PROJECT_DIR/log/test.log"
rm -f  "$PROJECT_DIR/log/production.log"
rm -rf "$PROJECT_DIR/public/assets"
rm -rf "$PROJECT_DIR/.ruby-lsp"

echo "  OK: Runtime directories cleaned."

# ------------------------------------------------------------------
# STEP 3 — Re-create required .keep files so dirs exist in ZIP
# ------------------------------------------------------------------
echo ""
echo "[3/6] Preserving directory structure with .keep files..."

mkdir -p "$PROJECT_DIR/tmp/pids"
touch "$PROJECT_DIR/tmp/.keep"
touch "$PROJECT_DIR/tmp/pids/.keep"
touch "$PROJECT_DIR/log/.keep"
touch "$PROJECT_DIR/storage/.keep"

echo "  OK: .keep files in place."

# ------------------------------------------------------------------
# STEP 4 — Build ZIP, excluding everything sensitive
# ------------------------------------------------------------------
echo ""
echo "[4/6] Building ZIP archive (this may take a moment)..."

cd "$PROJECT_DIR/.."

zip -r "$OUTPUT_ZIP" "$(basename "$PROJECT_DIR")/" \
  --exclude "$(basename "$PROJECT_DIR")/.git/*" \
  --exclude "$(basename "$PROJECT_DIR")/config/master.key" \
  --exclude "$(basename "$PROJECT_DIR")/config/master.key.bak" \
  --exclude "$(basename "$PROJECT_DIR")/config/credentials.yml.enc.bak" \
  --exclude "$(basename "$PROJECT_DIR")/config/*.key" \
  --exclude "$(basename "$PROJECT_DIR")/config/*.key.bak" \
  --exclude "$(basename "$PROJECT_DIR")/heroku/*" \
  --exclude "$(basename "$PROJECT_DIR")/heroku-linux-x64.tar.gz" \
  --exclude "$(basename "$PROJECT_DIR")/heroku_build.log" \
  --exclude "$(basename "$PROJECT_DIR")/heroku_push.log" \
  --exclude "$(basename "$PROJECT_DIR")/storage/8o/*" \
  --exclude "$(basename "$PROJECT_DIR")/storage/a2/*" \
  --exclude "$(basename "$PROJECT_DIR")/storage/jc/*" \
  --exclude "$(basename "$PROJECT_DIR")/storage/ew/*" \
  --exclude "$(basename "$PROJECT_DIR")/storage/[a-z0-9][a-z0-9]/*" \
  --exclude "$(basename "$PROJECT_DIR")/tmp/cache/*" \
  --exclude "$(basename "$PROJECT_DIR")/tmp/local_secret.txt" \
  --exclude "$(basename "$PROJECT_DIR")/tmp/restart.txt" \
  --exclude "$(basename "$PROJECT_DIR")/tmp/sockets/*" \
  --exclude "$(basename "$PROJECT_DIR")/tmp/storage/*" \
  --exclude "$(basename "$PROJECT_DIR")/log/development.log" \
  --exclude "$(basename "$PROJECT_DIR")/log/test.log" \
  --exclude "$(basename "$PROJECT_DIR")/log/production.log" \
  --exclude "$(basename "$PROJECT_DIR")/public/assets/*" \
  --exclude "$(basename "$PROJECT_DIR")/.ruby-lsp/*" \
  --exclude "$(basename "$PROJECT_DIR")/node_modules/*" \
  --exclude "$(basename "$PROJECT_DIR")/.env" \
  --exclude "$(basename "$PROJECT_DIR")/.env.*" \
  --exclude "$(basename "$PROJECT_DIR")/*.zip" \
  --exclude "$(basename "$PROJECT_DIR")/build_delivery.sh" \
  -q

echo "  OK: ZIP created at $OUTPUT_ZIP"

# ------------------------------------------------------------------
# STEP 5 — Verify the ZIP does NOT contain sensitive files
# ------------------------------------------------------------------
echo ""
echo "[5/6] Verifying ZIP contents for security..."

VERIFY_FAIL=false

if unzip -l "$OUTPUT_ZIP" | grep -q "config/master.key$"; then
  echo "  CRITICAL: master.key found in ZIP — DO NOT SEND!"
  VERIFY_FAIL=true
fi

if unzip -l "$OUTPUT_ZIP" | grep -q "master.key.bak"; then
  echo "  CRITICAL: master.key.bak found in ZIP — DO NOT SEND!"
  VERIFY_FAIL=true
fi

if unzip -l "$OUTPUT_ZIP" | grep -q "heroku-linux-x64"; then
  echo "  WARN: heroku-linux-x64.tar.gz found in ZIP (large binary)"
  VERIFY_FAIL=true
fi

if unzip -l "$OUTPUT_ZIP" | grep -q "local_secret.txt"; then
  echo "  WARN: local_secret.txt found in ZIP"
  VERIFY_FAIL=true
fi

if [ "$VERIFY_FAIL" = true ]; then
  echo ""
  echo "  Verification FAILED. Remove the ZIP and investigate."
  rm -f "$OUTPUT_ZIP"
  exit 1
fi

echo "  OK: No sensitive files detected in ZIP."

# ------------------------------------------------------------------
# STEP 6 — Print summary
# ------------------------------------------------------------------
echo ""
echo "[6/6] Done."
echo ""
echo "======================================================"
echo "  DELIVERY PACKAGE READY"
echo "======================================================"
echo "  File:  $OUTPUT_ZIP"
echo "  Size:  $(du -sh "$OUTPUT_ZIP" | cut -f1)"
echo ""
echo "  Contents summary:"
unzip -l "$OUTPUT_ZIP" | tail -1
echo ""
echo "  BEFORE SENDING:"
echo "    1. Open the ZIP and spot-check that config/master.key is absent"
echo "    2. Confirm delivery docs are present:"
echo "       - README_DELIVERY.txt"
echo "       - DELIVERY_CHECKLIST.txt"
echo "       - DOMAIN_TRANSFER_CHECKLIST.txt"
echo "    3. Upload to Flippa or a secure file transfer service"
echo "       (Google Drive, Dropbox, WeTransfer)"
echo "    4. Send the download link via Flippa messaging"
echo "======================================================"
