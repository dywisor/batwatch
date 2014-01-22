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

unset -v DISPLAY

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


# --- X helper functions, from shlib ---

# void x11__run_and_filter_who ( repl_expr )
#
x11__run_and_filter_who() {
   who | sed -nr -e "s,^(\S+)\s+([:][0-9.]+)\s+.*$,${1},p" | sort -u
}

# void print_x_users()
print_x_users()              { x11__run_and_filter_who '\1'; }
# void print_x_displays()
print_x_displays()           { x11__run_and_filter_who '\2'; }
# void print_x_users_and_displays()
print_x_users_and_displays() { x11__run_and_filter_who '\1 \2'; }

# int x11__run_command_on_display (
#    target_user, display, *cmdv, (DISPLAY=%display)
# )
#
x11__run_command_on_display() {
   local user="${1:?}"
   local display="${2:?}"
   shift 2 || return 64

   DISPLAY="${display}" "$@"
}

# int x11__sudo_run_command_as (
#    target_user, display, *cmdv, **X_SUDO="sudo", (DISPLAY=%display)
# )
#
x11__sudo_run_command_as() {
   local user="${1:?}"
   local display="${2:?}"
   shift 2 || return 64

   if [ -n "${USER-}" ] && [ "${user}" = "${USER}" ]; then
      DISPLAY="${display}" "$@"
   else
      ${X_SUDO} -u "${user}" DISPLAY="${display}" -- "$@"
   fi
}

run_as_x_user() {
   local __runas_func="${F_RUN_AS_X_USER:-x11__sudo_run_command_as}"
   local target_user
   local user
   local item

   case "${1-}" in
      '--target-user'|'-u')
         target_user="${2:?}"
         shift 2 || return 64
      ;;
      '-a'|'--all')
         target_user="@all"
         shift || return 64
      ;;
      '--')
         shift || return 64
      ;;
   esac

   for item in $(print_x_users_and_displays); do
      if [ -z "${item}" ]; then
         true
      elif [ -z "${user}" ]; then
         user="${item}"
      else
         case "${target_user}" in
            '')
               ${__runas_func:?} "${user}" "${item}" "$@"
               return ${?}
            ;;
            '@all')
               ${__runas_func:?} "${user}" "${item}" "$@"
            ;;
            "${user}")
               ${__runas_func:?} "${user}" "${item}" "$@"
            ;;
         esac

         user=
      fi
   done
}

# int xnotify_all (
#    *argv,
#    **X_NOTIFY="notify-send"
#    **F_RUN_AS_X_USER="x11__run_command_on_display"
# )
#
xnotify_all() {
   local F_RUN_AS_X_USER="${F_RUN_AS_X_USER:-x11__run_command_on_display}"
   run_as_x_user -a "${X_NOTIFY:-notify-send}" "$@"
}

# int xnotify_user (
#    user, *argv,
#    **X_NOTIFY="notify-send",
#    **F_RUN_AS_X_USER="x11__run_command_on_display"
#
xnotify_user() {
   local F_RUN_AS_X_USER="${F_RUN_AS_X_USER:-x11__run_command_on_display}"
   local target_user="${1:?}"
   shift || return 64
   run_as_x_user -u "${target_user}" "${X_NOTIFY:-notify-send}" "$@"
}


## -- main --


dolog "started" debug

##[ -n "${BATTERY-}" [ || die "no battery given." 64

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

body=
body="${body}remaining energy : ${BATTERY_PERCENT:-??}%\n"
body="${body}remaining running time : ${BATTERY_TIME:-??} minutes\n"
body="${body}AC power: $(have_ac_power && echo yes || echo no)\n"

if have_fallback_battery; then
   body="${body}\nfallback battery: ${FALLBACK_BATTERY} (${FALLBACK_BATTERY_PERCENT}%)\n"
fi

xnotify_all -c batwatch -t 15000 "battery status ${BATTERY:-?BAT?}" "${body}"
