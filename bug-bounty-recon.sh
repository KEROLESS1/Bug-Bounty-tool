#!/bin/bash

################################################################################
# Bug Bounty Reconnaissance Automation Script
# Purpose: Automated subdomain enumeration and URL discovery
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGETS="targets.txt"
OUTPUT_DIR="output"
THREADS=50
TIMEOUT=10

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{subdomains,urls,live,screenshots,vulns}

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║   Bug Bounty Reconnaissance Automation Script    ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if targets file exists
if [ ! -f "$TARGETS" ]; then
    echo -e "${RED}[!] Error: $TARGETS file not found!${NC}"
    echo -e "${YELLOW}[*] Creating sample targets.txt file...${NC}"
    echo "example.com" > "$TARGETS"
    echo -e "${GREEN}[+] Created $TARGETS - Please add your target domains${NC}"
    exit 1
fi

# Display targets
echo -e "${BLUE}[*] Target domains:${NC}"
cat "$TARGETS"
echo ""

# Function to check if a tool is installed
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}[!] $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}[+] $1 is installed${NC}"
        return 0
    fi
}

# Check required tools
echo -e "${BLUE}[*] Checking required tools...${NC}"
TOOLS=(assetfinder subfinder httpx waybackurls gau nuclei)
MISSING_TOOLS=()

for tool in "${TOOLS[@]}"; do
    if ! check_tool "$tool"; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${YELLOW}[*] Missing tools: ${MISSING_TOOLS[*]}${NC}"
    echo -e "${YELLOW}[*] Install them with:${NC}"
    echo "  go install github.com/tomnomnom/assetfinder@latest"
    echo "  go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    echo "  go install github.com/projectdiscovery/httpx/cmd/httpx@latest"
    echo "  go install github.com/tomnomnom/waybackurls@latest"
    echo "  go install github.com/lc/gau/v2/cmd/gau@latest"
    echo "  go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

################################################################################
# PHASE 1: Subdomain Enumeration
################################################################################

echo -e "${BLUE}[*] Starting subdomain enumeration...${NC}"

# Assetfinder
if command -v assetfinder &> /dev/null; then
    echo -e "${YELLOW}[*] Running assetfinder...${NC}"
    cat "$TARGETS" | while read domain; do
        assetfinder --subs-only "$domain"
    done | sort -u > "$OUTPUT_DIR/subdomains/assetfinder.txt"
    echo -e "${GREEN}[+] Assetfinder found: $(wc -l < "$OUTPUT_DIR/subdomains/assetfinder.txt") subdomains${NC}"
fi

# Subfinder
if command -v subfinder &> /dev/null; then
    echo -e "${YELLOW}[*] Running subfinder...${NC}"
    subfinder -dL "$TARGETS" -silent -o "$OUTPUT_DIR/subdomains/subfinder.txt"
    echo -e "${GREEN}[+] Subfinder found: $(wc -l < "$OUTPUT_DIR/subdomains/subfinder.txt") subdomains${NC}"
fi

# Combine all subdomains
echo -e "${YELLOW}[*] Combining subdomain results...${NC}"
cat "$OUTPUT_DIR/subdomains/"*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/subdomains/all-subdomains.txt"
echo -e "${GREEN}[+] Total unique subdomains: $(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt")${NC}"

################################################################################
# PHASE 2: Probe Live Hosts
################################################################################

echo -e "${BLUE}[*] Probing for live hosts...${NC}"

if command -v httpx &> /dev/null; then
    cat "$OUTPUT_DIR/subdomains/all-subdomains.txt" | httpx -silent -threads "$THREADS" -timeout "$TIMEOUT" \
        -status-code -title -tech-detect -o "$OUTPUT_DIR/live/live-hosts.txt"
    echo -e "${GREEN}[+] Live hosts found: $(wc -l < "$OUTPUT_DIR/live/live-hosts.txt")${NC}"
    
    # Extract just the URLs
    cat "$OUTPUT_DIR/live/live-hosts.txt" | awk '{print $1}' > "$OUTPUT_DIR/live/live-urls.txt"
fi

################################################################################
# PHASE 3: URL Discovery
################################################################################

echo -e "${BLUE}[*] Starting URL discovery...${NC}"

# Waybackurls
if command -v waybackurls &> /dev/null; then
    echo -e "${YELLOW}[*] Running waybackurls...${NC}"
    cat "$TARGETS" | while read domain; do
        echo "$domain" | waybackurls
    done | sort -u > "$OUTPUT_DIR/urls/wayback-urls.txt"
    echo -e "${GREEN}[+] Wayback URLs found: $(wc -l < "$OUTPUT_DIR/urls/wayback-urls.txt")${NC}"
fi

# GAU (Get All URLs)
if command -v gau &> /dev/null; then
    echo -e "${YELLOW}[*] Running gau...${NC}"
    cat "$TARGETS" | while read domain; do
        echo "$domain" | gau --blacklist png,jpg,gif,jpeg,svg,css,woff,woff2,ttf,eot,ico
    done | sort -u > "$OUTPUT_DIR/urls/gau-urls.txt"
    echo -e "${GREEN}[+] GAU URLs found: $(wc -l < "$OUTPUT_DIR/urls/gau-urls.txt")${NC}"
fi

# Combine all URLs
echo -e "${YELLOW}[*] Combining URL results...${NC}"
cat "$OUTPUT_DIR/urls/"*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/urls/all-urls.txt"
echo -e "${GREEN}[+] Total unique URLs: $(wc -l < "$OUTPUT_DIR/urls/all-urls.txt")${NC}"

################################################################################
# PHASE 4: Filtering Interesting URLs
################################################################################

echo -e "${BLUE}[*] Filtering interesting URLs...${NC}"

# Parameters (potential for XSS, SQLi, etc.)
cat "$OUTPUT_DIR/urls/all-urls.txt" | grep "=" > "$OUTPUT_DIR/urls/urls-with-params.txt"
echo -e "${GREEN}[+] URLs with parameters: $(wc -l < "$OUTPUT_DIR/urls/urls-with-params.txt")${NC}"

# JavaScript files
cat "$OUTPUT_DIR/urls/all-urls.txt" | grep -E "\.js(\?|$)" > "$OUTPUT_DIR/urls/js-files.txt"
echo -e "${GREEN}[+] JavaScript files: $(wc -l < "$OUTPUT_DIR/urls/js-files.txt")${NC}"

# API endpoints
cat "$OUTPUT_DIR/urls/all-urls.txt" | grep -E "(api|v1|v2|v3|graphql|swagger)" > "$OUTPUT_DIR/urls/api-endpoints.txt"
echo -e "${GREEN}[+] Potential API endpoints: $(wc -l < "$OUTPUT_DIR/urls/api-endpoints.txt")${NC}"

################################################################################
# PHASE 5: Vulnerability Scanning (Optional)
################################################################################

echo ""
read -p "Run nuclei vulnerability scan? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] && command -v nuclei &> /dev/null; then
    echo -e "${BLUE}[*] Running nuclei scan...${NC}"
    nuclei -l "$OUTPUT_DIR/live/live-urls.txt" -severity critical,high,medium \
        -o "$OUTPUT_DIR/vulns/nuclei-results.txt"
    echo -e "${GREEN}[+] Nuclei scan complete!${NC}"
fi

################################################################################
# Summary
################################################################################

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  SCAN SUMMARY                     ║${NC}"
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}[+] Total Subdomains:       $(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt")${NC}"
echo -e "${GREEN}[+] Live Hosts:             $(wc -l < "$OUTPUT_DIR/live/live-urls.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${GREEN}[+] Total URLs:             $(wc -l < "$OUTPUT_DIR/urls/all-urls.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${GREEN}[+] URLs with Parameters:   $(wc -l < "$OUTPUT_DIR/urls/urls-with-params.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${GREEN}[+] JavaScript Files:       $(wc -l < "$OUTPUT_DIR/urls/js-files.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${GREEN}[+] API Endpoints:          $(wc -l < "$OUTPUT_DIR/urls/api-endpoints.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}[*] Results saved in: $OUTPUT_DIR/${NC}"
echo -e "${YELLOW}[*] Happy Hunting! 🎯${NC}"
