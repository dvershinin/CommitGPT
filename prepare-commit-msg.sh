#!/bin/bash

COMMIT_FILE=$1
COMMIT_SOURCE=$2

# Skip if commit message already provided (amend, merge, etc.)
if [ -n "$COMMIT_SOURCE" ]; then
    exit 0
fi

# Allow callers to isolate this hook's OpenAI spend from any other OPENAI_API_KEY
# already in the environment (e.g. when the same shell runs other AI tooling
# against a personal key). Falls back to OPENAI_API_KEY when COMMITGPT_OPENAI_API_KEY
# is unset so existing setups keep working unchanged.
API_KEY="${COMMITGPT_OPENAI_API_KEY:-$OPENAI_API_KEY}"

# Model is overridable too. Default to the cheapest current-generation tier
# ($0.05/M input, $0.40/M output at the time of writing). Anything in the
# OpenAI Chat Completions catalogue works.
MODEL="${COMMITGPT_MODEL:-gpt-5-nano}"

# Get staged changes (what will actually be committed)
CHANGES=$(git diff --cached --stat)
DIFF_CONTENT=$(git diff --cached | head -500)  # Limit diff size

# Skip if no changes
if [ -z "$CHANGES" ]; then
    echo "Auto-update" > "$COMMIT_FILE"
    exit 0
fi

# Check for API key
if [ -z "$API_KEY" ]; then
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
- Do NOT wrap the message in markdown code fences or backticks
- Output ONLY the raw commit message text, nothing else
- If files were deleted, say they were deleted
- If files were renamed, say they were renamed
- If version numbers changed, mention the new version
EOF

# gpt-5* family rejects max_tokens (wants max_completion_tokens), refuses
# any temperature other than 1, and silently spends the entire token budget
# on internal reasoning unless reasoning_effort is pinned low. Older chat
# models (gpt-4.1*, gpt-4o*, etc.) keep the original parameters.
if [[ "$MODEL" == gpt-5* ]]; then
    TOKENS_KEY="max_completion_tokens"
    EXTRA_PARAMS=',"reasoning_effort":"minimal"'
else
    TOKENS_KEY="max_tokens"
    EXTRA_PARAMS=',"temperature":0.3'
fi

# Call OpenAI API with timeout
RESPONSE=$(timeout 30 curl -s -H "Content-Type: application/json" \
-H "Authorization: Bearer $API_KEY" \
--data-binary @- https://api.openai.com/v1/chat/completions 2>/dev/null << JSONEOF
{
    "model": "$MODEL",
    "messages": [{"role": "user", "content": $(echo "$PROMPT" | jq -Rs .)}],
    "$TOKENS_KEY": 300
    $EXTRA_PARAMS
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

# Strip markdown code fences (```markdown, ```, etc.) that GPT sometimes adds
MESSAGE=$(echo "$MESSAGE" | sed '/^```/d')

# Strip leading/trailing blank lines
MESSAGE=$(echo "$MESSAGE" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba;}')

# Write the commit message
echo "$MESSAGE" > "$COMMIT_FILE"
