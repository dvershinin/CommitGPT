#!/bin/bash

COMMIT_FILE=$1
COMMIT_SOURCE=$2

# Skip if commit message already provided (amend, merge, etc.)
if [ -n "$COMMIT_SOURCE" ]; then
    exit 0
fi

# Get staged changes (what will actually be committed)
CHANGES=$(git diff --cached --stat)
DIFF_CONTENT=$(git diff --cached | head -500)  # Limit diff size

# Skip if no changes
if [ -z "$CHANGES" ]; then
    echo "Auto-update" > "$COMMIT_FILE"
    exit 0
fi

# Check for API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Auto-update" > "$COMMIT_FILE"
    echo "" >> "$COMMIT_FILE"
    echo "Changed files:" >> "$COMMIT_FILE"
    echo "$CHANGES" >> "$COMMIT_FILE"
    exit 0
fi

# Build a factual prompt
read -r -d '' PROMPT << EOF
Generate a git commit message for these changes. Be factual and concise.

Files changed:
$CHANGES

Diff (truncated):
$DIFF_CONTENT

Rules:
- First line: summary under 72 chars describing WHAT changed
- Then blank line  
- Then bullet points of specific changes
- Do NOT invent features or reasons - only describe what the diff shows
- If files were deleted, say they were deleted
- If files were renamed, say they were renamed
- If version numbers changed, mention the new version
EOF

# Call OpenAI API with timeout
RESPONSE=$(timeout 30 curl -s -H "Content-Type: application/json" \
-H "Authorization: Bearer $OPENAI_API_KEY" \
--data-binary @- https://api.openai.com/v1/chat/completions 2>/dev/null << JSONEOF
{
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": $(echo "$PROMPT" | jq -Rs .)}],
    "max_tokens": 300,
    "temperature": 0.3
}
JSONEOF
)

# Extract message
MESSAGE=$(echo "$RESPONSE" | jq -r ".choices[0].message.content // empty" 2>/dev/null)

# Validate message - must not be null/empty/error
if [ -z "$MESSAGE" ] || [ "$MESSAGE" = "null" ] || [[ "$MESSAGE" == *"error"* ]]; then
    # Fallback to simple descriptive message
    echo "Update files" > "$COMMIT_FILE"
    echo "" >> "$COMMIT_FILE"
    echo "Changed:" >> "$COMMIT_FILE"
    echo "$CHANGES" >> "$COMMIT_FILE"
    exit 0
fi

# Write the commit message
echo "$MESSAGE" > "$COMMIT_FILE"
