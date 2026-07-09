#!/bin/sh
# Rebuilds styles.css from the Tailwind classes actually used in index.html.
# Run this after adding or changing any class in index.html -- an unbuilt class
# silently has no styles. Pinned to Tailwind 3.x to match what the old
# cdn.tailwindcss.com script served, so nothing shifts visually.
set -eu
cd "$(dirname "$0")/.."
npx -y tailwindcss@3 --input tailwind.css --output styles.css --content ./index.html --minify
