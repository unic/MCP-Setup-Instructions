# Exit on error
$ErrorActionPreference = "Stop"

# Default model
$MODEL = "qwen3:8b"

# Parse command line arguments
param(
    [string]$m = $MODEL
)

$MODEL = $m

# Helper functions for colored output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERR ] $Message" -ForegroundColor Red
}

# -----------------------------
# Check for Go Installation
# -----------------------------
function Check-Go {
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Ok "Go is already installed."
    } else {
        Write-Info "Go is not installed. Installing using winget..."
        # Check if winget is available
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                winget install GoLang.Go
                Write-Ok "Go installed. Please restart your terminal for changes to take effect."
                Write-Warn "Please restart this script after restarting your terminal."
                exit 0
            } catch {
                Write-Err "Failed to install Go via winget. Please install Go manually from https://go.dev/doc/install"
                exit 1
            }
        } else {
            Write-Err "winget not found. Please install Go manually from https://go.dev/doc/install"
            exit 1
        }
    }
}

# -----------------------------
# Check for Ollama Installation
# -----------------------------
function Check-Ollama {
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Ok "Ollama is already installed."
    } else {
        Write-Err "Ollama is not installed. Please download and install Ollama from https://ollama.com/download/windows"
        exit 1
    }
}

# -----------------------------
# Check for Node.js (for npx)
# -----------------------------
function Check-NodeJS {
    if (Get-Command npx -ErrorAction SilentlyContinue) {
        Write-Ok "Node.js and npx are available."
    } else {
        Write-Warn "npx not found. Installing Node.js..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                winget install OpenJS.NodeJS
                Write-Ok "Node.js installed. Please restart your terminal for changes to take effect."
                Write-Warn "Please restart this script after restarting your terminal."
                exit 0
            } catch {
                Write-Err "Failed to install Node.js via winget. Please install Node.js manually from https://nodejs.org/en/download/"
                exit 1
            }
        } else {
            Write-Err "winget not found. Please install Node.js manually from https://nodejs.org/en/download/"
            exit 1
        }
    }
}

# -----------------------------
# Start Ollama and Pull Model
# -----------------------------
function Setup-Ollama {
    param([string]$ModelName)
    
    Write-Info "Using Ollama model: $ModelName"
    
    Write-Info "Pulling model '$ModelName' (this may take a while the first time)..."
    try {
        ollama pull $ModelName
        Write-Ok "Model '$ModelName' is ready."
    } catch {
        Write-Warn "ollama pull failed; trying 'ollama run' which can also trigger a pull..."
        try {
            echo "exit" | ollama run $ModelName
            Write-Ok "Model '$ModelName' is ready."
        } catch {
            Write-Err "Failed to pull model '$ModelName'."
            exit 1
        }
    }
}

# -----------------------------
# Create MCP Config File
# -----------------------------
function Create-MCPConfig {
    $configDir = "$env:APPDATA\mcphost"
    $configPath = "$configDir\mcp_config.json"

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
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
    Write-Ok "Wrote MCP config to: $configPath"
    return $configPath
}

# -----------------------------
# Install mcphost using Go
# -----------------------------
function Install-MCPhost {
    Write-Info "Installing mcphost with Go..."
    
    $GOBIN = (go env GOBIN)
    if ([string]::IsNullOrEmpty($GOBIN)) {
        $GOPATH = (go env GOPATH)
        $GOBIN = "$GOPATH\bin"
    }

    try {
        go install github.com/mark3labs/mcphost@latest
        
        # Add Go bin directory to PATH for current session
        $env:Path += ";$GOBIN"
        
        # Verify mcphost installation
        if (Test-Path "$GOBIN\mcphost.exe") {
            Write-Ok "mcphost installed at $GOBIN\mcphost.exe"
        } else {
            Write-Err "mcphost binary not found in $GOBIN after installation."
            Write-Err "Try opening a new terminal, or check: ls `"$GOBIN\mcphost.exe`""
            exit 1
        }
        
        return $GOBIN
    } catch {
        Write-Err "Failed to install mcphost: $_"
        exit 1
    }
}

# -----------------------------
# Add Go bin to PATH permanently
# -----------------------------
function Add-GoToPath {
    param([string]$GoBinPath)
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($currentPath -notlike "*$GoBinPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$GoBinPath", [EnvironmentVariableTarget]::User)
        Write-Ok "Added $GoBinPath to user PATH environment variable."
        Write-Info "You may need to restart your terminal for PATH changes to take effect."
    } else {
        Write-Ok "Go bin directory already in PATH."
    }
}

# -----------------------------
# Main Script Execution
# -----------------------------
Write-Info "Starting Ollama MCP Host Setup for Windows..."
Write-Info "Using model: $MODEL"

# Check prerequisites
Check-Go
Check-Ollama
Check-NodeJS

# Setup Ollama and pull model
Setup-Ollama -ModelName $MODEL

# Create MCP config file
$configPath = Create-MCPConfig

# Install mcphost
$goBinPath = Install-MCPhost

# Add Go bin to PATH
Add-GoToPath -GoBinPath $goBinPath

# Final instructions
Write-Host ""
Write-Ok "All set!"
Write-Host "You can start your MCP host with:"
Write-Host ""
Write-Host "  mcphost -m ollama:$MODEL --config `"$configPath`""
Write-Host ""
Write-Host "If 'mcphost' isn't found, restart your terminal or add to PATH:"
Write-Host "  `$env:Path += ';$goBinPath'"
Write-Host ""