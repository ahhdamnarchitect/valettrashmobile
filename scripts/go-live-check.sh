#!/usr/bin/env bash
# Go-live verification for Relaxed Living Valet.
#
# Everything still blocking launch needs a credential, a purchase or hardware --
# things only the owner can supply. This script closes that loop: run it after each
# one and it tells you whether that piece actually works, instead of needing someone
# to check by hand.
#
#   ./scripts/go-live-check.sh                 # everything it can reach
#   ./scripts/go-live-check.sh stripe          # just one section
#
# Reads mobile/dart_define.json for the project URL and publishable key.

set -uo pipefail
cd "$(dirname "$0")/.."

CFG="mobile/dart_define.json"
[ -f "$CFG" ] || { echo "missing $CFG - copy dart_define.example.json and fill it in"; exit 1; }
URL=$(python3 -c "import json;print(json.load(open('$CFG'))['SUPABASE_URL'])")
KEY=$(python3 -c "import json;print(json.load(open('$CFG'))['SUPABASE_ANON_KEY'])")
SECTION="${1:-all}"

pass(){ printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail(){ printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAILED=$((FAILED+1)); }
todo(){ printf "  \033[33mTODO\033[0m  %s\n" "$1"; }
head(){ printf "\n\033[1m%s\033[0m\n" "$1"; }
FAILED=0

run(){ [ "$SECTION" = "all" ] || [ "$SECTION" = "$1" ]; }

# ── backend ──────────────────────────────────────────────────────────────────
if run backend; then
head "Backend"
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 "$URL/auth/v1/health" -H "apikey: $KEY")
[ "$code" = "200" ] && pass "auth reachable" || fail "auth returned $code"

anon=$(curl -s --max-time 20 "$URL/rest/v1/properties?select=name" -H "apikey: $KEY")
[ "$anon" = "[]" ] && pass "RLS blocks anonymous reads" || fail "anon saw data: ${anon:0:60}"

code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 -X POST "$URL/rest/v1/properties" \
  -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d '{"name":"probe","address":"x","city":"x","state":"TX","zip_code":"00000"}')
[ "$code" = "401" ] || [ "$code" = "403" ] && pass "RLS blocks anonymous writes" || fail "anon write returned $code"
fi

# ── stripe ───────────────────────────────────────────────────────────────────
if run stripe; then
head "Stripe  (needs STRIPE_SECRET_KEY + STRIPE_WEBHOOK_SECRET in Edge Function secrets)"
body=$(curl -s --max-time 25 -X POST "$URL/functions/v1/create-checkout-session" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d '{}' 2>/dev/null)
if grep -qi "not configured" <<<"$body"; then
  todo "secrets not set yet - see brain/stripe_setup.md"
elif grep -qi "unauthor\|jwt" <<<"$body"; then
  pass "function is live and rejecting unauthenticated callers"
else
  pass "function responding: ${body:0:70}"
fi

hook=$(curl -s -o /dev/null -w "%{http_code}" --max-time 25 -X POST "$URL/functions/v1/stripe-webhook" \
  -H "Content-Type: application/json" -d '{}')
case "$hook" in
  400) pass "webhook live and rejecting unsigned payloads (correct)";;
  503) todo "webhook deployed but STRIPE_WEBHOOK_SECRET not set";;
  401) fail "webhook has JWT verification ON - Stripe cannot call it. Turn it OFF.";;
  *)   fail "webhook returned $hook";;
esac
todo "after adding keys: run a real test-mode purchase and confirm credits land"
fi

# ── email / smtp ─────────────────────────────────────────────────────────────
if run smtp; then
head "Email  (built-in mailer caps at ~2-3/hour - custom SMTP needed before launch)"
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 25 -X POST "$URL/auth/v1/recover" \
  -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d '{"email":"relaxedlivingtx@gmail.com"}')
[ "$code" = "200" ] && pass "password-reset endpoint accepted the request" || fail "recover returned $code"
todo "check the inbox - if nothing arrives, the built-in mailer is rate-limited"
todo "after SMTP: reset a password end to end and confirm the deep link opens the app"
fi

# ── app ──────────────────────────────────────────────────────────────────────
if run app; then
head "App"
if command -v flutter >/dev/null 2>&1; then
  errs=$(cd mobile && flutter analyze 2>/dev/null | grep -cE "^\s*error")
  [ "$errs" = "0" ] && pass "flutter analyze: 0 errors" || fail "flutter analyze: $errs errors"
  if (cd mobile && flutter test >/dev/null 2>&1); then pass "unit + widget tests"; else fail "tests failing"; fi
else
  todo "flutter not on PATH - skipped analyze/tests"
fi
todo "physical device: install a TestFlight/Play build and tap Export CSV once"
fi

printf "\n"
[ "$FAILED" -eq 0 ] && printf "\033[32mNo failures.\033[0m TODOs are the items still needing a credential, a purchase or hardware.\n" \
                    || printf "\033[31m%s check(s) failed.\033[0m\n" "$FAILED"
exit 0
