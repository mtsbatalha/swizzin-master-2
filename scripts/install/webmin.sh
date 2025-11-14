#! /bin/bash
# shellcheck disable=SC2024
# Webmin installer
# flying_sausages for swizzin 2020

_install_webmin() {
    echo_progress_start "Installing Webmin repo"
    # Preferred method: use signed-by keyring
    echo "deb [signed-by=/usr/share/keyrings/webmin-archive-keyring.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list

    # Try to fetch and dearmor the Webmin GPG key
    if which gpg > /dev/null 2>&1; then
        if curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor > /usr/share/keyrings/webmin-archive-keyring.gpg 2>> "${log}"; then
            echo_log_only "Webmin GPG key downloaded and stored"
        else
            echo_warn "Failed to dearmor Webmin key with gpg; will try apt-key fallback"
            rm -f /usr/share/keyrings/webmin-archive-keyring.gpg 2>/dev/null || true
            # fall through to apt-key fallback below
        fi
    else
        echo_warn "gpg not available; will try apt-key fallback for Webmin key"
    fi

    # If keyring is missing or empty, fallback to apt-key (older systems)
    if [[ ! -s /usr/share/keyrings/webmin-archive-keyring.gpg ]]; then
        echo_info "Using apt-key fallback to add Webmin repository key"
        if curl -fsSL https://download.webmin.com/jcameron-key.asc | apt-key add - >> "${log}" 2>&1; then
            echo_log_only "Webmin GPG key added via apt-key"
            # For older apt versions that do not support 'signed-by', rewrite sources.list without signed-by
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
        else
            echo_error "Failed to add Webmin GPG key via apt-key"
        fi
    fi

    echo_progress_done "Repo added"
    # Run apt update and capture output to detect unsigned repo / missing key errors
    apt_update_output=$(mktemp)
    if ! apt_update 2>&1 | tee "$apt_update_output"; then
        echo_warn "apt update returned non-zero status; checking for webmin-specific errors"
    fi
    if grep -Ei "not signed|no_pubkey|NO_PUBKEY|The repository.*is not signed" "$apt_update_output" >/dev/null 2>&1; then
        echo_warn "Webmin repository update failed due to missing/invalid GPG key or unsigned Release. Attempting insecure 'trusted=yes' fallback."
        # Overwrite the source entry to bypass signature checks (insecure)
        echo "deb [trusted=yes] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
        # Retry update and install
        if ! apt_update 2>&1 | tee "$apt_update_output"; then
            echo_warn "apt update still failing after trusted fallback; aborting Webmin install"
        fi
        if apt_install webmin; then
            echo_warn "Webmin installed using trusted=yes (signature verification bypassed)."
            rm -f "$apt_update_output"
        else
            echo_error "Trusted fallback failed; removing repo and key"
            rm -f /etc/apt/sources.list.d/webmin.list
            rm -f /usr/share/keyrings/webmin-archive-keyring.gpg
            rm -f "$apt_update_output"
            return 1
        fi
    else
        rm -f "$apt_update_output"
        apt_install webmin || echo_warn "webmin package installation failed; check apt logs"
    fi
}

_install_webmin
if [[ -f /install/.nginx.lock ]]; then
    echo_progress_start "Configuring nginx"
    bash /etc/swizzin/scripts/nginx/webmin.sh
    systemctl reload nginx
    echo_progress_done
else
    echo_info "Webmin will run on port 10000"
fi

echo_success "Webmin installed"
echo_info "Please use any account with sudo permissions to log in"

touch /install/.webmin.lock
