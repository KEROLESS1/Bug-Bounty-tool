#!/bin/bash

################################################################################
# Advanced Bug Bounty Automation Script
# Includes: Port scanning, technology detection, screenshot capture
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TARGETS="${1:-targets.txt}"
OUTPUT_DIR="output-$(date +%Y%m%d-%H%M%S)"
THREADS=50
TIMEOUT=10
RATE_LIMIT=150  # requests per second

# Usage
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: $0 [targets_file]"
    echo "Default: targets.txt"
    exit 0
fi

# Create directory structure
mkdir -p "$OUTPUT_DIR"/{subdomains,urls,live,ports,screenshots,vulns,technologies,javascript}

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ██████╗ ██╗   ██╗ ██████╗     ██████╗  ██████╗ ██╗   ║
║   ██╔══██╗██║   ██║██╔════╝     ██╔══██╗██╔═══██╗╚██╗  ║
║   ██████╔╝██║   ██║██║  ███╗    ██████╔╝██║   ██║ ╚██╗ ║
║   ██╔══██╗██║   ██║██║   ██║    ██╔══██╗██║   ██║ ██╔╝ ║
║   ██████╔╝╚██████╔╝╚██████╔╝    ██████╔╝╚██████╔╝██╔╝  ║
║   ╚═════╝  ╚═════╝  ╚═════╝     ╚═════╝  ╚═════╝ ╚═╝   ║
║                                                          ║
║         Advanced Reconnaissance Automation               ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check targets file
if [ ! -f "$TARGETS" ]; then
    echo -e "${RED}[!] Error: $TARGETS not found!${NC}"
    exit 1
fi

# Log file
LOG_FILE="$OUTPUT_DIR/scan.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}[*] Started at: $(date)${NC}"
echo -e "${BLUE}[*] Target file: $TARGETS${NC}"
echo -e "${BLUE}[*] Output directory: $OUTPUT_DIR${NC}"
echo ""

################################################################################
# Tool Check Function
################################################################################

check_tools() {
    local tools=("$@")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${YELLOW}[!] Missing tools: ${missing[*]}${NC}"
        return 1
    fi
    return 0
}

################################################################################
# PHASE 1: Subdomain Enumeration
################################################################################

phase_subdomains() {
    echo -e "${MAGENTA}[PHASE 1] Subdomain Enumeration${NC}"
    
    # Passive sources
    echo -e "${YELLOW}[*] Running passive subdomain enumeration...${NC}"
    
    if command -v assetfinder &> /dev/null; then
        cat "$TARGETS" | assetfinder --subs-only | sort -u > "$OUTPUT_DIR/subdomains/assetfinder.txt"
        echo -e "${GREEN}[+] Assetfinder: $(wc -l < "$OUTPUT_DIR/subdomains/assetfinder.txt")${NC}"
    fi
    
    if command -v subfinder &> /dev/null; then
        subfinder -dL "$TARGETS" -all -silent -o "$OUTPUT_DIR/subdomains/subfinder.txt"
        echo -e "${GREEN}[+] Subfinder: $(wc -l < "$OUTPUT_DIR/subdomains/subfinder.txt")${NC}"
    fi
    
    if command -v amass &> /dev/null; then
        echo -e "${YELLOW}[*] Running amass (this may take a while)...${NC}"
        amass enum -passive -df "$TARGETS" -o "$OUTPUT_DIR/subdomains/amass.txt" -timeout 30
        echo -e "${GREEN}[+] Amass: $(wc -l < "$OUTPUT_DIR/subdomains/amass.txt")${NC}"
    fi
    
    # Combine results
    cat "$OUTPUT_DIR/subdomains/"*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/subdomains/all-subdomains.txt"
    
    TOTAL_SUBS=$(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt")
    echo -e "${GREEN}[✓] Total unique subdomains: $TOTAL_SUBS${NC}"
    echo ""
}

################################################################################
# PHASE 2: Live Host Detection
################################################################################

phase_live_hosts() {
    echo -e "${MAGENTA}[PHASE 2] Live Host Detection${NC}"
    
    if command -v httpx &> /dev/null; then
        cat "$OUTPUT_DIR/subdomains/all-subdomains.txt" | httpx \
            -silent \
            -threads "$THREADS" \
            -timeout "$TIMEOUT" \
            -status-code \
            -title \
            -tech-detect \
            -cdn \
            -web-server \
            -follow-redirects \
            -random-agent \
            -rate-limit "$RATE_LIMIT" \
            -json \
            -o "$OUTPUT_DIR/live/live-hosts.json"
        
        # Extract URLs
        cat "$OUTPUT_DIR/live/live-hosts.json" | jq -r '.url' 2>/dev/null > "$OUTPUT_DIR/live/live-urls.txt"
        
        LIVE_HOSTS=$(wc -l < "$OUTPUT_DIR/live/live-urls.txt")
        echo -e "${GREEN}[✓] Live hosts: $LIVE_HOSTS${NC}"
    fi
    echo ""
}

################################################################################
# PHASE 3: Port Scanning
################################################################################

phase_port_scan() {
    echo -e "${MAGENTA}[PHASE 3] Port Scanning${NC}"
    
    if command -v naabu &> /dev/null; then
        echo -e "${YELLOW}[*] Scanning common ports...${NC}"
        
        cat "$OUTPUT_DIR/subdomains/all-subdomains.txt" | naabu \
            -silent \
            -top-ports 1000 \
            -rate "$RATE_LIMIT" \
            -o "$OUTPUT_DIR/ports/open-ports.txt"
        
        echo -e "${GREEN}[✓] Port scan complete${NC}"
    else
        echo -e "${YELLOW}[!] naabu not installed, skipping port scan${NC}"
    fi
    echo ""
}

################################################################################
# PHASE 4: URL Discovery
################################################################################

phase_url_discovery() {
    echo -e "${MAGENTA}[PHASE 4] URL Discovery${NC}"
    
    # Wayback Machine
    if command -v waybackurls &> /dev/null; then
        echo -e "${YELLOW}[*] Fetching URLs from Wayback Machine...${NC}"
        cat "$TARGETS" | waybackurls | sort -u > "$OUTPUT_DIR/urls/wayback.txt"
        echo -e "${GREEN}[+] Wayback: $(wc -l < "$OUTPUT_DIR/urls/wayback.txt")${NC}"
    fi
    
    # GAU
    if command -v gau &> /dev/null; then
        echo -e "${YELLOW}[*] Running GAU...${NC}"
        cat "$TARGETS" | gau \
            --blacklist png,jpg,gif,jpeg,svg,css,woff,woff2,ttf,eot,ico,mp4,mp3,webm \
            --threads "$THREADS" | sort -u > "$OUTPUT_DIR/urls/gau.txt"
        echo -e "${GREEN}[+] GAU: $(wc -l < "$OUTPUT_DIR/urls/gau.txt")${NC}"
    fi
    
    # Katana crawler
    if command -v katana &> /dev/null; then
        echo -e "${YELLOW}[*] Running Katana crawler...${NC}"
        cat "$OUTPUT_DIR/live/live-urls.txt" | katana \
            -silent \
            -d 3 \
            -jc \
            -kf all \
            -rate-limit "$RATE_LIMIT" \
            -o "$OUTPUT_DIR/urls/katana.txt"
        echo -e "${GREEN}[+] Katana: $(wc -l < "$OUTPUT_DIR/urls/katana.txt")${NC}"
    fi
    
    # Combine all URLs
    cat "$OUTPUT_DIR/urls/"*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/urls/all-urls.txt"
    
    TOTAL_URLS=$(wc -l < "$OUTPUT_DIR/urls/all-urls.txt")
    echo -e "${GREEN}[✓] Total URLs: $TOTAL_URLS${NC}"
    echo ""
}

################################################################################
# PHASE 5: URL Filtering
################################################################################

phase_url_filtering() {
    echo -e "${MAGENTA}[PHASE 5] URL Filtering & Classification${NC}"
    
    # Parameters
    grep "=" "$OUTPUT_DIR/urls/all-urls.txt" > "$OUTPUT_DIR/urls/params.txt"
    echo -e "${GREEN}[+] URLs with parameters: $(wc -l < "$OUTPUT_DIR/urls/params.txt")${NC}"
    
    # JavaScript files
    grep -E "\.js(\?|$)" "$OUTPUT_DIR/urls/all-urls.txt" > "$OUTPUT_DIR/javascript/js-files.txt"
    echo -e "${GREEN}[+] JavaScript files: $(wc -l < "$OUTPUT_DIR/javascript/js-files.txt")${NC}"
    
    # API endpoints
    grep -iE "(api|graphql|swagger|v1|v2|v3|rest)" "$OUTPUT_DIR/urls/all-urls.txt" > "$OUTPUT_DIR/urls/api.txt"
    echo -e "${GREEN}[+] API endpoints: $(wc -l < "$OUTPUT_DIR/urls/api.txt")${NC}"
    
    # Login/Auth pages
    grep -iE "(login|signin|signup|register|auth|oauth)" "$OUTPUT_DIR/urls/all-urls.txt" > "$OUTPUT_DIR/urls/auth.txt"
    echo -e "${GREEN}[+] Auth endpoints: $(wc -l < "$OUTPUT_DIR/urls/auth.txt")${NC}"
    
    # File uploads
    grep -iE "(upload|file|attachment|document)" "$OUTPUT_DIR/urls/all-urls.txt" > "$OUTPUT_DIR/urls/uploads.txt"
    echo -e "${GREEN}[+] Upload endpoints: $(wc -l < "$OUTPUT_DIR/urls/uploads.txt")${NC}"
    
    # Admin panels
    grep -iE "(admin|dashboard|cpanel|phpmyadmin|wp-admin)" "$OUTPUT_DIR/urls/all-urls.txt" > "$OUTPUT_DIR/urls/admin.txt"
    echo -e "${GREEN}[+] Admin panels: $(wc -l < "$OUTPUT_DIR/urls/admin.txt")${NC}"
    
    echo ""
}

################################################################################
# PHASE 6: JavaScript Analysis
################################################################################

phase_js_analysis() {
    echo -e "${MAGENTA}[PHASE 6] JavaScript Analysis${NC}"
    
    if [ -s "$OUTPUT_DIR/javascript/js-files.txt" ]; then
        echo -e "${YELLOW}[*] Analyzing JavaScript files for secrets...${NC}"
        
        # Download and analyze JS files (first 100)
        head -100 "$OUTPUT_DIR/javascript/js-files.txt" | while read url; do
            curl -sk "$url" 2>/dev/null | grep -oE "(api[_-]?key|apikey|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key|client[_-]?secret)" >> "$OUTPUT_DIR/javascript/secrets.txt"
        done
        
        if [ -f "$OUTPUT_DIR/javascript/secrets.txt" ]; then
            sort -u "$OUTPUT_DIR/javascript/secrets.txt" > "$OUTPUT_DIR/javascript/potential-secrets.txt"
            rm "$OUTPUT_DIR/javascript/secrets.txt"
            echo -e "${GREEN}[+] Found potential secrets: $(wc -l < "$OUTPUT_DIR/javascript/potential-secrets.txt")${NC}"
        fi
    fi
    echo ""
}

################################################################################
# PHASE 7: Vulnerability Scanning
################################################################################

phase_vulnerability_scan() {
    echo -e "${MAGENTA}[PHASE 7] Vulnerability Scanning${NC}"
    
    read -p "$(echo -e ${YELLOW}"Run nuclei vulnerability scan? (y/n): "${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v nuclei &> /dev/null; then
            echo -e "${YELLOW}[*] Running nuclei (this may take a while)...${NC}"
            
            nuclei -update-templates -silent
            
            nuclei -l "$OUTPUT_DIR/live/live-urls.txt" \
                -severity critical,high,medium \
                -es info \
                -rl "$RATE_LIMIT" \
                -bs 25 \
                -c "$THREADS" \
                -silent \
                -json \
                -o "$OUTPUT_DIR/vulns/nuclei.json"
            
            # Create readable report
            cat "$OUTPUT_DIR/vulns/nuclei.json" | jq -r '"\(.info.severity) - \(.info.name) - \(.host)"' > "$OUTPUT_DIR/vulns/nuclei-summary.txt"
            
            echo -e "${GREEN}[✓] Nuclei scan complete${NC}"
        else
            echo -e "${RED}[!] Nuclei not installed${NC}"
        fi
    fi
    echo ""
}

################################################################################
# PHASE 8: Subdomain Takeover Check
################################################################################

phase_takeover_check() {
    echo -e "${MAGENTA}[PHASE 8] Subdomain Takeover Check${NC}"
    
    if command -v subzy &> /dev/null; then
        subzy run --targets "$OUTPUT_DIR/subdomains/all-subdomains.txt" \
            --concurrency 50 \
            --output "$OUTPUT_DIR/vulns/takeover.txt"
        
        echo -e "${GREEN}[✓] Takeover check complete${NC}"
    else
        echo -e "${YELLOW}[!] subzy not installed, skipping${NC}"
    fi
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    phase_subdomains
    phase_live_hosts
    phase_port_scan
    phase_url_discovery
    phase_url_filtering
    phase_js_analysis
    phase_vulnerability_scan
    phase_takeover_check
    
    # Final Summary
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   SCAN SUMMARY                         ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} %-30s ${GREEN}%20s ${CYAN}║${NC}\n" "Total Subdomains:" "$(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt")"
    printf "${CYAN}║${NC} %-30s ${GREEN}%20s ${CYAN}║${NC}\n" "Live Hosts:" "$(wc -l < "$OUTPUT_DIR/live/live-urls.txt" 2>/dev/null || echo 0)"
    printf "${CYAN}║${NC} %-30s ${GREEN}%20s ${CYAN}║${NC}\n" "Total URLs:" "$(wc -l < "$OUTPUT_DIR/urls/all-urls.txt" 2>/dev/null || echo 0)"
    printf "${CYAN}║${NC} %-30s ${GREEN}%20s ${CYAN}║${NC}\n" "URLs with Parameters:" "$(wc -l < "$OUTPUT_DIR/urls/params.txt" 2>/dev/null || echo 0)"
    printf "${CYAN}║${NC} %-30s ${GREEN}%20s ${CYAN}║${NC}\n" "JavaScript Files:" "$(wc -l < "$OUTPUT_DIR/javascript/js-files.txt" 2>/dev/null || echo 0)"
    printf "${CYAN}║${NC} %-30s ${GREEN}%20s ${CYAN}║${NC}\n" "API Endpoints:" "$(wc -l < "$OUTPUT_DIR/urls/api.txt" 2>/dev/null || echo 0)"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${BLUE}[*] Finished at: $(date)${NC}"
    echo -e "${GREEN}[*] Results saved in: $OUTPUT_DIR${NC}"
    echo -e "${YELLOW}[*] Log file: $LOG_FILE${NC}"
    echo -e "${MAGENTA}[*] Happy Hunting! 🎯${NC}"
}

# Run main function
main
