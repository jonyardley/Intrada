#!/bin/bash
# First build the CSS
npx tailwindcss -i ./style/main.css -o ./style/output.css

# Then start trunk with the CSS watcher in background
npm run build:css & 

# Start trunk serve (the $@ passes any command line arguments)
trunk serve $@

# Cleanup background processes when trunk is stopped
trap "kill 0" EXIT 