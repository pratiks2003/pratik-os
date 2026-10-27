#!/usr/bin/env bash
# Creates (or reuses) the compliance key and stores it in the org's protected
# Compliance_Settings__c. The key is kept locally in .secrets/ (git-ignored)
# so add-blocked-term.mjs can hash terms the same way the org does.
#
# Usage: scripts/compliance/set-key.sh <org-alias>
set -euo pipefail

ORG="${1:?Usage: set-key.sh <org-alias>}"
KEY_FILE="$(dirname "$0")/../../.secrets/compliance-key"

mkdir -p "$(dirname "$KEY_FILE")"
if [[ ! -s "$KEY_FILE" ]]; then
  (umask 077 && openssl rand -hex 32 > "$KEY_FILE")
  echo "Generated a new compliance key in .secrets/compliance-key"
fi
KEY="$(tr -d '\n' < "$KEY_FILE")"

APEX_FILE="$(mktemp)"
trap 'rm -f "$APEX_FILE"' EXIT
cat > "$APEX_FILE" <<APEX
Compliance_Settings__c setting = Compliance_Settings__c.getOrgDefaults();
setting.Term_Key__c = '$KEY';
upsert setting;
APEX

sf apex run --target-org "$ORG" --file "$APEX_FILE" > /dev/null
echo "Compliance key stored in $ORG"
