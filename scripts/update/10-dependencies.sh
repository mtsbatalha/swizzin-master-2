#!/bin/bash
# Ensures that dependencies are installed and corrects them if that is not the case.

if ! which add-apt-repository > /dev/null; then
    echo_info "Repository management tools not found; attempting to install software-properties-common"
    # Ensure apt cache is updated before checking/installing software-properties-common
    apt_update
    # Check if software-properties-common is available in the cache
    if apt-cache show software-properties-common > /dev/null 2>&1; then
        apt_install software-properties-common
    else
        echo_warn "Package 'software-properties-common' not found in repositories; skipping (may not be available on this distribution)"
        # For Debian/minimal systems, add-apt-repository may still work via apt-add-repository
    fi
fi

if [[ $(_os_distro) == "ubuntu" ]]; then
    if [[ $(_os_codename) == "jammy" ]]; then
        if ! grep -s 'ubuntu-toolchain-r' /etc/apt/sources.list.d/ubuntu-toolchain-r-ubuntu-ppa-jammy.list 2> /dev/null | grep -q -v '^#'; then
            echo_info "Adding toolchain repo"
            add-apt-repository -y ppa:ubuntu-toolchain-r/ppa >> ${log} 2>&1
            trigger_apt_update=true
        fi
    fi
    listFile="/etc/apt/sources.list.d/ubuntu.sources"
    if [[ -f ${listFile} ]]; then
        components=(universe multiverse restricted)
        tmpFile=$(mktemp)
        cp "$listFile" "$tmpFile"
        for component in "${components[@]}"; do
            sed -i "/^Components:/ {
                /$component/! s/$/ $component/
            }" "$tmpFile"
        done

        if ! cmp -s "$listFile" "$tmpFile"; then
            trigger_apt_update=true
            mv "$tmpFile" "$listFile"
        else
            rm "$tmpFile"
        fi
    else
        if ! grep 'universe' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling universe repo"
            add-apt-repository -y universe >> ${log} 2>&1
            trigger_apt_update=true
        fi
        if ! grep 'multiverse' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling multiverse repo"
            add-apt-repository -y multiverse >> ${log} 2>&1
            trigger_apt_update=true
        fi
        if ! grep 'restricted' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling restricted repo"
            add-apt-repository -y restricted >> ${log} 2>&1
            trigger_apt_update=true
        fi
    fi
elif [[ $(_os_distro) == "debian" ]]; then
    listFile="/etc/apt/sources.list.d/debian.sources"
    if [[ -f ${listFile} ]]; then
        components=(contrib non-free)
        tmpFile=$(mktemp)
        cp "$listFile" "$tmpFile"
        for component in "${components[@]}"; do
            sed -i "/^Components:/ {
            /$component/! s/$/ $component/
        }" "$tmpFile"
        done

        if ! cmp -s "$listFile" "$tmpFile"; then
            trigger_apt_update=true
            mv "$tmpFile" "$listFile"
        else
            rm "$tmpFile"
        fi
    else
        if ! grep contrib /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling contrib repo"
            # Try apt-add-repository first, fallback to direct sed editing
            if which apt-add-repository > /dev/null 2>&1; then
                apt-add-repository -y contrib >> ${log} 2>&1
            else
                echo_warn "apt-add-repository not found; using sed to edit sources.list directly"
                sed -i 's/^deb \(.*\)$/deb \1 contrib/' /etc/apt/sources.list
            fi
            trigger_apt_update=true
        fi
        if ! grep -P '\bnon-free(\s|$)' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling non-free repo"
            # Try apt-add-repository first, fallback to direct sed editing
            if which apt-add-repository > /dev/null 2>&1; then
                apt-add-repository -y non-free >> ${log} 2>&1
            else
                echo_warn "apt-add-repository not found; using sed to edit sources.list directly"
                sed -i 's/^deb \(.*\)$/deb \1 non-free/' /etc/apt/sources.list
            fi
            trigger_apt_update=true
        fi
    fi
fi
if [[ $trigger_apt_update == "true" ]]; then
    apt_update
fi

#space-separated list of required GLOBAL SWIZZIN dependencies (NOT application specific ones)
dependencies="whiptail git sudo curl wget lsof rsyslog fail2ban apache2-utils vnstat tcl tcl-dev build-essential dirmngr apt-transport-https bc uuid-runtime jq net-tools gnupg2 cracklib-runtime unzip ccze cron"

apt_install "${dependencies[@]}"

. /etc/swizzin/sources/functions/gcc
GCC_Jammy_Upgrade
