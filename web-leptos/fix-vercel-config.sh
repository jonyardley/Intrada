#!/bin/bash

# Fix Vercel configuration after build
# This script fixes the invalid regex pattern in vercel.json

set -e

DIST_DIR="./dist"
VERCEL_CONFIG="$DIST_DIR/vercel.json"

echo "🔧 Fixing Vercel configuration..."

if [[ ! -f "$VERCEL_CONFIG" ]]; then
    echo "⚠️  $VERCEL_CONFIG not found, creating new one..."
    
    cat > "$VERCEL_CONFIG" << 'EOF'
{
    "rewrites": [
        {
            "source": "/(.*)",
            "destination": "/index.html"
        }
    ],
    "headers": [
        {
            "source": "/(.*)\\.wasm",
            "headers": [
                {
                    "key": "Content-Type",
                    "value": "application/wasm"
                },
                {
                    "key": "Cache-Control",
                    "value": "public, max-age=31536000, immutable"
                }
            ]
        },
        {
            "source": "/(.*)\\.js",
            "headers": [
                {
                    "key": "Cache-Control",
                    "value": "public, max-age=31536000, immutable"
                }
            ]
        },
        {
            "source": "/(.*)\\.css",
            "headers": [
                {
                    "key": "Cache-Control",
                    "value": "public, max-age=31536000, immutable"
                }
            ]
        }
    ]
}
EOF
    
    echo "✅ Created new vercel.json"
else
    echo "📝 Updating existing vercel.json..."
    
    # Create a temporary fixed version
    cat > "$VERCEL_CONFIG.tmp" << 'EOF'
{
    "rewrites": [
        {
            "source": "/(.*)",
            "destination": "/index.html"
        }
    ],
    "headers": [
        {
            "source": "/(.*)\\.wasm",
            "headers": [
                {
                    "key": "Content-Type",
                    "value": "application/wasm"
                },
                {
                    "key": "Cache-Control",
                    "value": "public, max-age=31536000, immutable"
                }
            ]
        },
        {
            "source": "/(.*)\\.js",
            "headers": [
                {
                    "key": "Cache-Control",
                    "value": "public, max-age=31536000, immutable"
                }
            ]
        },
        {
            "source": "/(.*)\\.css",
            "headers": [
                {
                    "key": "Cache-Control",
                    "value": "public, max-age=31536000, immutable"
                }
            ]
        }
    ]
}
EOF
    
    # Replace the original with the fixed version
    mv "$VERCEL_CONFIG.tmp" "$VERCEL_CONFIG"
    
    echo "✅ Fixed vercel.json - removed problematic regex pattern"
fi

echo "🎉 Vercel configuration fixed!"
echo "📄 Contents of $VERCEL_CONFIG:"
cat "$VERCEL_CONFIG"