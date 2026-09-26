#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Irruptiv Software Solutions LLC
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://asternodis.com/

APP="Asternodis"
var_tags="${var_tags:-backup;disaster-recovery}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
# Upstream publishes both amd64 and arm64 builds of the controller binary, verified against
# https://asternodis.com/get/latest/asternodis_linux_arm64
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /usr/local/bin/asternodis ]]; then
    msg_error "No Asternodis Installation Found!"
    exit
  fi

  msg_info "Stopping Asternodis"
  systemctl stop asternodis
  msg_ok "Stopped Asternodis"

  msg_info "Updating Asternodis"
  # Upstream publishes a rolling 'latest' channel rather than per-version download paths, so
  # an update is a re-fetch of latest rather than a move between pinned versions.
  tmp_binary=$(mktemp)
  if ! download_file "https://asternodis.com/get/latest/asternodis_linux_$(get_system_arch uname)" "$tmp_binary"; then
    rm -f "$tmp_binary"
    # Put the existing controller back. One release behind still replicates and still fails
    # over; stopped does neither, and this host may be someone's recovery site.
    systemctl start asternodis
    msg_error "Download failed - the existing installation was left in place and restarted."
    exit
  fi
  install -m 0755 "$tmp_binary" /usr/local/bin/asternodis
  rm -f "$tmp_binary"
  msg_ok "Updated Asternodis"

  msg_info "Starting Asternodis"
  systemctl start asternodis
  msg_ok "Started Asternodis"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}https://${IP}${CL}"
echo -e "${INFO}${YW}The certificate is self-signed on first run, so expect a browser warning.${CL}"
echo -e "${INFO}${YW}This installs ONE controller. Disaster recovery needs a second one at your recovery site - run this script there too, then pair them.${CL}"
