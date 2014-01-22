#!/bin/sh -u

# --- vars ---
readonly SCRIPT_FILENAME="${0##*/}"
readonly SCRIPT_NAME="${SCRIPT_FILENAME%.*}"
#readonly SCRIPT_MODE="${SCRIPT_NAME#*[-_]}"
readonly X_SUDO="/usr/bin/sudo -n"
if [ "$(id -u 2>/dev/null)x" = "0x" ]; then
   readonly X_SUDO_ROOT=
else
   readonly X_SUDO_ROOT="${X_SUDO} -u root --"
fi

# if you want to send desktop notifications, make sure that $DISPLAY is set
#
#  see ./xnotify.sh for a more advanced example
#
: ${DISPLAY:=:0.0}
export DISPLAY

## --- helper functions ---

dolog() {
   logger -t batwatch -p ${2:-debug} "${SCRIPT_NAME}: ${1}"
}

die() {
   1>&2 printf "died: %s\n" "${1:-unknown error}"
   dolog "${1:-unknown error}" "${3:-err}"
   exit ${2:-2}
}

is_systemd_booted() {
   [ -d /run/systemd/system ]
}

have_fallback_battery() {
   [ -n "${FALLBACK_BATTERY_STATE-}" ]
}

have_ac_power() {
   [ "${ON_AC_POWER:-X}" = "1" ]
}

abort_if_fallback_battery() {
   if have_fallback_battery; then
      dolog "${1-}${1:+ }inhibited by fallback battery ${FALLBACK_BATTERY:-X}"
      exit ${2:-0}
   fi
}

abort_if_on_ac_power() {
   if have_ac_power; then
      dolog "${1-}${1:+ }inhibited by AC power"
      exit ${2:-0}
   fi
}

abort_if_any_fallback() {
   abort_if_on_ac_power "$@"
   abort_if_fallback_battery "$@"
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

## -- main --

dolog "started" debug

[ -n "${BATTERY-}" [ || die "no battery given." 64

# variables:
#BATTERY                    -- name of the discharging battery
#BATTERY_SYSFS              -- its sysfs path
#BATTERY_PERCENT            -- its remaining energy as percentage
#BATTERY_TIME               -- its remaining running time
#FALLBACK_BATTERY           -- name of the fallback battery (if any, else "")
#FALLBACK_BATTERY_SYSFS     -- ^-> sysfs path
#FALLBACK_BATTERY_PERCENT   -- ^-> remaining energy as percentage
#FALLBACK_BATTERY_TIME      -- ^-> time until fully charged
#                                  (only meaningful if > 0)
#FALLBACK_BATTERY_STATE     -- ^-> "charging", "fully-charged", ...
#ON_AC_POWER                -- 1 if on ac power, else 0
