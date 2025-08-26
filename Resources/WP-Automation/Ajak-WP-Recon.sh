#!/bin/bash

#========================================#
#   AJAK CYBERACADEMY - WP Recon Tool    #
#   Author: Akash.P                      #
#========================================#

# Banner Function with Gradient
banner() {
    echo
    echo -e "\e[38;5;198m    ___     _   _     _              \e[38;5;199m ____          _                _            "
    echo -e "\e[38;5;198m   / _ \   | | | |   | |            \e[38;5;199m/ ___|   _   _| |__   _   _  __| | ___  _ __ "
    echo -e "\e[38;5;200m  | | | |  | |_| | __| | __ _  __ _ \e[38;5;201m\___ \  | | | | '_ \ | | | |/ _  |/ _ \| '__|"
    echo -e "\e[38;5;200m  | |_| |  |  _  |/ _  |/ _  |/ _  | \e[38;5;201m___) | | |_| | |_) || |_| | (_| | (_) | |   "
    echo -e "\e[38;5;202m   \___/   |_| |_|\__,_|\__, |\__,_| \e[38;5;203m____/   \__,_|_.__/  \__,_|\__,_|\___/|_|   "
    echo -e "\e[38;5;202m                         __/ |                                                   "
    echo -e "\e[38;5;203m                        |___/                                                    "
    echo -e "\e[0m"
    echo -e "\e[1;38;5;207m     🚀 AJAK Cyberacademy | WordPress Recon Tool"
    echo -e "\e[1;38;5;213m     📝 Author: Akash.P"
    echo
}

# Improved WP Version Detection
wp_version_detect() {
    local url="$1"
    url=$(echo "$url" | sed 's:/*$::')

    # Try 1: Meta generator
    version=$(curl -s -L "$url" | grep -oP '(?<=<meta name="generator" content="WordPress )[^"]+')
    if [ -n "$version" ]; then
        echo "WordPress $version (from meta generator tag)"
        return
    fi

    # Try 2: Asset version string
    version=$(curl -s -L "$url" | grep -oP 'ver=[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | sed 's/ver=//')
    if [ -n "$version" ]; then
        echo "WordPress $version (from asset version string)"
        return
    fi

    # Try 3: RSS feed
    version=$(curl -s -L "$url/feed/" | grep -oP '<generator>https?://wordpress.org/\?v=[^<]+' | sed 's/.*v=//')
    if [ -n "$version" ]; then
        echo "WordPress $version (from RSS feed)"
        return
    fi

    # Try 4: readme.html
    version=$(curl -s -L "$url/readme.html" | grep -oP 'Version [0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 | awk '{print $2}')
    if [ -n "$version" ]; then
        echo "WordPress $version (from readme.html)"
        return
    fi

    echo "Could not detect WordPress version."
}

# Grab WP Version Banner
banner_grab() {
    read -p "Enter URL (with http/https): " url
    echo -e "\n[+] Fetching WordPress Version from $url..."
    wp_version_detect "$url"
}

# Detect WordPress on subdomains
wp_detect() {
    read -p "Enter target domain: " target
    echo -e "\n[+] Scanning for WordPress installations..."
    subfinder -d "$target" -silent | \
    xargs -P10 -I{} bash -c 'curl -s -L "http://{}" | grep -qi "wp-content" && echo "[+] WordPress: http://{}"'
}

# Enumerate plugins & versions
wp_plugins() {
    read -p "Enter target domain: " target
    echo -e "\n[+] Enumerating WordPress plugins..."
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

# Enumerate themes & versions
wp_themes() {
    read -p "Enter target domain: " target
    echo -e "\n[+] Enumerating WordPress themes..."
    subfinder -d "$target" -silent | \
    xargs -P10 -I{} bash -c '
    html=$(curl -s -L "http://{}")
    themes=$(echo "$html" | grep -oP "wp-content/themes/[^/]+")
    if [ -n "$themes" ]; then
        while read -r theme; do
            version=$(echo "$html" | grep -oP "$theme[^\" ]*" | grep -oP "ver=[0-9\.]+" | head -n1 | sed "s/ver=//")
            echo "{\"domain\": \"{}\", \"theme\": \"$theme\", \"version\": \"${version:-unknown}\"}"
        done <<< "$themes"
    fi
    ' | jq -s .
}

# Check sensitive WP directories
check_sensitive_dirs() {
    read -p "Enter target URL (with https/http): " TARGET
    TARGET=$(echo "$TARGET" | sed 's:/*$::')
    DIRS=(
        "/wp-admin.php/"
        "/wp-config.php/"
        "/wp-content/uploads/"
        "/wp-load/"
        "/wp-signup.php/"
        "/wp-json/"
        "/wp-includes/"
        "/index.php/"
        "/wp-login.php/"
        "/wp-links-opml.php/"
        "/wp-activate.php/"
        "/wp-blog-header.php/"
        "/wp-cron.php/"
        "/wp-links.php/"
        "/wp-mail.php/"
        "/xmlrpc.php/"
        "/wp-settings.php/"
        "/wp-trackback.php/"
        "/wp-signup.php/"
        "/wp-json/wp/v2/users/"
        "/wp-json/wp/v2/plugins/"
        "/wp-json/wp/v2/themes/"
        "/wp-json/wp/v2/comments/"
    )
    echo -e "\n[+] Checking sensitive directories..."
    RESULTS="["
    for DIR in "${DIRS[@]}"; do
        STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "$TARGET$DIR")
        if [ "$STATUS" == "200" ]; then
            RESULTS+="{\"path\": \"$DIR\", \"status\": 200},"
        fi
    done
    RESULTS=${RESULTS%,}
    RESULTS+="]"
    echo "$RESULTS" | jq .
}

# Run All
run_all() {
    read -p "Enter main URL (for banner & dirs check): " main_url
    read -p "Enter target domain (for subfinder scans): " target_domain

    echo -e "\n========== WP VERSION BANNER =========="
    wp_version_detect "$main_url"

    echo -e "\n========== WP DETECTION =========="
    subfinder -d "$target_domain" -silent | \
    xargs -P10 -I{} bash -c 'curl -s -L "http://{}" | grep -qi "wp-content" && echo "[+] WordPress: http://{}"'

    echo -e "\n========== WP PLUGINS =========="
    wp_plugins <<< "$target_domain"

    echo -e "\n========== WP THEMES =========="
    wp_themes <<< "$target_domain"

    echo -e "\n========== SENSITIVE DIRS =========="
    TARGET=$(echo "$main_url" | sed 's:/*$::')
    DIRS=(
        "/wp-admin.php/"
        "/wp-config.php/"
        "/wp-content/uploads/"
        "/wp-load/"
        "/wp-signup.php/"
        "/wp-json/"
        "/wp-includes/"
        "/index.php/"
        "/wp-login.php/"
        "/wp-links-opml.php/"
        "/wp-activate.php/"
        "/wp-blog-header.php/"
        "/wp-cron.php/"
        "/wp-links.php/"
        "/wp-mail.php/"
        "/xmlrpc.php/"
        "/wp-settings.php/"
        "/wp-trackback.php/"
        "/wp-signup.php/"
        "/wp-json/wp/v2/users/"
        "/wp-json/wp/v2/plugins/"
        "/wp-json/wp/v2/themes/"
        "/wp-json/wp/v2/comments/"
    )
    RESULTS="["
    for DIR in "${DIRS[@]}"; do
        STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "$TARGET$DIR")
        if [ "$STATUS" == "200" ]; then
            RESULTS+="{\"path\": \"$DIR\", \"status\": 200},"
        fi
    done
    RESULTS=${RESULTS%,}
    RESULTS+="]"
    echo "$RESULTS" | jq .
}

# Menu
menu() {
    banner
    echo "1) Grab WP Version Banner"
    echo "2) Detect WordPress on Subdomains"
    echo "3) Enumerate Plugins & Versions"
    echo "4) Enumerate Themes & Versions"
    echo "5) Check Sensitive WP Directories"
    echo "6) Run All Above"
    echo "7) Exit"
    read -p "Select an option: " choice

    case $choice in
        1) banner_grab ;;
        2) wp_detect ;;
        3) wp_plugins ;;
        4) wp_themes ;;
        5) check_sensitive_dirs ;;
        6) run_all ;;
        7) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
}

while true; do
    menu
done
