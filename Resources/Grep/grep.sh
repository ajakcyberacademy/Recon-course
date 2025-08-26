#!/bin/bash

echo "Created By AJAK Cyber Academy 🔐"
read -p "Enter path to URL wordlist file: " url_file

if [[ ! -f "$url_file" ]]; then
    echo "❌ File does not exist. Exiting."
    exit 1
fi

output_dir="grep_results_$(date +%s)"
mkdir "$output_dir"
echo "[+] Results will be saved in $output_dir"

# ---------- Sensitive Keywords ----------
grep -Ei 'apikey|api_key|secret|token|access_token|auth|authentication|authorization|password|passwd|pwd|admin|user|username|login|signin|email|session|cookie|jwt|bearer|key|credentials|client_id|client_secret|private_key|public_key|aws_secret|aws_access|s3|bucket|gcp|azure|gitlab|github|git_token|slack_token|webhook|webhook_url|db|database|db_user|db_pass|mysql|pgsql|sql|query|dump|backup|config|configuration|\.env|env|environment|vault|secrets|ssh|rsa|pem|cert|certificate|ftp|smtp|imap|hostname|host|ip|port|netloc|route|router|endpoint|callback|redirect|url|base_url|origin|firebase|firebaseio|twilio|nexmo|plivo|sendgrid|stripe|paypal|payment|billing|invoice|adminpanel|dashboard|console|superuser|root|debug|debugger|stacktrace|traceback|exception|error_log|logs|logfile|shell|cmd|exec|eval' "$url_file" > "$output_dir/sensitive_keywords.txt"

# ---------- SSRF Parameters ----------
grep -Ei 'url=|uri=|path=|target=|dest=|domain=|destination=|redirect=|redir=|return=|image=|continue=|data=|callback=|returnUrl=' "$url_file" > "$output_dir/ssrf_params.txt"

# Filter http and https separately
grep -E "^http://" "$url_file" > "$output_dir/http_urls.txt"
grep -E "^https://" "$url_file" > "$output_dir/https_urls.txt"

# ---------- XSS Parameters ----------
grep -Ei 'q=|query=|search=|s=|keyword=|message=|comment=|feedback=|input=|redirect=|page=|url=|next=|return=|text=' "$url_file" > "$output_dir/xss_params.txt"

# ---------- RCE Parameters ----------
grep -Ei 'cmd=|exec=|execute=|run=|process=|shell=|terminal=|ping=|call=|path=|load=|module=|read=|write=|binary=' "$url_file" > "$output_dir/rce_params.txt"

# ---------- Existing Common Recon ----------
grep -Eo 'https?://[^ ]+\.(env|yaml|yml|json|xml|log|sql|ini|bak|conf|config|db|dbf|tar|gz|backup|swp|old|key|pem|crt|pfx|pdf|xlsx|xls|ppt|pptx)' "$url_file" > "$output_dir/extension_leaks.txt"
grep -Ei 'id=|page=|dir=|search=|category=|file=|class=|url=|news=|item=|menu=|lang=|name=|ref=|title=|view=|topic=|thread=|type=|date=|form=|join=|main=|nav=|region=' "$url_file" > "$output_dir/sqli_candidates.txt"
grep -Ei 'next=|url=|target=|rurl=|dest=|destination=|redir=|redirect_uri=|redirect_url=|redirect=|redirect/|cgi-bin/redirect.cgi|out/|out\?|view=|login=to|image_url=|go=|return=|returnTo=|return_to=|checkout_url=|continue=|return_path=' "$url_file" > "$output_dir/open_redirects.txt"

grep '=' "$url_file" > "$output_dir/params.txt"
grep -Ei '\?.+=|&.+=|=' "$url_file" | sort -u > "$output_dir/param_endpoints_for_fuzz.txt"
grep "\.js$" "$url_file" > "$output_dir/javascript_files.txt"
grep -Eo 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' "$url_file" > "$output_dir/jwt_tokens.txt"
grep -Eoi '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,}' "$url_file" > "$output_dir/emails.txt"
grep -Eo '[A-Za-z0-9+/]{20,}={0,2}' "$url_file" > "$output_dir/base64.txt"
grep -Ei 'debug|trace|verbose|test=1|dev=1' "$url_file" > "$output_dir/debug.txt"
grep -Ei 'upload|file=|image=|media=' "$url_file" > "$output_dir/upload.txt"
grep -Ei '/\.git|/\.svn|/\.htaccess|/\.DS_Store' "$url_file" > "$output_dir/git_exposed.txt"
grep -Ei 'stripe|paypal|payu|checkout|billing|invoice' "$url_file" > "$output_dir/payment.txt"
grep -Ei 'role=|privilege=|=admin' "$url_file" > "$output_dir/privilege.txt"

grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$url_file" > "$output_dir/ipv4.txt"
grep -Eo '((10|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168)\.[0-9]{1,3}\.[0-9]{1,3})' "$url_file" > "$output_dir/private_ips.txt"
grep -Eo '([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}' "$url_file" > "$output_dir/ipv6.txt"

