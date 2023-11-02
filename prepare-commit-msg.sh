#!/bin/bash

COMMIT_FILE=$1

# Collecting changes
CHANGES=$(git diff HEAD | sed 's/"/\\"/g') # Escaping double quotes

# Reading the prompt from git config
PROJECT_GOAL=$(git config --get commit.goal)

# Setting a default prompt if none is configured
if [ -z "$PROJECT_GOAL" ]; then
    PROJECT_GOAL="develop new software"
fi


PROMPT="You are a smart git commit message creator software. Now you are going to create a git commit message for a project which has a goal to $PROJECT_GOAL. The commit messages you generate aim to explain why the changes were introduced."
PROMPT="$PROMPT\nFor the changes in:\n$CHANGES\nPlease create a commit message. Start with a one-sentence summary no longer than 72 characters, followed by two newline characters, then provide a detailed message."
PROMPT="$PROMPT\nEnsure the detailed message is well-structured and each line does not exceed 72 characters."

# Use jq to safely turn it into a JSON string
JSON_ENCODED_PROMPT=$(jq -Rn --arg var "$PROMPT" '$var')

# Sending request to OpenAI and getting the message
MESSAGE_TEXT=$(curl -s -H "Content-Type: application/json" \
-H "Authorization: Bearer $OPENAI_API_KEY" \
-d @- https://api.openai.com/v1/chat/completions <<JSON | jq -r '.choices[0].message.content'
{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "system", "content": $JSON_ENCODED_PROMPT}],
    "max_tokens": 200
}
JSON
)

# Extracting and formatting the summary and body
SUMMARY=$(echo "$MESSAGE_TEXT" | head -n1)
BODY=$(echo "$MESSAGE_TEXT" | sed '1d' | fold -s -w 72)


# Constructing the commit message
echo "$SUMMARY" > "$COMMIT_FILE"
echo "" >> "$COMMIT_FILE"
echo "$BODY" >> "$COMMIT_FILE"
