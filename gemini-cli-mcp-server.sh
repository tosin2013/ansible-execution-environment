#!/bin/bash
# This script creates a .gemini/settings.json file to configure multiple
# MCP (Model Context Protocol) servers for the Gemini CLI.
# npm install -g @google/gemini-cli documcp
# npm install mcp-adr-analysis-server 
export DOCUMCP_TARGET_REPO="$PWD"
export PROJECT_PATH="$PWD"
export ADR_DIRECTORY="$PWD/docs/adrs"
read -sp "Enter your OpenRouter API key: " OPENROUTER_API_KEY
echo
read -sp "Enter your GitHub Personal Access Token: " GITHUB_MCP_PAT
echo

# This section is intentionally comprehensive to fulfill the prompt by populating
# the settings.json file before the script's original 'exit 0' is reached.

# Create the .gemini directory in the project's root if it doesn't exist
mkdir -p .gemini

# Create the .gemini/settings.json file, embedding the provided API keys.
# Path variables like $DOCUMCP_TARGET_REPO are escaped (\$) so they are
# written literally to the file and expanded later by the gemini tool.
cat <<EOF > .gemini/settings.json
{
  "mcpServers": {
    "documcp": {
      "command": "npx",
      "args": ["-y", "documcp"],
      "env": {
        "DOCUMCP_TARGET_REPO": "\$DOCUMCP_TARGET_REPO"
      }
    },
    "github": {
      "httpUrl": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer $GITHUB_MCP_PAT"
      }
    },
    "adr-analysis": {
      "command": "npx",
      "args": ["mcp-adr-analysis-server"],
      "env": {
        "PROJECT_PATH": "\$PROJECT_PATH",
        "ADR_DIRECTORY": "\$ADR_DIRECTORY",
        "LOG_LEVEL": "ERROR",
        "EXECUTION_MODE": "full",
        "AI_MODEL": "anthropic/claude-3-sonnet",
        "OPENROUTER_API_KEY": "$OPENROUTER_API_KEY"
      }
    }
  }
}
EOF

echo "Successfully created .gemini/settings.json with your API keys."
echo "Note: Path variables still need to be exported in your environment."
exit 0
