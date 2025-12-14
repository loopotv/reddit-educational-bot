#!/bin/bash

# Test Script per Tutorial Bot
# Esempi di chiamate API

BASE_URL="http://localhost:5678"  # Modifica con il tuo domain
WEBHOOK_PATH="/webhook/generate-tutorial"

echo "🧪 Tutorial Bot - Test Suite"
echo "============================="
echo ""

# Test 1: Basic Tutorial - Portrait Photography
echo "Test 1: Basic Portrait Tutorial..."
curl -X POST "${BASE_URL}${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "portrait photography",
    "style": "cinematic editorial",
    "duration": 45
  }' | jq '.'

echo ""
echo "---"
echo ""

# Test 2: Product Photography
echo "Test 2: Product Photography Tutorial..."
curl -X POST "${BASE_URL}${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "luxury product photography with reflections",
    "style": "commercial advertising",
    "duration": 50
  }' | jq '.'

echo ""
echo "---"
echo ""

# Test 3: Fashion Editorial
echo "Test 3: Fashion Editorial Tutorial..."
curl -X POST "${BASE_URL}${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "fashion editorial with dynamic movement",
    "style": "vogue magazine editorial",
    "duration": 60
  }' | jq '.'

echo ""
echo "---"
echo ""

# Test 4: Architecture
echo "Test 4: Architecture Photography Tutorial..."
curl -X POST "${BASE_URL}${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "modern architecture photography",
    "style": "architectural digest editorial",
    "duration": 40
  }' | jq '.'

echo ""
echo "============================="
echo "✅ Tests completed"
echo ""
echo "Expected response format:"
echo '{'
echo '  "status": "success",'
echo '  "video_url": "https://cdn.shotstack.io/..../final.mp4",'
echo '  "render_id": "xxx-xxx-xxx"'
echo '}'
echo ""
echo "Note: Video rendering takes 30-120 seconds"
echo "Check status with Shotstack render_id if needed"
