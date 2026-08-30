#!/bin/bash
# Build script for Vercel - Flutter Web
set -e

echo "🚀 Starting Flutter Web build on Vercel..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "📦 Flutter is not installed. Installing Flutter stable..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
    export PATH="$PATH:$HOME/flutter/bin"
fi

# Enable web support and pre-cache web artifacts
flutter config --enable-web
flutter precache --web

# Get Flutter dependencies
flutter pub get

# Build Flutter web app
flutter build web --release

echo "✅ Flutter web build completed successfully in build/web"
