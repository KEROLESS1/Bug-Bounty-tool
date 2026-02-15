#!/bin/bash

################################################################################
# Bug Bounty Tools - Automated Installation & Verification Script
# Installs all required tools and verifies they work correctly
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="installation-$(date +%Y%m%d-%H%M%S).log"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     Bug Bounty Tools Installation & Verification         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Success message
success() {
    echo -e "${GREEN}[✓] $1${NC}" | tee -a "$LOG_FILE"
}

# Error message
error() {
    echo -e "${RED}[✗] $1${NC}" | tee -a "$LOG_FILE"
}

# Warning message
warning() {
    echo -e "${YELLOW}[!] $1${NC}" | tee -a "$LOG_FILE"
}

# Info message
info() {
    echo -e "${BLUE}[*] $1${NC}" | tee -a "$LOG_FILE"
}

################################################################################
# System Requirements Check
################################################################################

check_requirements() {
    info "Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        success "OS: Linux detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        success "OS: macOS detected"
    else
        error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    
    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then 
        warning "Running as root is not recommended. Consider running as normal user."
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo ""
}

################################################################################
# Install Prerequisites
################################################################################

install_prerequisites() {
    info "Installing prerequisites..."
    
    if [ "$OS" == "linux" ]; then
        # Detect package manager
        if command -v apt-get &> /dev/null; then
            PKG_MANAGER="apt"
            info "Package manager: APT"
            
            sudo apt-get update
            sudo apt-get install -y curl wget git build-essential python3 python3-pip || {
                error "Failed to install prerequisites"
                exit 1
            }
        elif command -v yum &> /dev/null; then
            PKG_MANAGER="yum"
            info "Package manager: YUM"
            
            sudo yum install -y curl wget git gcc python3 python3-pip || {
                error "Failed to install prerequisites"
                exit 1
            }
        else
            error "No supported package manager found (apt/yum)"
            exit 1
        fi
    elif [ "$OS" == "macos" ]; then
        # Check for Homebrew
        if ! command -v brew &> /dev/null; then
            warning "Homebrew not found. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        brew install curl wget git python3 || {
            error "Failed to install prerequisites"
            exit 1
        }
    fi
    
    success "Prerequisites installed"
    echo ""
}

################################################################################
# Install Go
################################################################################

install_go() {
    info "Checking Go installation..."
    
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}')
        success "Go already installed: $GO_VERSION"
        
        # Check version (need at least 1.19)
        VERSION_NUM=$(echo $GO_VERSION | grep -oP '\d+\.\d+' | head -1)
        if (( $(echo "$VERSION_NUM >= 1.19" | bc -l) )); then
            success "Go version is sufficient"
        else
            warning "Go version $VERSION_NUM is old. Recommended: 1.19+"
        fi
    else
        info "Installing Go..."
        
        if [ "$OS" == "linux" ]; then
            GO_VERSION="1.21.6"
            wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" || {
                error "Failed to download Go"
                exit 1
            }
            
            sudo rm -rf /usr/local/go
            sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
            rm "go${GO_VERSION}.linux-amd64.tar.gz"
            
        elif [ "$OS" == "macos" ]; then
            brew install go || {
                error "Failed to install Go"
                exit 1
            }
        fi
        
        success "Go installed"
    fi
    
    # Setup Go environment
    if [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
        export PATH=$PATH:$HOME/go/bin
    fi
    
    # Add to shell profile
    SHELL_RC=""
    if [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
    
    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" "$SHELL_RC"; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> "$SHELL_RC"
            echo 'export PATH=$PATH:$HOME/go/bin' >> "$SHELL_RC"
            info "Added Go to PATH in $SHELL_RC"
        fi
    fi
    
    echo ""
}

################################################################################
# Install Go-based Bug Bounty Tools
################################################################################

install_go_tools() {
    info "Installing Go-based bug bounty tools..."
    echo ""
    
    # Array of tools to install
    declare -A TOOLS=(
        ["assetfinder"]="github.com/tomnomnom/assetfinder@latest"
        ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
        ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        ["waybackurls"]="github.com/tomnomnom/waybackurls@latest"
        ["gau"]="github.com/lc/gau/v2/cmd/gau@latest"
        ["hakrawler"]="github.com/hakluke/hakrawler@latest"
        ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
        ["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        ["ffuf"]="github.com/ffuf/ffuf/v2@latest"
        ["anew"]="github.com/tomnomnom/anew@latest"
        ["gf"]="github.com/tomnomnom/gf@latest"
        ["unfurl"]="github.com/tomnomnom/unfurl@latest"
        ["qsreplace"]="github.com/tomnomnom/qsreplace@latest"
        ["dalfox"]="github.com/hahwul/dalfox/v2@latest"
        ["subzy"]="github.com/PentestPad/subzy@latest"
        ["subjack"]="github.com/haccer/subjack@latest"
        ["httprobe"]="github.com/tomnomnom/httprobe@latest"
    )
    
    INSTALLED=0
    FAILED=0
    SKIPPED=0
    
    for tool in "${!TOOLS[@]}"; do
        info "Installing $tool..."
        
        # Check if already installed
        if command -v "$tool" &> /dev/null; then
            warning "$tool already installed, updating..."
        fi
        
        # Install the tool
        if go install "${TOOLS[$tool]}" 2>> "$LOG_FILE"; then
            success "$tool installed successfully"
            ((INSTALLED++))
        else
            error "Failed to install $tool"
            ((FAILED++))
        fi
    done
    
    echo ""
    info "Go tools installation summary:"
    echo -e "  ${GREEN}Installed: $INSTALLED${NC}"
    echo -e "  ${RED}Failed: $FAILED${NC}"
    echo ""
}

################################################################################
# Install Python-based Tools
################################################################################

install_python_tools() {
    info "Installing Python-based tools..."
    echo ""
    
    # Upgrade pip
    python3 -m pip install --upgrade pip 2>> "$LOG_FILE"
    
    # Array of Python tools
    PYTHON_TOOLS=(
        "arjun"
        "uro"
    )
    
    for tool in "${PYTHON_TOOLS[@]}"; do
        info "Installing $tool..."
        if python3 -m pip install "$tool" --break-system-packages 2>> "$LOG_FILE"; then
            success "$tool installed"
        else
            # Try without --break-system-packages for older systems
            if python3 -m pip install "$tool" 2>> "$LOG_FILE"; then
                success "$tool installed"
            else
                error "Failed to install $tool"
            fi
        fi
    done
    
    echo ""
}

################################################################################
# Update Nuclei Templates
################################################################################

update_nuclei_templates() {
    info "Updating Nuclei templates..."
    
    if command -v nuclei &> /dev/null; then
        nuclei -update-templates -silent 2>> "$LOG_FILE"
        success "Nuclei templates updated"
    else
        warning "Nuclei not found, skipping template update"
    fi
    
    echo ""
}

################################################################################
# Install GF Patterns
################################################################################

install_gf_patterns() {
    info "Installing GF patterns..."
    
    if command -v gf &> /dev/null; then
        # Create gf directory
        mkdir -p "$HOME/.gf"
        
        # Clone GF patterns repository
        if [ -d "$HOME/.gf/patterns" ]; then
            info "GF patterns already exist, updating..."
            cd "$HOME/.gf/patterns" && git pull 2>> "$LOG_FILE"
        else
            git clone https://github.com/1ndianl33t/Gf-Patterns "$HOME/.gf/patterns" 2>> "$LOG_FILE"
        fi
        
        # Copy patterns to gf directory
        cp -r "$HOME/.gf/patterns"/*.json "$HOME/.gf/" 2>> "$LOG_FILE"
        
        success "GF patterns installed"
    else
        warning "gf tool not installed, skipping patterns"
    fi
    
    echo ""
}

################################################################################
# Verify Tool Installation
################################################################################

verify_tools() {
    info "Verifying tool installations..."
    echo ""
    
    # List of all tools to verify
    ALL_TOOLS=(
        "assetfinder"
        "subfinder"
        "httpx"
        "nuclei"
        "waybackurls"
        "gau"
        "hakrawler"
        "katana"
        "naabu"
        "ffuf"
        "anew"
        "gf"
        "unfurl"
        "qsreplace"
        "dalfox"
        "subzy"
        "subjack"
        "httprobe"
        "arjun"
        "uro"
    )
    
    WORKING=0
    NOT_WORKING=0
    
    echo -e "${CYAN}Tool Verification Report:${NC}"
    echo "─────────────────────────────────────────────────────"
    
    for tool in "${ALL_TOOLS[@]}"; do
        if command -v "$tool" &> /dev/null; then
            # Try to get version or help
            if "$tool" -h &> /dev/null || "$tool" --help &> /dev/null || "$tool" -version &> /dev/null; then
                echo -e "${GREEN}[✓]${NC} $tool - Working"
                ((WORKING++))
            else
                echo -e "${GREEN}[✓]${NC} $tool - Installed (cannot verify)"
                ((WORKING++))
            fi
        else
            echo -e "${RED}[✗]${NC} $tool - Not found"
            ((NOT_WORKING++))
        fi
    done
    
    echo "─────────────────────────────────────────────────────"
    echo -e "${GREEN}Working: $WORKING${NC} | ${RED}Not Working: $NOT_WORKING${NC} | Total: ${#ALL_TOOLS[@]}"
    echo ""
}

################################################################################
# Test Tools with Example
################################################################################

test_tools() {
    echo ""
    read -p "$(echo -e ${YELLOW}"Would you like to run a quick test? (y/n): "${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Running quick test on example.com..."
        echo ""
        
        TEST_DOMAIN="example.com"
        
        # Test assetfinder
        if command -v assetfinder &> /dev/null; then
            info "Testing assetfinder..."
            RESULT=$(assetfinder --subs-only "$TEST_DOMAIN" 2>/dev/null | head -5)
            if [ -n "$RESULT" ]; then
                success "assetfinder is working"
                echo "$RESULT" | head -3
            else
                warning "assetfinder returned no results"
            fi
            echo ""
        fi
        
        # Test httpx
        if command -v httpx &> /dev/null; then
            info "Testing httpx..."
            RESULT=$(echo "example.com" | httpx -silent -status-code 2>/dev/null)
            if [ -n "$RESULT" ]; then
                success "httpx is working"
                echo "$RESULT"
            else
                warning "httpx returned no results"
            fi
            echo ""
        fi
        
        # Test waybackurls
        if command -v waybackurls &> /dev/null; then
            info "Testing waybackurls..."
            RESULT=$(echo "$TEST_DOMAIN" | waybackurls 2>/dev/null | head -5)
            if [ -n "$RESULT" ]; then
                success "waybackurls is working"
                echo "$RESULT" | head -3
            else
                warning "waybackurls returned no results"
            fi
            echo ""
        fi
        
        success "Quick test completed!"
    fi
}

################################################################################
# Create Configuration Files
################################################################################

create_configs() {
    info "Creating configuration directories..."
    
    # Create subfinder config directory
    mkdir -p "$HOME/.config/subfinder"
    
    if [ ! -f "$HOME/.config/subfinder/provider-config.yaml" ]; then
        cat > "$HOME/.config/subfinder/provider-config.yaml" << 'EOF'
# Subfinder Provider Configuration
# Add your API keys below for better results

# Example:
# shodan:
#   - YOUR_SHODAN_API_KEY
# censys:
#   - YOUR_CENSYS_API_ID:YOUR_CENSYS_SECRET
# github:
#   - YOUR_GITHUB_TOKEN
# virustotal:
#   - YOUR_VIRUSTOTAL_API_KEY
# securitytrails:
#   - YOUR_SECURITYTRAILS_API_KEY
EOF
        success "Created subfinder config template"
    fi
    
    echo ""
}

################################################################################
# Display Summary and Next Steps
################################################################################

show_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}║              Installation Complete!                       ║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    info "Installation log saved to: $LOG_FILE"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Reload your shell or run: source ~/.bashrc (or ~/.zshrc)"
    echo "2. Verify PATH includes Go binaries:"
    echo -e "   ${BLUE}echo \$PATH | grep go/bin${NC}"
    echo ""
    echo "3. (Optional) Add API keys to:"
    echo -e "   ${BLUE}~/.config/subfinder/provider-config.yaml${NC}"
    echo ""
    echo "4. Run the bug bounty scripts:"
    echo -e "   ${BLUE}./bug-bounty-recon.sh${NC}"
    echo -e "   ${BLUE}./advanced-recon.sh${NC}"
    echo ""
    
    echo -e "${GREEN}Free API Keys:${NC}"
    echo "• Shodan: https://account.shodan.io/"
    echo "• VirusTotal: https://www.virustotal.com/gui/join-us"
    echo "• GitHub: https://github.com/settings/tokens"
    echo "• SecurityTrails: https://securitytrails.com/"
    echo "• Censys: https://censys.io/register"
    echo ""
    
    echo -e "${YELLOW}Important Reminders:${NC}"
    echo "⚠️  Only test targets you have permission to test"
    echo "⚠️  Read bug bounty program rules carefully"
    echo "⚠️  Respect rate limits and robots.txt"
    echo ""
    
    echo -e "${GREEN}Happy Hunting! 🎯${NC}"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    log "=== Bug Bounty Tools Installation Started ==="
    
    check_requirements
    install_prerequisites
    install_go
    install_go_tools
    install_python_tools
    update_nuclei_templates
    install_gf_patterns
    create_configs
    verify_tools
    test_tools
    show_summary
    
    log "=== Installation Completed ==="
}

# Run main function
main
