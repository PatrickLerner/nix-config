#!/usr/bin/env bash

set -e

echo "🔍 Running Nix linters..."

echo "📝 Formatting with nixfmt..."
find . -name "*.nix" -not -path "./.git/*" -exec nixfmt {} +

echo "💀 Checking for dead code with deadnix..."
deadnix .

echo "🔧 Running static analysis with statix..."
statix check .

echo "✅ Linting complete!"