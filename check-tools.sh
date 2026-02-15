#!/bin/bash

################################################################################
# Quick Tool Verification Script
# Checks if all bug bounty tools are installed and working
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════╗"
echo "║   Bug Bounty Tools - Health Check         ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Counters
TOTAL=0
WORKING=0
MISSING=0

# Function to check tool
check_tool() {
    local tool=$1
    local description=$2
    ((TOTAL++))
    
    printf "%-20s " "$tool"
    
    if command -v "$tool" &> /dev/null; then
        # Try to verify it works
        if timeout 2 "$tool" -h &> /dev/null || \
           timeout 2 "$tool" --help &> /dev/null || \
           timeout 2 "$tool" -version &> /dev/null || \
           timeout 2 "$tool" version &> /dev/null; then
            echo -e "${GREEN}[✓ WORKING]${NC}   $description"
            ((WORKING++))
            return 0
        else
            echo -e "${GREEN}[✓ FOUND]${NC}     $description"
            ((WORKING++))
            return 0
        fi
    else
        echo -e "${RED}[✗ MISSING]${NC}   $description"
        ((MISSING++))
        return 1
    fi
}

echo -e "${BLUE}Checking Essential Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

# Core Tools
check_tool "go" "Go programming language"
check_tool "git" "Version control"
check_tool "curl" "HTTP client"
check_tool "wget" "File downloader"
check_tool "python3" "Python 3"
check_tool "pip3" "Python package manager"

echo ""
echo -e "${BLUE}Checking Subdomain Enumeration Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "assetfinder" "Fast subdomain discovery"
check_tool "subfinder" "Passive subdomain enumeration"
check_tool "amass" "In-depth subdomain enumeration (optional)"

echo ""
echo -e "${BLUE}Checking HTTP/Network Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "httpx" "HTTP toolkit and prober"
check_tool "httprobe" "HTTP probe (alternative)"
check_tool "naabu" "Fast port scanner"

echo ""
echo -e "${BLUE}Checking URL Discovery Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "waybackurls" "Wayback Machine URL fetcher"
check_tool "gau" "Get All URLs from sources"
check_tool "hakrawler" "Web crawler"
check_tool "katana" "Advanced web crawler"

echo ""
echo -e "${BLUE}Checking Fuzzing & Discovery Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "ffuf" "Fast web fuzzer"
check_tool "gobuster" "Directory/DNS/vhost bruteforcer (optional)"
check_tool "arjun" "HTTP parameter discovery"

echo ""
echo -e "${BLUE}Checking Vulnerability Scanners:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "nuclei" "Vulnerability scanner"
check_tool "dalfox" "XSS scanner"

echo ""
echo -e "${BLUE}Checking Subdomain Takeover Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "subzy" "Subdomain takeover checker"
check_tool "subjack" "Subdomain takeover tool"

echo ""
echo -e "${BLUE}Checking Utility Tools:${NC}"
echo "────────────────────────────────────────────────────────────"

check_tool "anew" "Add new lines to files"
check_tool "gf" "Pattern matching wrapper"
check_tool "unfurl" "URL parser"
check_tool "qsreplace" "Query string replacer"
check_tool "uro" "URL deduplicator"
check_tool "jq" "JSON processor"

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${CYAN}Summary:${NC}"
echo "────────────────────────────────────────────────────────────"
echo -e "  Total Tools Checked: ${BLUE}$TOTAL${NC}"
echo -e "  ${GREEN}Working: $WORKING${NC}"
echo -e "  ${RED}Missing: $MISSING${NC}"
echo "════════════════════════════════════════════════════════════"

# Calculate percentage
if [ $TOTAL -gt 0 ]; then
    PERCENTAGE=$((WORKING * 100 / TOTAL))
    echo -e "  Coverage: ${CYAN}${PERCENTAGE}%${NC}"
fi

echo ""

# Recommendations
if [ $MISSING -gt 0 ]; then
    echo -e "${YELLOW}⚠ Recommendations:${NC}"
    echo ""
    echo "Some tools are missing. To install all tools, run:"
    echo -e "${BLUE}  ./install-tools.sh${NC}"
    echo ""
    echo "Or install missing tools manually:"
    echo -e "${BLUE}  go install github.com/tool/path@latest${NC}"
    echo ""
else
    echo -e "${GREEN}✓ All tools are installed and ready!${NC}"
    echo ""
    echo "You can now run the bug bounty scripts:"
    echo -e "${BLUE}  ./bug-bounty-recon.sh${NC}"
    echo -e "${BLUE}  ./advanced-recon.sh${NC}"
    echo ""
fi

# Check PATH
echo -e "${BLUE}Checking Go binary PATH:${NC}"
if [[ ":$PATH:" == *":$HOME/go/bin:"* ]]; then
    echo -e "${GREEN}✓ Go bin directory is in PATH${NC}"
else
    echo -e "${YELLOW}⚠ Go bin directory not in PATH${NC}"
    echo "Add to your shell config (~/.bashrc or ~/.zshrc):"
    echo -e "${BLUE}  export PATH=\$PATH:\$HOME/go/bin${NC}"
    echo "Then reload: source ~/.bashrc"
fi

echo ""

# Check Nuclei templates
if command -v nuclei &> /dev/null; then
    echo -e "${BLUE}Checking Nuclei templates:${NC}"
    TEMPLATE_COUNT=$(find ~/nuclei-templates -name "*.yaml" 2>/dev/null | wc -l)
    if [ $TEMPLATE_COUNT -gt 0 ]; then
        echo -e "${GREEN}✓ Found $TEMPLATE_COUNT nuclei templates${NC}"
    else
        echo -e "${YELLOW}⚠ No nuclei templates found${NC}"
        echo "Run: nuclei -update-templates"
    fi
fi

echo ""
echo -e "${CYAN}Happy Hunting! 🎯${NC}"
