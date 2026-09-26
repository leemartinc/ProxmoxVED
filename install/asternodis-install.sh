#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Irruptiv Software Solutions LLC
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://asternodis.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
# The controller reaches Proxmox nodes over SSH for the storage-side work that has no API
# equivalent, so the client is a hard requirement rather than a convenience.
$STD apt install -y openssh-client
msg_ok "Installed Dependencies"

msg_info "Installing Asternodis"
# Asternodis ships as a single static binary from the vendor, not as a GitHub release or an
# APT repository, so this uses download_file rather than fetch_and_deploy_gh_release or
# fetch_and_deploy_from_url - the latter auto-detects an ARCHIVE type via file(1) and a bare
# ELF binary is not one.
tmp_binary=$(mktemp)
download_file "https://asternodis.com/get/latest/asternodis_linux_$(get_system_arch uname)" "$tmp_binary"
install -m 0755 "$tmp_binary" /usr/local/bin/asternodis
rm -f "$tmp_binary"
# 0700: this directory holds the controller's database, its encryption key and its peer
# identity. Anything able to read it can impersonate this site to the site it is paired with.
install -d -m 0700 /var/lib/asternodis
msg_ok "Installed Asternodis"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/asternodis.service
[Unit]
Description=Asternodis - Disaster Recovery for Proxmox VE
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/asternodis serve --data-dir /var/lib/asternodis --listen :443
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now asternodis
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt -y autoremove
$STD apt -y autoclean
msg_ok "Cleaned"

cleanup_lxc
