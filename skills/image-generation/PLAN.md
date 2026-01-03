# Plan: Nano Banana Pro Image Generation Skill

## Overview

Create a skill that enables Claude Code to generate images using Google's **Nano Banana Pro** (Gemini 3 Pro Image) API. This skill will allow users to generate high-quality images directly from their development environment.

## What is Nano Banana Pro?

**Nano Banana Pro** is Google DeepMind's state-of-the-art image generation model, also known as **Gemini 3 Pro Image** (model ID: `gemini-3-pro-image-preview`). Key capabilities:

- **High-fidelity visuals** with up to 4K resolution (1K, 2K, 4K)
- **Multiple aspect ratios**: 1:1, 16:9, 9:16, 21:9, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4
- **Accurate text rendering** - best-in-class for legible text in images
- **Advanced reasoning** via "Thinking" mode for complex prompts
- **Image editing** - modify existing images with natural language
- **Reference images** - up to 6 object references, 5 human references for consistency
- **SynthID watermarking** - invisible watermarks on all generated images

## API Details

### Endpoint
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent
```

### Authentication
- **Header**: `x-goog-api-key: $GEMINI_API_KEY`
- **Key source**: https://aistudio.google.com/apikey

### Request Format
```json
{
  "contents": [{
    "parts": [
      {"text": "prompt here"},
      {"inline_data": {"mime_type": "image/png", "data": "BASE64_IMAGE"}}
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"],
    "imageConfig": {
      "aspectRatio": "16:9",
      "imageSize": "2K"
    }
  }
}
```

### Response Format
```json
{
  "candidates": [{
    "content": {
      "parts": [
        {"text": "description"},
        {"inline_data": {"mime_type": "image/png", "data": "base64_encoded_image"}}
      ]
    }
  }]
}
```

### Pricing (Approximate)
- 1K images: ~$0.04/image
- 4K images: ~$0.24/image

---

## Implementation Plan

### Phase 1: Create Skill Structure

**Task 1.1: Create skill directory and SKILL.md**
- Path: `/skills/image-generation/SKILL.md`
- Follow existing skill pattern with YAML frontmatter

**Task 1.2: Define skill responsibilities**
1. Text-to-image generation
2. Image editing with natural language
3. Multi-image generation (batch)
4. Reference-based generation (style consistency)
5. Output file management

### Phase 2: Skill Content Design

**Task 2.1: Core Principles**
1. **Quality First** - Use appropriate resolution for the use case
2. **Prompt Engineering** - Guide users to write effective prompts
3. **Cost Awareness** - Default to 1K, recommend 2K/4K when needed
4. **File Management** - Save to sensible locations with clear naming
5. **Safety** - Respect content policies, handle errors gracefully

**Task 2.2: Primary Responsibilities**

1. **Image Generation**
   - Interpret user intent and craft optimal prompts
   - Select appropriate aspect ratio based on use case
   - Handle API calls and decode base64 responses
   - Save images with descriptive filenames

2. **Image Editing**
   - Load existing images and encode to base64
   - Apply user-requested modifications
   - Support iterative refinement

3. **Batch Operations**
   - Generate multiple variations
   - Create image series with consistency
   - Use reference images for style matching

4. **Error Handling**
   - API quota/rate limits
   - Content policy violations
   - Network failures with retry

**Task 2.3: Workflow Templates**

Include ready-to-use curl/bash commands:

```bash
# Text-to-image generation
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "A serene mountain landscape at sunset"}]}],
    "generationConfig": {
      "responseModalities": ["IMAGE"],
      "imageConfig": {"aspectRatio": "16:9", "imageSize": "2K"}
    }
  }' | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | base64 -d > output.png
```

### Phase 3: Environment Setup Instructions

**Task 3.1: API Key Configuration**
```bash
# Option 1: Export in shell
export GEMINI_API_KEY="your-api-key-here"

# Option 2: Store in .env (add to .gitignore!)
echo "GEMINI_API_KEY=your-api-key-here" >> .env
```

**Task 3.2: Prerequisites**
- `curl` - for API calls
- `jq` - for JSON parsing
- `base64` - for image encoding/decoding (standard on Linux/macOS)

### Phase 4: Prompt Engineering Guidelines

**Task 4.1: Effective Prompt Patterns**

```
[Subject] + [Style] + [Composition] + [Lighting] + [Details]

Example:
"A professional headshot of a confident business executive,
corporate photography style, centered composition,
soft studio lighting, wearing a navy blue suit,
neutral gray background, 4K quality"
```

**Task 4.2: Use Case Templates**

| Use Case | Aspect Ratio | Resolution | Prompt Tips |
|----------|--------------|------------|-------------|
| Social media post | 1:1 | 1K | Bold colors, clear focal point |
| YouTube thumbnail | 16:9 | 2K | High contrast, readable text |
| Phone wallpaper | 9:16 | 2K | Vertical composition |
| Product shot | 4:3 | 2K-4K | Clean background, detailed |
| Banner/header | 21:9 | 2K | Horizontal, no center focus |
| Icon/avatar | 1:1 | 1K | Simple, recognizable |

### Phase 5: Example Workflows

**Task 5.1: Generate a single image**
```bash
# 1. Set up environment
export GEMINI_API_KEY="your-key"

# 2. Generate image
generate_image() {
  local prompt="$1"
  local output="${2:-generated.png}"
  local aspect="${3:-1:1}"
  local size="${4:-1K}"

  curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{\"parts\": [{\"text\": \"$prompt\"}]}],
      \"generationConfig\": {
        \"responseModalities\": [\"IMAGE\"],
        \"imageConfig\": {\"aspectRatio\": \"$aspect\", \"imageSize\": \"$size\"}
      }
    }" | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | base64 -d > "$output"

  echo "Image saved to: $output"
}

# 3. Usage
generate_image "A cute robot mascot for a tech startup" logo.png 1:1 2K
```

**Task 5.2: Edit an existing image**
```bash
# Convert image to base64 and send with edit prompt
edit_image() {
  local input="$1"
  local prompt="$2"
  local output="${3:-edited.png}"

  local base64_image=$(base64 -w0 "$input")
  local mime_type="image/png"

  curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{\"parts\": [
        {\"text\": \"$prompt\"},
        {\"inline_data\": {\"mime_type\": \"$mime_type\", \"data\": \"$base64_image\"}}
      ]}],
      \"generationConfig\": {\"responseModalities\": [\"IMAGE\"]}
    }" | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | base64 -d > "$output"

  echo "Edited image saved to: $output"
}

# Usage
edit_image photo.png "Remove the background and make it transparent" photo-nobg.png
```

**Task 5.3: Generate multiple variations**
```bash
# Generate N variations of a prompt
generate_variations() {
  local prompt="$1"
  local count="${2:-3}"
  local prefix="${3:-variation}"

  for i in $(seq 1 $count); do
    echo "Generating variation $i of $count..."
    generate_image "$prompt, variation $i" "${prefix}_${i}.png" "1:1" "1K"
    sleep 1  # Rate limiting
  done
}
```

### Phase 6: Error Handling

**Task 6.1: Common Errors and Solutions**

| Error | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Invalid API key | Verify GEMINI_API_KEY is set correctly |
| 429 Too Many Requests | Rate limit exceeded | Implement exponential backoff |
| 400 Bad Request | Invalid parameters | Check aspect ratio, size values |
| Content policy violation | Prompt contains restricted content | Revise prompt |
| Empty response | Generation failed | Retry with different prompt |

**Task 6.2: Robust Generation Script**
```bash
generate_image_robust() {
  local prompt="$1"
  local output="${2:-generated.png}"
  local max_retries=3
  local retry_delay=2

  for attempt in $(seq 1 $max_retries); do
    echo "Attempt $attempt of $max_retries..."

    response=$(curl -s -w "\n%{http_code}" -X POST \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
      -H "x-goog-api-key: $GEMINI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"contents\": [{\"parts\": [{\"text\": \"$prompt\"}]}],
        \"generationConfig\": {\"responseModalities\": [\"IMAGE\"]}
      }")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
      echo "$body" | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | base64 -d > "$output"
      if [ -s "$output" ]; then
        echo "Success! Image saved to: $output"
        return 0
      fi
    elif [ "$http_code" = "429" ]; then
      echo "Rate limited. Waiting ${retry_delay}s..."
      sleep $retry_delay
      retry_delay=$((retry_delay * 2))
    else
      echo "Error: HTTP $http_code"
      echo "$body" | jq -r '.error.message // "Unknown error"'
    fi
  done

  echo "Failed after $max_retries attempts"
  return 1
}
```

### Phase 7: Integration with Claude Code

**Task 7.1: Skill Invocation Pattern**

When user requests image generation:
1. Skill activates and guides prompt creation
2. Claude constructs the API call using Bash tool
3. Image is saved to specified location
4. Claude can read the image back to verify/describe it

**Task 7.2: Example Conversation Flow**

```
User: Generate a logo for my app called "TaskMaster"

Claude (with image-generation skill):
I'll create a logo for TaskMaster. Let me craft an effective prompt.

[Uses Bash to run API call]

I've generated the logo and saved it to `taskmaster-logo.png`.
The image shows [description]. Would you like me to:
1. Generate more variations?
2. Adjust the style?
3. Try a different concept?
```

---

## SKILL.md Structure

The final `SKILL.md` will include:

```yaml
---
name: image-generation
description: |
  Generate images using Google's Nano Banana Pro (Gemini 3 Pro Image) API.
  Create logos, illustrations, product shots, and more with natural language.
  Supports text-to-image, image editing, and multi-image generation.
license: Apache-2.0
---
```

**Sections:**
1. Core Principles (5)
2. Primary Responsibilities (4 areas)
3. API Reference (endpoint, auth, formats)
4. Prompt Engineering Guide
5. Ready-to-Use Commands
6. Error Handling
7. Use Case Templates
8. Constraints
9. Success Metrics

---

## Constraints

- Always inform users about API costs before generating 4K images
- Never store API keys in code or commits
- Respect content policies - refuse to generate harmful content
- Default to lower resolution unless quality demands higher
- Always save with descriptive filenames, not random strings
- Include SynthID watermark notice when relevant

## Success Metrics

- Images generate successfully on first attempt (>95%)
- Prompts produce expected results (subjective but verifiable)
- Users understand costs before expensive operations
- Error messages are actionable
- Generated images are saved to accessible locations

---

## Next Steps

1. **Create `/skills/image-generation/SKILL.md`** with complete skill content
2. **Add to README.md** - Update skill catalog
3. **Create examples** (optional) - Add example prompts/outputs
4. **Test the skill** - Verify API calls work with real key
5. **Update plugin.json** - Increment skill count

---

## Sources

- [Gemini Image Generation API Docs](https://ai.google.dev/gemini-api/docs/image-generation)
- [Nano Banana Pro Announcement](https://blog.google/technology/ai/nano-banana-pro/)
- [Google AI Studio](https://aistudio.google.com/apikey) - API key generation
