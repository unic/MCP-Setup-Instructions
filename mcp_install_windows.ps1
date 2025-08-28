# Exit on error
$ErrorActionPreference = "Stop"

# -----------------------------
# Check for Go Installation
# -----------------------------
function Check-Go {
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Host "Go is already installed."
    } else {
        Write-Host "Go is not installed. Installing using winget..."
        # Check if winget is available
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install GoLang.Go
            Write-Host "Go installed. Restart your terminal for changes to take effect."
        } else {
            Write-Host "winget not found. Please install Go manually from https://go.dev/doc/install"
            exit 1
        }
    }
}

# -----------------------------
# Check for Ollama Installation
# -----------------------------
function Check-Ollama {
    # Check if the 'ollama' command is available on the PATH
    try {
        $ollamaCommand = Get-Command ollama -ErrorAction Stop
        Write-Host "Ollama is installed at: $($ollamaCommand.Source)"
    } catch {
        Write-Host "Ollama is not installed. Please download Ollama from https://ollama.com/download/windows"
        exit 1
    }
}

# -----------------------------
# Check for Node.js (for npx)
# -----------------------------
# function Check-NodeJS {
    # if (Get-Command npx -ErrorAction SilentlyContinue) {
        # Write-Host "Node.js is already installed."
    # } else {
        # Write-Host "Node.js is not installed. Please download it from https://nodejs.org/en/download/"
        # exit 1
    # }
# }

# -----------------------------
# Create MCP Config File
# -----------------------------
function Create-MCPConfig {
    $configDir = "$env:APPDATA\mcphost"
    $configPath = "$configDir\mcp_config.json"

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir
    }

    $jsonContent = @'
{
  "mcpServers": {
    "swiss-ai-weeks-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:8000/mcp/"
      ]
    }
  }
}
'@

    Set-Content -Path $configPath -Value $jsonContent
    Write-Host "MCP config created at: $configPath"
}

# -----------------------------
# Install mcphost using Go
# -----------------------------
function Install-MCPhost {
    Write-Host "Installing mcphost using Go..."

    $GOBIN = (go env GOPATH) + "\bin"

    # Ensure Go binary path is added to environment PATH
    $env:Path += ";$GOBIN"

    # Install mcphost
    go install github.com/mark3labs/mcphost@latest

    # Verify mcphost installation
    if (Test-Path "$GOBIN\mcphost.exe") {
        Write-Host "mcphost installed at $GOBIN\mcphost.exe"
    } else {
        Write-Host "mcphost installation failed."
        exit 1
    }
}

# -----------------------------
# Final Setup Instructions
# -----------------------------
function Final-Instructions {
    Write-Host ""
    Write-Host "Setup complete!"
    Write-Host "To run mcphost, use the following command:"
    Write-Host "  mcphost -m ollama:qwen3:8b --config $env:APPDATA\mcphost\mcp_config.json"
    Write-Host "If 'mcphost' isn't recognized, restart your terminal."
}

# -----------------------------
# Main Script Execution
# -----------------------------
Write-Host "Starting Ollama MCP Host Setup..."

# Check Go, Ollama, and Node.js installations
Check-Go
Check-Ollama
# Check-NodeJS

# Create MCP config file
Create-MCPConfig

# Install mcphost using Go
Install-MCPhost

# Show final instructions
Final-Instructions