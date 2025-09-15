#!/bin/bash

# HyCrypt Demo Script
# This script demonstrates basic HyCrypt usage patterns

echo "=== HyCrypt Demo Script ==="
echo "This script shows common usage patterns"
echo

# Check if HyCrypt is available
if ! command -v ../hycrypt &> /dev/null; then
    echo "❌ HyCrypt binary not found. Please build it first:"
    echo "   make build"
    exit 1
fi

echo "✅ HyCrypt binary found"
echo

# Function to print section headers
print_section() {
    echo
    echo "$(printf '=%.0s' {1..50})"
    echo "$1"
    echo "$(printf '=%.0s' {1..50})"
    echo
}

# Function to print command and execute
run_command() {
    echo "$ $1"
    eval "$1"
    echo
}

print_section "1. Generate Configuration"
run_command "../hycrypt -gen-config"

print_section "2. Display Help"
run_command "../hycrypt -help"

print_section "3. File Encryption Examples"
echo "Command examples (not executed in demo):"
echo "  ../hycrypt -f=sample.txt                    # RSA encryption"
echo "  ../hycrypt -m=kmac -f=config.json         # KMAC encryption"
echo "  ../hycrypt -f=demo_folder                 # Directory encryption"
echo

print_section "4. Text Encryption Examples"  
echo "Command examples (not executed in demo):"
echo "  echo 'Secret message' | ../hycrypt -t                        # Text to file"
echo "  echo 'Secret message' | ../hycrypt -t --output-format=hex   # Text to hex"
echo "  cat document.md | ../hycrypt -t -m=kmac                     # Pipe file content"
echo

print_section "5. Decryption Examples"
echo "Command examples (not executed in demo):"
echo "  ../hycrypt -d -f=sample-20241215-rsa.hycrypt              # File decryption"
echo "  echo 'hex_string' | ../hycrypt -d -t --input-format=hex   # Hex decryption"
echo

print_section "Demo Complete"
echo "🎉 HyCrypt demo script completed!"
echo "📖 For full functionality, run: make demo"
echo "🚀 For interactive mode, run: ../hycrypt"