#!/bin/bash

# HyCrypt Text Demo - Text Encryption and Decryption
# This script demonstrates text encryption features

set -e  # Exit on any error

echo "📝 HyCrypt Text Demo - Text Encryption & Decryption"
echo "=================================================="
echo

# Check if HyCrypt binary exists
if [ ! -f "../hycrypt" ]; then
    echo "❌ HyCrypt binary not found. Please run 'make build' first"
    exit 1
fi

echo "✅ HyCrypt binary ready"
echo

# Setup demo environment
echo "📁 Setting up demo environment..."
mkdir -p demo_keys demo_text_output

# Generate keys if needed
if [ ! -f "demo_keys/private.pem" ]; then
    echo "🔑 Generating RSA keys..."
    openssl genrsa -out demo_keys/private.pem 4096 2>/dev/null
    openssl rsa -in demo_keys/private.pem -pubout -out demo_keys/public.pem 2>/dev/null
    chmod 600 demo_keys/private.pem
fi

# Generate KMAC key
echo "$(openssl rand -hex 32)" > demo_keys/kmac.key

# Generate config
../hycrypt -gen-config > /dev/null 2>&1

echo "✅ Demo environment ready"
echo

# Demo 1: Simple text encryption to file
echo "🔒 Demo 1: Text Encryption to File"
echo "Text: 'Hello, HyCrypt Demo!'"
echo "Algorithm: RSA"
echo "Output: File"
echo
echo "Command: echo 'Hello, HyCrypt Demo!' | ../hycrypt -t -key-dir=demo_keys -output=demo_text_output"
echo 'Hello, HyCrypt Demo!' | ../hycrypt -t -key-dir=demo_keys -output=demo_text_output -no-art
echo

# Demo 2: Multi-line text encryption
echo "🔒 Demo 2: Multi-line Text Encryption" 
echo "Algorithm: KMAC"
echo "Output: File"
echo
DEMO_TEXT="Demo Configuration:
Database: localhost:5432
Username: demo_user
Environment: development
Encrypted: $(date)"

echo "Text content:"
echo "$DEMO_TEXT"
echo
echo "Command: echo \$DEMO_TEXT | ../hycrypt -t -m=kmac -key-dir=demo_keys -output=demo_text_output"
echo "$DEMO_TEXT" | ../hycrypt -t -m=kmac -key-dir=demo_keys -output=demo_text_output -no-art
echo

# Show encrypted files
echo "📋 Generated encrypted files:"
ls -la demo_text_output/
echo

# Demo 3: Text decryption
echo "🔓 Demo 3: Text File Decryption"
echo "Decrypting text files..."
echo

for encrypted_file in demo_text_output/*.hycrypt; do
    if [ -f "$encrypted_file" ]; then
        filename=$(basename "$encrypted_file")
        echo "Decrypting: $filename"
        echo "Command: ../hycrypt -d -f=$encrypted_file -key-dir=demo_keys -output=demo_text_output"
        ../hycrypt -d -f="$encrypted_file" -key-dir=demo_keys -output=demo_text_output -no-art
        echo
    fi
done

# Show decrypted files
echo "📋 Decrypted files:"
ls -la demo_text_output/*.txt 2>/dev/null || echo "No .txt files found"
echo

# Show content of decrypted files
for txt_file in demo_text_output/*.txt; do
    if [ -f "$txt_file" ]; then
        echo "Content of $(basename "$txt_file"):"
        cat "$txt_file"
        echo
    fi
done

# Cleanup
echo "🧹 Cleaning up demo files..."
rm -rf demo_keys demo_text_output config.yaml
echo "✅ Cleanup complete"
echo

echo "🎉 Text demo completed successfully!"
echo "📖 For hex output demo, try: ./hex_demo.sh"
echo "🚀 For interactive mode, run: ../hycrypt"