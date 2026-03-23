#!/usr/bin/env bash

# JavaScript & CSS Auto-Minifier with inotifywait
# Usage: ./watch-minify.sh [directory] [--recursive]

# Configuration
WATCH_DIR="${1:-.}"  # Default to current directory
RECURSIVE="${2}"
JS_MIN_SUFFIX=".min.js"
CSS_MIN_SUFFIX=".min.css"

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting JavaScript & CSS minifier watch...${NC}"
echo -e "Watching: ${WATCH_DIR}"
echo -e "Recursive: ${RECURSIVE:-no}\n"

# Check if inotify-tools is installed
if ! command -v inotifywait &> /dev/null; then
    echo -e "${RED}Error: inotifywait not found${NC}"
    echo "Install with: sudo apt-get install inotify-tools"
    exit 1
fi

# Check for JS minifier (prefer terser, fallback to uglifyjs)
JS_MINIFIER=""
if command -v terser &> /dev/null; then
    JS_MINIFIER="terser"
    echo -e "${GREEN}✓ Using terser for JavaScript minification${NC}"
elif command -v uglifyjs &> /dev/null; then
    JS_MINIFIER="uglifyjs"
    echo -e "${GREEN}✓ Using uglifyjs for JavaScript minification${NC}"
else
    echo -e "${YELLOW}⚠ No JavaScript minifier found${NC}"
    echo "  Install terser with: npm install -g terser"
    echo "  Or uglifyjs with: npm install -g uglify-js"
fi

# Check for CSS minifier (prefer csso, fallback to clean-css)
CSS_MINIFIER=""
if command -v csso &> /dev/null; then
    CSS_MINIFIER="csso"
    echo -e "${GREEN}✓ Using csso for CSS minification${NC}"
elif command -v cleancss &> /dev/null; then
    CSS_MINIFIER="cleancss"
    echo -e "${GREEN}✓ Using clean-css for CSS minification${NC}"
else
    echo -e "${YELLOW}⚠ No CSS minifier found${NC}"
    echo "  Install csso with: npm install -g csso-cli"
    echo "  Or clean-css with: npm install -g clean-css-cli"
fi

# Check if at least one minifier is available
if [ -z "$JS_MINIFIER" ] && [ -z "$CSS_MINIFIER" ]; then
    echo -e "\n${RED}Error: No minifiers found. Please install at least one.${NC}"
    exit 1
fi

echo ""

# Function to minify a JavaScript file
minify_js() {
    local file="$1"
    local basename="${file%.js}"
    local output="${basename}${JS_MIN_SUFFIX}"
    
    # Skip if file is already minified
    if [[ "$file" == *"$JS_MIN_SUFFIX" ]]; then
        return
    fi
    
    if [ -z "$JS_MINIFIER" ]; then
        echo -e "${YELLOW}Skipping JS (no minifier): ${file}${NC}"
        return
    fi
    
    echo -e "${BLUE}Minifying JS: ${file}${NC}"
    
    if [ "$JS_MINIFIER" = "terser" ]; then
        terser "$file" --compress --mangle -o "$output" 2>&1
    else
        uglifyjs "$file" --compress --mangle -o "$output" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        local original_size=$(wc -c < "$file")
        local minified_size=$(wc -c < "$output")
        local saved=$((original_size - minified_size))
        local percent=$((saved * 100 / original_size))
        echo -e "${GREEN}✓ Created: ${output}${NC}"
        echo -e "  Size: ${original_size} → ${minified_size} bytes (${percent}% reduction)\n"
    else
        echo -e "${RED}✗ Failed to minify ${file}${NC}\n"
    fi
}

# Function to minify a CSS file
minify_css() {
    local file="$1"
    local basename="${file%.css}"
    local output="${basename}${CSS_MIN_SUFFIX}"
    
    # Skip if file is already minified
    if [[ "$file" == *"$CSS_MIN_SUFFIX" ]]; then
        return
    fi
    
    if [ -z "$CSS_MINIFIER" ]; then
        echo -e "${YELLOW}Skipping CSS (no minifier): ${file}${NC}"
        return
    fi
    
    echo -e "${BLUE}Minifying CSS: ${file}${NC}"
    
    if [ "$CSS_MINIFIER" = "csso" ]; then
        csso "$file" -o "$output" 2>&1
    else
        cleancss "$file" -o "$output" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        local original_size=$(wc -c < "$file")
        local minified_size=$(wc -c < "$output")
        local saved=$((original_size - minified_size))
        local percent=$((saved * 100 / original_size))
        echo -e "${GREEN}✓ Created: ${output}${NC}"
        echo -e "  Size: ${original_size} → ${minified_size} bytes (${percent}% reduction)\n"
    else
        echo -e "${RED}✗ Failed to minify ${file}${NC}\n"
    fi
}

# Build inotifywait options
INOTIFY_OPTS="-e close_write -e moved_to"
if [ "$RECURSIVE" = "--recursive" ] || [ "$RECURSIVE" = "-r" ]; then
    INOTIFY_OPTS="$INOTIFY_OPTS -r"
fi

# Watch for file changes
inotifywait -m $INOTIFY_OPTS --format '%w%f' "$WATCH_DIR" | while read filepath
do
    # Check if it's a JS file (but not already minified)
    if [[ "$filepath" == *.js ]] && [[ "$filepath" != *"$JS_MIN_SUFFIX" ]]; then
        minify_js "$filepath"
    # Check if it's a CSS file (but not already minified)
    elif [[ "$filepath" == *.css ]] && [[ "$filepath" != *"$CSS_MIN_SUFFIX" ]]; then
        minify_css "$filepath"
    fi
done
