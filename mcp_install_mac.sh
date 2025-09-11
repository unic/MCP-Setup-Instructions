#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Defaults & args
# -----------------------------
MODEL="qwen3:8b"

usage() {
  echo "Usage: $0 [-m MODEL]"
  echo "  -m MODEL   Ollama model to pull/use (default: qwen2.5)"
  exit 1
}

while getopts ":m:h" opt; do
  case "$opt" in
    m) MODEL="$OPTARG" ;;
    h|\?) usage ;;
  esac
done

# -----------------------------
# Helpers
# -----------------------------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

on_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew not found. Please install it from https://brew.sh and re-run."
    exit 1
  fi
  ok "Homebrew is installed."
}

ensure_pkg() {
  local formula="$1"
  if ! brew list --formula "$formula" >/dev/null 2>&1; then
    info "Installing $formula..."
    brew install "$formula"
  else
    ok "$formula already installed."
  fi
}

append_path_once() {
  local line="$1"
  local rc="$2"
  if [[ -f "$rc" ]]; then
    if ! grep -qsF "$line" "$rc"; then
      printf "\n# Added by setup_ollama_mcphost.sh\n%s\n" "$line" >> "$rc"
      ok "Updated $rc"
    fi
  fi
}

current_shell_rc() {
  # Try to pick the right rc file for the current shell
  case "${SHELL##*/}" in
    zsh) echo "$HOME/.zshrc" ;;
    bash) 
      # Prefer ~/.bashrc, fallback to ~/.bash_profile
      [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc" || echo "$HOME/.bash_profile"
      ;;
    *) echo "$HOME/.zshrc" ;; # default to zsh
  esac
}

# -----------------------------
# Checks
# -----------------------------
if ! on_macos; then
  err "This script is intended for macOS."
  exit 1
fi

info "Using Ollama model: $MODEL"

# -----------------------------
# Install prerequisites
# -----------------------------
ensure_brew

ensure_pkg ollama
ensure_pkg go

# Your config uses npx; ensure it's available
if ! command -v npx >/dev/null 2>&1; then
  warn "npx not found; installing Node.js to provide npx."
  ensure_pkg node
else
  ok "npx is available."
fi

# -----------------------------
# Start ollama service & pull model
# -----------------------------
info "Starting Ollama (via brew services)..."
brew services start ollama >/dev/null 2>&1 || true
sleep 2

info "Pulling model '$MODEL' (this may take a while the first time)..."
# Use 'pull' to download without launching a session
if ! ollama pull "$MODEL"; then
  warn "ollama pull failed; trying 'ollama run' which can also trigger a pull..."
  echo "exit" | ollama run "$MODEL" || {
    err "Failed to pull model '$MODEL'."
    exit 1
  }
fi
ok "Model '$MODEL' is ready."

# -----------------------------
# Write MCP config
# -----------------------------
CONFIG_DIR="$HOME/.config/mcphost"
CONFIG_PATH="$CONFIG_DIR/mcp_config.json"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_PATH" <<'JSON'
{
  "mcpServers": {
    "swiss-ai-weeks-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://unic-swiss-ai-weeks-mcp.azurewebsites.net/mcp/"
      ]
    }
  }
}
JSON

ok "Wrote MCP config to: $CONFIG_PATH"

# -----------------------------
# Install mcphost
# -----------------------------
info "Installing mcphost with Go..."
# GOPATH/GOBIN discovery
GO_BIN_DIR="$(go env GOBIN)"
if [[ -z "$GO_BIN_DIR" ]]; then
  GO_BIN_DIR="$(go env GOPATH)/bin"
fi

go install github.com/mark3labs/mcphost@latest

# Make sure PATH contains the Go bin dir
RC_FILE="$(current_shell_rc)"
PATH_LINE="export PATH=\"\$PATH:$GO_BIN_DIR\""
append_path_once "$PATH_LINE" "$RC_FILE"

# Also add to ~/.zshrc if current shell rc wasn't zsh (common on macOS)
if [[ "$RC_FILE" != "$HOME/.zshrc" ]]; then
  append_path_once "$PATH_LINE" "$HOME/.zshrc"
fi

# Make mcphost discoverable in the *current* session too
export PATH="$PATH:$GO_BIN_DIR"

# Verify installation
if [[ -x "$GO_BIN_DIR/mcphost" ]]; then
  ok "mcphost installed at $GO_BIN_DIR/mcphost"
else
  err "mcphost binary not found in $GO_BIN_DIR after installation."
  err "Try opening a new terminal, or check: ls \"$GO_BIN_DIR/mcphost\""
  exit 1
fi

# -----------------------------
# Final message
# -----------------------------
echo
ok "All set!"
echo "You can start your MCP host with:"
echo
echo "  mcphost -m ollama:${MODEL} --config \"$CONFIG_PATH\""
echo
echo "If 'mcphost' isn't found, open a new terminal or run:"
echo "  source \"$RC_FILE\""
echo

