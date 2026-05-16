#!/bin/bash

echo "Testing exams endpoints..."

# Start server in background
node /Users/eduardovasqueskaizer/Projects/runnin.core/server/dist/main.js &
SERVER_PID=$!
sleep 2

echo "Server started with PID: $SERVER_PID"

# Test upload-url endpoint
echo -e "\n=== Testing POST /v1/exams/upload-url ==="
curl -s -X POST http://localhost:3000/v1/exams/upload-url \
  -H "Content-Type: application/json" \
  -d '{"examName":"Cardiovascular Exam","fileName":"ecg_result.pdf","fileSize":2048}' \
  -H "Authorization: Bearer test-jwt-token"

echo ""
echo ""

# Test list exams endpoint
echo -e "\n=== Testing GET /v1/exams ==="
curl -s http://localhost:3000/v1/exams \
  -H "Authorization: Bearer test-jwt-token"

echo ""
echo ""

# Stop server
kill $SERVER_PID 2>/dev/null

echo "Tests completed!"
