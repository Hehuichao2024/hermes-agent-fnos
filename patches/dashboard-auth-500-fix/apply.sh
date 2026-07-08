#!/bin/bash
# Apply Dashboard auth auto-SSO hotfix for Hermes Agent.
# 
# Usage:
#   ./apply.sh                     # Patch the container named "hermes-agent"
#   ./apply.sh my-container        # Patch a differently-named container
#
# The fix excludes password-only auth providers (BasicAuthProvider)
# from the auto-SSO redirect, which causes a 500 error when FN Connect
# (or any reverse proxy) accesses the Dashboard remotely.
#
# Explanation:
#   BasicAuthProvider has supports_password=True but no start_login()
#   (it's a password form, not an OAuth redirect). The auto-SSO
#   logic in _auto_sso_response() was treating it as an OAuth provider,
#   redirecting to /auth/login?provider=basic → NotImplementedError → 500.
#   The fix filters out supports_password providers from SSO candidates,
#   so they correctly fall through to the /login password form page.

set -euo pipefail

CONTAINER="${1:-hermes-agent}"
FILE="/opt/hermes/hermes_cli/dashboard_auth/middleware.py"

echo "=== Dashboard Auth 500 Fix ==="
echo "Container: $CONTAINER"
echo "Target:    $FILE"
echo ""

# Verify container exists and is running
if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: Container '$CONTAINER' not found!"
  echo "       Usage: $0 [container-name]"
  exit 1
fi

STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}')
if [ "$STATUS" != "running" ]; then
  echo "ERROR: Container '$CONTAINER' is not running (status: $STATUS)"
  exit 1
fi

echo "[1/3] Locating middleware.py..."
if ! docker exec "$CONTAINER" test -f "$FILE"; then
  echo "ERROR: $FILE not found inside container!"
  docker exec "$CONTAINER" find /opt/hermes -name "middleware.py" 2>/dev/null || true
  exit 1
fi
echo "      Found: $FILE"

echo "[2/3] Applying patch..."
docker exec "$CONTAINER" sh -c '
  # Read current content for verification
  MIDDLEWARE="/opt/hermes/hermes_cli/dashboard_auth/middleware.py"
  LINES=$(wc -l < "$MIDDLEWARE")
  
  # Check if already patched
  if grep -q "sso_candidates" "$MIDDLEWARE"; then
    echo "      Already patched — skipping."
    exit 0
  fi
  
  # Apply the fix: replace auto-SSO logic to exclude password-only providers
  sed -i "180,187c\    providers = list_session_providers()\n    # Exclude password-only providers from auto-SSO (they need the\n    # /login page to render the password form, not start_login()).\n    sso_candidates = [p for p in providers if not getattr(p, \"supports_password\", False)]\n    if len(sso_candidates) != 1:\n        # Zero → nothing to auto-redirect. Two+ → user must choose at /login.\n        # Password-only cases fall through here correctly.\n        return None\n\n    from hermes_cli.dashboard_auth.prefix import prefix_from_request\n\n    provider = sso_candidates[0]" "$MIDDLEWARE"
  
  echo "      Patch applied."
'

echo "[3/3] Restarting container to reload Python modules..."
docker restart "$CONTAINER" >/dev/null
sleep 3

# Verify
echo ""
echo "=== Verification ==="
LOCATION=$(curl -s -o /dev/null -w "%{redirect_url}" http://127.0.0.1:9119/ 2>/dev/null || echo "dashboard not reachable on port 9119")
echo "GET / redirects to: $LOCATION"

if echo "$LOCATION" | grep -q "/login"; then
  echo ""
  echo "✅ Fix verified — redirect goes to /login (correct)."
  echo "   Open FN Connect URL and you should see the login page."
elif echo "$LOCATION" | grep -q "/auth/login"; then
  echo ""
  echo "❌ Fix FAILED — still redirecting to /auth/login."
  echo "   Check if the container restarted properly."
else
  echo ""
  echo "⚠️  Could not verify redirect. Check dashboard status manually:"
  echo "   curl -sv http://127.0.0.1:9119/ 2>&1 | grep -i location"
fi
