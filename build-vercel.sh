#!/bin/bash
# Build script for Vercel - Flutter Web
# This script builds the Flutter web app for Vercel deployment

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter is not installed. Installing..."
    # Download Flutter
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
    export PATH="$PATH:`pwd`/flutter/bin"
fi

# Get Flutter dependencies
flutter pub get

# Build Flutter web app
flutter build web --release --no-web-resources-cdn

echo "Flutter web build completed successfully"
