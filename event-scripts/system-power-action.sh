#!/bin/sh -u
readonly SCRIPT_FILENAME="${0##*/}"
readonly SCRIPT_NAME="${SCRIPT_FILENAME%.*}"
readonly SCRIPT_MODE="${SCRIPT_NAME#*system[-_]}"
readonly X_SUDO="/usr/bin/sudo -n"
if [ "$(id -u 2>/dev/null)x" = "0x" ]; then
   readonly X_SUDO_ROOT=
else
   readonly X_SUDO_ROOT="${X_SUDO} -u root --"
fi
readonly X_SYSTEMCTL="systemctl"
readonly X_PM_PREFIX="/usr/sbin/pm-"

dolog() {
   logger -t batwatch -p ${2:-debug} "${SCRIPT_NAME}: ${1}"
}

die() {
   1>&2 printf "died: %s\n" "${1:-unknown error}"
   dolog "${1:-unknown error}" "${3:-err}"
   exit ${2:-2}
}

is_systemd_booted() { [ -d /run/systemd/system ]; }

have_fallback_battery() {
   [ -n "${FALLBACK_BATTERY_STATE-}" ]
}

abort_if_fallback_battery() {
   if have_fallback_battery; then
      dolog "${1-}${1:+ }inhibited by fallback battery ${FALLBACK_BATTERY:-X}"
      exit ${2:-0}
   fi
}

abort_if_on_ac_power() {
   if [ "${ON_AC_POWER}" = "1" ]; then
      dolog "${1-}${1:+ }inhibited by AC power"
      exit ${2:-0}
   fi
}

abort_if_any_fallback_power() {
   abort_if_on_ac_power
   abort_if_fallback_battery
}

# run_command_logged ( action_description, *cmdv )
run_command_logged() {
   : ${1?} ${2:?}
   local desc="${1}"; shift;
   local rc
   dolog "about to ${desc}" info
   if "$@"; then
      dolog "${desc} succeeded." debug
      return 0
   else
      rc=${?}
      dolog "${desc} failed (rc=${rc})." err
      return ${rc}
   fi
}

run_systemctl_command() {
   : ${1:?}
   run_command_logged "${1}(systemd)" ${X_SUDO-} ${X_SYSTEMCTL:?} "$@"
}

run_pm_command() {
   : ${1:?}
   run_command_logged "${1}(pm-${2:-${1}})" ${X_SUDO-} ${X_PM_PREFIX:?}"${2:-${1}}"
}

# run_power_command ( desc, pm_util_name:=desc, systemctl_name:=desc )
run_power_command() {
   : ${1:?}
   if is_systemd_booted; then
      run_systemctl_command "${1}" "${3:-${1}}"
   else
      run_pm_command "${1}" "${2:-${1}}"
   fi
}




dolog "started" debug

[ -n "${BATTERY-}" ] || die "no battery given." 64


case "${SCRIPT_MODE}" in
   'suspend')
      abort_if_any_fallback_power suspend
      run_power_command suspend
   ;;
   'suspend-hybrid'|'hybrid-sleep')
      abort_if_any_fallback_power suspend-hybrid
      run_power_command suspend-hybrid "" hybrid-sleep
   ;;
   'hibernate')
      abort_if_any_fallback_power hibernate
      run_power_command hibernate
   ;;
   'power-action')
      die "This script needs to be (sym-)linked." 4
   ;;
   'poweroff'|'halt')
      abort_if_any_fallback_power poweroff
      if is_systemd_booted; then
         run_systemctl_command poweroff
      else
         run_command_logged poweroff ${X_SUDO-} shutdown -h now
      fi
   ;;
   'reboot')
      # reboot on low battery doesn't make much sense
      abort_if_any_fallback_power reboot
      if is_systemd_booted; then
         run_systemctl_command reboot
      else
         run_command_logged reboot ${X_SUDO-} reboot
      fi
   ;;
   *)
      die "unknown script mode '${SCRIPT_MODE}'" 3
   ;;
esac
