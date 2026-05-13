#!/usr/bin/env bash
set -euo pipefail

API_URL="https://runnin-api-rogiz7losq-rj.a.run.app"

echo "=========================================="
echo "Runnin API - LLM Endpoint Test"
echo "=========================================="
echo ""

# Test health endpoint (no auth required)
echo "→ Testing health endpoint..."
if curl -s -f "$API_URL/health" > /dev/null; then
  echo "✓ Health endpoint responding"
else
  echo "❌ Health endpoint failed"
  exit 1
fi

echo ""
echo "→ Testing authenticated endpoints (requires Firebase token)..."
echo ""

# Check if FIREBASE_TOKEN is set
if [[ -z "${FIREBASE_TOKEN:-}" ]]; then
  echo "⚠ FIREBASE_TOKEN environment variable not set"
  echo ""
  echo "To test authenticated endpoints, you need a Firebase ID token:"
  echo ""
  echo "1. Open the Runnin mobile app"
  echo "2. Sign in with your account"
  echo "3. Extract the Firebase ID token (from app logs or Firebase console)"
  echo "4. Run this script with:"
  echo "   FIREBASE_TOKEN='your-token-here' bash $0"
  echo ""
  exit 0
fi

# Test plan generation endpoint
echo "Testing POST /v1/plans/generate..."
PLAN_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$API_URL/v1/plans/generate" \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "goalType": "5K",
    "currentLevel": "beginner",
    "weeksAvailable": 8
  }')

HTTP_CODE=$(echo "$PLAN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$PLAN_RESPONSE" | head -n-1)

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✓ Plan generation successful"
  echo "Response preview:"
  echo "$RESPONSE_BODY" | jq -r '.data.weeks[0] // .message // .' 2>/dev/null | head -5
elif [[ "$HTTP_CODE" == "401" ]]; then
  echo "❌ Authentication failed (401) - check your Firebase token"
elif [[ "$HTTP_CODE" == "403" ]]; then
  echo "❌ Premium required (403) - this account needs premium access"
else
  echo "❌ Request failed with HTTP $HTTP_CODE"
  echo "$RESPONSE_BODY"
fi

echo ""
echo "Testing POST /v1/coach/message..."
COACH_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$API_URL/v1/coach/message" \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello coach, how should I prepare for my next run?"
  }')

HTTP_CODE=$(echo "$COACH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$COACH_RESPONSE" | head -n-1)

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✓ Coach message successful"
  echo "Response preview:"
  echo "$RESPONSE_BODY" | jq -r '.data.response // .message // .' 2>/dev/null | head -5
elif [[ "$HTTP_CODE" == "401" ]]; then
  echo "❌ Authentication failed (401) - check your Firebase token"
elif [[ "$HTTP_CODE" == "403" ]]; then
  echo "❌ Premium required (403) - this account needs premium access"
else
  echo "❌ Request failed with HTTP $HTTP_CODE"
  echo "$RESPONSE_BODY"
fi

echo ""
echo "=========================================="
echo "Test complete"
echo "=========================================="
