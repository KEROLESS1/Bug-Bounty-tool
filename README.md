# Bug Bounty Automation Scripts

A comprehensive collection of automation scripts for bug bounty reconnaissance and vulnerability discovery.

## 📁 Files Included

### Installation & Verification Scripts

1. **install-tools.sh** - ⭐ **AUTOMATED INSTALLATION** ⭐
   - One-click installation of ALL bug bounty tools
   - Checks system requirements
   - Installs Go and Python tools
   - Updates Nuclei templates
   - Installs GF patterns
   - Verifies all installations
   - Runs test to confirm tools work

2. **check-tools.sh** - Tool health checker
   - Quickly verify all tools are installed
   - Shows which tools are working
   - Provides installation recommendations
   - Checks PATH configuration

### Main Reconnaissance Scripts

3. **bug-bounty-recon.sh** - Basic reconnaissance script
   - Subdomain enumeration (assetfinder, subfinder)
   - Live host detection (httpx)
   - URL discovery (waybackurls, gau)
   - URL filtering and categorization
   - Optional nuclei vulnerability scanning

4. **advanced-recon.sh** - Advanced reconnaissance with more features
   - Everything from basic script plus:
   - Port scanning (naabu)
   - JavaScript analysis for secrets
   - Subdomain takeover detection
   - Technology fingerprinting
   - Enhanced reporting

### Documentation

5. **INSTALLATION.md** - Manual installation guide
   - Step-by-step tool installation
   - API key configuration
   - Troubleshooting tips

6. **CHEATSHEET.md** - Quick reference guide
   - Common commands for all major tools
   - One-liners for quick tasks
   - Pro tips and best practices

7. **targets.txt** - Sample target file
   - Add your authorized targets here

## 🚀 Quick Start

### Method 1: Automated Installation (Recommended ⭐)

```bash
# 1. Make the installation script executable
chmod +x install-tools.sh

# 2. Run the automated installer
./install-tools.sh

# This will:
# - Check system requirements
# - Install Go (if needed)
# - Install ALL bug bounty tools
# - Verify installations
# - Run tests to confirm tools work
# - Setup configurations

# 3. Reload your shell
source ~/.bashrc  # or source ~/.zshrc for zsh

# 4. Verify tools are working
./check-tools.sh

# 5. Add your targets
echo "yourtarget.com" > targets.txt

# 6. Run reconnaissance
./bug-bounty-recon.sh
```

### Method 2: Manual Installation

```bash
# 1. Install Go (if not already installed)
# Ubuntu/Debian:
sudo apt install golang-go

# macOS:
brew install go

# 2. Install bug bounty tools manually
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# 3. Make sure Go bin is in PATH
export PATH=$PATH:$HOME/go/bin

# 4. Check if tools are working
./check-tools.sh
```

### Quick Tool Check

```bash
# At any time, verify your tools with:
./check-tools.sh

# This shows:
# ✓ Which tools are installed and working
# ✗ Which tools are missing
# → Recommendations for fixing issues
```

## 📊 What the Scripts Do

### Phase 1: Subdomain Enumeration
- Discovers subdomains using multiple passive sources
- Combines results for comprehensive coverage

### Phase 2: Live Host Detection
- Tests which subdomains are actually live
- Detects web servers, technologies, and CDNs

### Phase 3: URL Discovery
- Pulls historical URLs from Wayback Machine
- Fetches URLs from Common Crawl (GAU)
- Crawls live sites for additional endpoints

### Phase 4: URL Filtering
- Categorizes URLs by type:
  - URLs with parameters (potential injection points)
  - JavaScript files
  - API endpoints
  - Authentication pages
  - File upload endpoints
  - Admin panels

### Phase 5: Vulnerability Scanning (Optional)
- Runs nuclei templates for known vulnerabilities
- Focuses on critical, high, and medium severity issues

## 📂 Output Structure

```
output/
├── subdomains/
│   ├── assetfinder.txt
│   ├── subfinder.txt
│   └── all-subdomains.txt
├── live/
│   ├── live-hosts.txt
│   └── live-urls.txt
├── urls/
│   ├── wayback-urls.txt
│   ├── gau-urls.txt
│   ├── all-urls.txt
│   ├── urls-with-params.txt
│   ├── js-files.txt
│   ├── api-endpoints.txt
│   ├── auth.txt
│   ├── uploads.txt
│   └── admin.txt
└── vulns/
    └── nuclei-results.txt
```

## 🔧 Key Issues Fixed from Original Script

1. **Syntax Errors**
   - Fixed `TARGETS ="targets.txt"` → `TARGETS="targets.txt"` (removed space)
   - Fixed `cat  subdomains1.txt` → proper spacing
   - Fixed variable references

2. **Logic Issues**
   - Added proper file existence checks
   - Fixed tool availability checks
   - Corrected httpx command (was `httpx-toolkit`)

3. **Improvements Added**
   - Color-coded output for better readability
   - Progress indicators
   - Error handling
   - Comprehensive URL filtering
   - Organized output directory structure
   - Summary statistics

## ⚠️ Important Notes

### Legal Disclaimer
**CRITICAL**: Only test targets you have explicit permission to test. Unauthorized testing is illegal and unethical.

### Best Practices
1. Always get written authorization before testing
2. Read the bug bounty program's scope and rules
3. Respect rate limits to avoid DoS
4. Don't test in production during business hours
5. Report findings responsibly

### Rate Limiting
The scripts include rate limiting to avoid overwhelming targets:
- Default: 150 requests/second
- Adjust `RATE_LIMIT` variable if needed
- Use VPS for heavy scanning

### API Keys (Recommended)
Many tools work better with API keys. See INSTALLATION.md for details on:
- Shodan
- VirusTotal
- SecurityTrails
- Censys
- GitHub

## 🎯 Bug Bounty Platforms

- **HackerOne**: https://www.hackerone.com/
- **Bugcrowd**: https://www.bugcrowd.com/
- **Intigriti**: https://www.intigriti.com/
- **YesWeHack**: https://www.yeswehack.com/
- **Open Bug Bounty**: https://www.openbugbounty.org/

## 📚 Learning Resources

- **PortSwigger Academy**: https://portswigger.net/web-security (Free!)
- **OWASP Testing Guide**: https://owasp.org/www-project-web-security-testing-guide/
- **HackerOne Hacktivity**: https://hackerone.com/hacktivity
- **Bug Bounty Forum**: https://bugbountyforum.com/

## 🤝 Contributing

Feel free to:
- Add more tools and techniques
- Improve error handling
- Add new filtering categories
- Share your modifications

## 📝 License

Use responsibly and ethically. For educational and authorized testing only.

## 🐛 Troubleshooting

### Tools not found
```bash
# Ensure Go bin is in PATH
export PATH=$PATH:$HOME/go/bin
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
```

### Permission denied
```bash
chmod +x *.sh
```

### Slow performance
- Use a VPS with better bandwidth
- Reduce THREADS value
- Increase TIMEOUT value

### No results
- Check internet connection
- Verify targets.txt has valid domains
- Some targets may have strong security

## 💡 Next Steps

1. Read INSTALLATION.md for detailed setup
2. Review CHEATSHEET.md for command reference
3. Add your targets to targets.txt
4. Run the scripts
5. Manually verify interesting findings
6. Report vulnerabilities responsibly

Happy hunting! 🎯
