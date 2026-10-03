#!/bin/bash
# BusyBox-compatible adduser/addgroup/deluser/delgroup for Debian.
#
# MikoPBX Core calls these with BusyBox syntax, and on every boot it deletes
# every account except root, www and the SSH login. On the official firmware
# those are the only accounts; on Debian that would also remove the system
# accounts packages rely on, so only regular accounts (ID 1000-59999 in Debian
# policy) are deleted.
set -eu

isSystemUser() {
  local uid
  uid="$(id -u "$1" 2>/dev/null)" || return 1
  ((uid < 1000 || uid >= 60000))
}

isSystemGroup() {
  local gid
  gid="$(getent group "$1" | cut -d: -f3)"
  [[ -n $gid ]] && ((gid < 1000 || gid >= 60000))
}

cmd_adduser() {
  local home='' gecos='' shell='/bin/sh' group='' uid='' system='' createHome='-m'
  local OPTIND opt
  while getopts 'h:g:s:G:u:k:SDH' opt; do
    case "$opt" in
    h) home="$OPTARG" ;;
    g) gecos="$OPTARG" ;;
    s) shell="$OPTARG" ;;
    G) group="$OPTARG" ;;
    u) uid="$OPTARG" ;;
    S) system='-r' ;;
    H) createHome='-M' ;;
    k | D) ;;
    *) return 1 ;;
    esac
  done
  shift $((OPTIND - 1))
  local user="$1"
  [[ -n $home ]] || home="/home/$user"
  local args=("$createHome" -d "$home" -s "$shell" -c "$gecos")
  [[ -n $system ]] && args+=("$system")
  [[ -n $uid ]] && args+=(-u "$uid")
  if [[ -n $group ]]; then
    args+=(-g "$group")
  elif getent group "$user" >/dev/null; then
    args+=(-g "$user")
  else
    args+=(-U)
  fi
  useradd "${args[@]}" "$user"
  if [[ $# -ge 2 ]]; then
    usermod -aG "$2" "$user"
  fi
}

cmd_addgroup() {
  local gid='' system=''
  local OPTIND opt
  while getopts 'g:S' opt; do
    case "$opt" in
    g) gid="$OPTARG" ;;
    S) system='-r' ;;
    *) return 1 ;;
    esac
  done
  shift $((OPTIND - 1))
  if [[ $# -ge 2 ]]; then
    # addgroup USER GROUP: add an existing user to an existing group.
    usermod -aG "$2" "$1"
    return
  fi
  local args=()
  [[ -n $system ]] && args+=("$system")
  [[ -n $gid ]] && args+=(-g "$gid")
  groupadd "${args[@]}" "$1"
}

cmd_deluser() {
  if [[ ${1:-} == --remove-home ]]; then
    shift
  fi
  if [[ $# -ge 2 ]]; then
    gpasswd -d "$1" "$2" >/dev/null
    return
  fi
  if isSystemUser "$1"; then
    return 0
  fi
  userdel "$1"
}

cmd_delgroup() {
  if [[ $# -ge 2 ]]; then
    gpasswd -d "$1" "$2" >/dev/null
    return
  fi
  if isSystemGroup "$1"; then
    return 0
  fi
  groupdel "$1"
}

"cmd_$(basename "$0")" "$@"
