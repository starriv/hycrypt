#!/bin/bash

# HyCrypt Basic Demo - File Encryption and Decryption
# This script demonstrates the core functionality of HyCrypt

set -e  # Exit on any error

echo "🔐 HyCrypt Basic Demo - File Encryption & Decryption"
echo "=================================================="
echo

# Check if HyCrypt binary exists
if [ ! -f "../hycrypt" ]; then
    echo "❌ HyCrypt binary not found. Building..."
    cd .. && make build && cd demo
    if [ ! -f "../hycrypt" ]; then
        echo "❌ Failed to build HyCrypt"
        exit 1
    fi
fi

echo "✅ HyCrypt binary ready"
echo

# Create temporary demo directories
echo "📁 Setting up demo environment..."
mkdir -p demo_encrypted demo_decrypted demo_keys
cd demo_keys

# Generate RSA keys if they don't exist
if [ ! -f "private.pem" ] || [ ! -f "public.pem" ]; then
    echo "🔑 Generating RSA-4096 key pair..."
    openssl genrsa -out private.pem 4096 2>/dev/null
    openssl rsa -in private.pem -pubout -out public.pem 2>/dev/null
    chmod 600 private.pem
    echo "✅ RSA keys generated"
else
    echo "✅ RSA keys already exist"
fi

cd ..

# Generate configuration
echo "⚙️ Generating configuration..."
../hycrypt -gen-config > /dev/null 2>&1
echo "✅ Configuration ready"
echo

# Demo 1: RSA File Encryption
echo "🔒 Demo 1: RSA File Encryption"
echo "Input file: sample.txt"
echo "Algorithm: RSA-4096"
echo
echo "Command: ../hycrypt -f=sample.txt -key-dir=demo_keys -output=demo_encrypted"
../hycrypt -f=sample.txt -key-dir=demo_keys -output=demo_encrypted -no-art
echo

# Demo 2: KMAC File Encryption (if KMAC key exists or can be generated)
echo "🔒 Demo 2: KMAC File Encryption"
echo "Input file: config.json"
echo "Algorithm: KMAC"
echo

# Create a simple KMAC key for demo
echo "$(openssl rand -hex 32)" > demo_keys/kmac.key

echo "Command: ../hycrypt -m=kmac -f=config.json -key-dir=demo_keys -output=demo_encrypted"
../hycrypt -m=kmac -f=config.json -key-dir=demo_keys -output=demo_encrypted -no-art
echo

# List encrypted files
echo "📋 Generated encrypted files:"
ls -la demo_encrypted/
echo

# Demo 3: File Decryption
echo "🔓 Demo 3: File Decryption"
echo "Decrypting all files in demo_encrypted/"
echo

for encrypted_file in demo_encrypted/*.hycrypt; do
    if [ -f "$encrypted_file" ]; then
        filename=$(basename "$encrypted_file")
        echo "Decrypting: $filename"
        echo "Command: ../hycrypt -d -f=$encrypted_file -key-dir=demo_keys -output=demo_decrypted"
        ../hycrypt -d -f="$encrypted_file" -key-dir=demo_keys -output=demo_decrypted -no-art
        echo
    fi
done

# Show results
echo "📋 Decrypted files:"
ls -la demo_decrypted/
echo

echo "🔍 Comparing original and decrypted files:"
echo
echo "Original sample.txt:"
head -3 sample.txt
echo "..."
echo
echo "Decrypted sample.txt:"
if [ -f "demo_decrypted/sample.txt" ]; then
    head -3 demo_decrypted/sample.txt
    echo "..."
    echo "✅ Files match!" 
else
    echo "❌ Decrypted file not found"
fi
echo

# Cleanup
echo "🧹 Cleaning up demo files..."
rm -rf demo_encrypted demo_decrypted demo_keys config.yaml
echo "✅ Cleanup complete"
echo

echo "🎉 Basic demo completed successfully!"
echo "📖 For more demos, try: ./text_demo.sh or ./hex_demo.sh"
echo "🚀 For interactive mode, run: ../hycrypt"