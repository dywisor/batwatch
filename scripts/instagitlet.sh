#!/bin/sh
# -*- coding: utf-8 -*-
#
# This file has been autogenerated by the shlib compiler
# version 0.0.13 on 2014-01-13 13:51:16 (CET)
#
# ------------------------ shlib info ------------------------
#
# shlib - shell function library
#
# Copyright (C) 2012-2014 Andre Erdmann <dywi@mailerd.de>
# Distributed under the terms of the GNU General Public
# License; either version 2 of the License, or (at your
# option) any later version.
#
# Note: This is the "catch-all" license, certain modules may
# have their own (e.g. written by someone else).
#
# ---------------------- end shlib info ----------------------
#
set -u
##### begin section header #####

### module __main__

#
# insta git applet - downloads, builds and runs batwatch
#
#  Also performs basic dependency checks.
#
#
# Usage: <instagitlet> [<applet option>...] [--] <batwatch args>...
#
# Applet options:
#
#  -c, --no-color   --
#  -h, --help       --
#  -n, --dry-run    -- show what whould be done
#  --no-src,
#  --offline        -- don't update/clone the git repo
#  --no-deps        -- don't check for build dependencies
#  --no-compile     -- don't build batwatch
#  --no-run         -- don't run batwatch
#  -X, --just-run   -- same as --no-src --no-deps --no-compile
#  --src-dir <dir>  -- set src directory
#                       (default: <auto-detect>, $HOME/git-src/batwatch)
#
# Environment variables:
# * GIT_STORE_DIR    -- git src root directory ($HOME/git-src)
# * MAKEOPTS
# * NO_COLOR
# * DEBUG
#

##### end section header #####

##### begin section license #####

### license for __main__
#@DEFAULT GPL-2+
#


##### end section license #####

##### begin section constants #####

### module defsym
readonly IFS_DEFAULT="${IFS}"
readonly IFS_NEWLINE='
'
readonly NEWLINE="${IFS_NEWLINE}"

readonly EX_OK=0
readonly EX_ERR=1
readonly EX_USAGE=64
readonly ERR_FUNC_UNDEF=101


### module message
MESSAGE_COLOR_GREEN="1;32m"
MESSAGE_COLOR_YELLOW="1;33m"
MESSAGE_COLOR_RED="1;31m"
MESSAGE_COLOR_WHITE="1;29m"


### module __main__
readonly MY_GIT_BASE_URI='git://github.com/dywisor'
readonly PN=batwatch

# generate C_HEADER_DEPS with ./scripts/get_includes.sh ./src/
readonly C_HEADER_DEPS="
errno.h
fcntl.h
getopt.h
glib.h
libgen.h
libupower-glib/upower.h
signal.h
stdio.h
stdlib.h
string.h
sysexits.h
sys/stat.h
sys/types.h
unistd.h
"


##### end section constants #####

##### begin section variables #####

### module autodie

# modules/scripts may want to use/set %AUTODIE, %AUTODIE_NONFATAL
# if autodie behavior is optional
: ${AUTODIE=}
: ${AUTODIE_NONFATAL=}

### module defsym
: ${DEVNULL:=/dev/null}
: ${LOGGER:=true}


### module devel/instagitlet
: ${X_GIT:=git}


##### end section variables #####

##### begin section functions #####

### module die

# void die_get_msg_and_header  (
#    message, **DIE_WORD:="died", **msg!, **header!
# )
#
#  Sets %msg and %header.
#
die_get_msg_and_header() {
   if [ -n "${1-}" ]; then
      msg=" ${1}"
      header="${DIE_WORD:-died}:"
   else
      msg=
      header="${DIE_WORD:-died}."
   fi
}

# @private @noreturn die__minimal ( message, code, **DIE=exit )
#
#  Prints %message to stderr and calls %DIE(code) afterwards.
#
die__minimal() {
   [ "${HAVE_BREAKPOINT_SUPPORT:-n}" != "y" ] || breakpoint die

   local msg header
   die_get_msg_and_header "${1-}"

   if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
      eerror "${msg# }" "${header}"
   else
      echo "${header}${msg}" 1>&2
   fi
   ${DIE:-exit} ${2:-2}
}

# @noreturn die ( message=, code=2, **__F_DIE=die__minimal )
#
#  Calls __F_DIE ( message, code ).
#
die() {
   local __MESSAGE_INDENT=
   ${__F_DIE:-die__minimal} "${1-}" "${2:-2}"
}


### module autodie

# @private void die__autodie ( *argv )
#
#  Runs *argv. Dies on non-zero return code.
#
die__autodie() {
   if "$@"; then
      return 0
   else
      die "command '$*' returned $?."
   fi
}

# void autodie ( *argv, **F_AUTODIE=die__autodie )
#
#  Runs %F_AUTODIE ( *argv ) which is supposed to let the script die on
#  non-zero return code.
#
autodie() { ${F_AUTODIE:-die__autodie} "$@"; }

# @function_alias run() copies autodie()
#
run() { ${F_AUTODIE:-die__autodie} "$@"; }


### module defsym

# int __run__ ( *cmdv )
#
#  Simply runs *cmdv.
#
__run__() { "$@"; }

# int __not__ ( *cmdv )
#
#  Runs *cmdv and returns the negated returncode (1 on success, else 0).
#
__not__() { ! "$@"; }

### module function/functrace

# int get_functrace ( **ftrace! )
#
get_functrace() {
   ftrace=
   return 1
}

# void print_functrace ( message_function=**F_FUNCTRACE_MSG=ewarn )
#
#  Function stub since %FUNCNAME is not available in sh.
#
print_functrace() {
   ${1:-${F_FUNCTRACE_MSG:-eerror}} "not available" "[FUNCTRACE]"
}


### module misc/pragma

# @pragma debug
#
#  Returns true if debugging is enabled, else false.
#
__debug__() {
   [ "${DEBUG:-n}" = "y" ]
}

# @pragma verbose
#
#  Returns true if this script should be verbose, else false.
#
__verbose__() {
   [ "${VERBOSE:-n}" = "y" ]
}

# @pragma quiet
#
#  Returns true if this script should be quiet, else false.
#
__quiet__() {
   [ "${QUIET:-n}" = "y" ]
}

# @pragma interactive
#
#  Returns true if user interaction is allowed, else false.
#
__interactive__() {
   [ "${INTERACTIVE:-n}" = "y" ]
}

# @pragma faking
#
#  Returns true if (certain/all) commands should only be printed and not
#  executed, else false.
#
__faking__() {
   [ "${FAKE_MODE:-n}" = "y" ]
}

### module message

# @stdout @message_emitter<colored> __message_colored (
#    header=<default>, text=, text_append=,
#    color=, header_nocolor, header_colored,
#    **__MESSAGE_INDENT=
# )
#
__message_colored() {
   printf -- "${__MESSAGE_INDENT-}\033[${4:?}%s\033[0m%s${3-}" \
      "${1:-${6?}}" "${2:+ }${2-}"
}

# @stdout @message_emiter<nocolor> __message_nocolor (
#    header=<default>, text=, text_append=,
#    color=, header_nocolor, header_colored,
#    **__MESSAGE_INDENT=
# )
#
__message_nocolor() {
   printf -- "${__MESSAGE_INDENT-}%s%s${3-}" \
      "${1:-${5?}}" "${2:+ }${2-}"
}

# @stdout void einfo (
#    message, header="INFO"|"*",
#    **MESSAGE_COLOR_INFO=<default>, **__F_MESSAGE_EMITTER
# )
#
einfo() {
   ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_INFO:-${MESSAGE_COLOR_GREEN}}" '[INFO]' '*'
}

# @stdout void einfon (
#    message, header="INFO"|"*",
#    **MESSAGE_COLOR_INFO=<default>, **__F_MESSAGE_EMITTER
# )
#
einfon() {
   ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '' \
      "${MESSAGE_COLOR_INFO:-${MESSAGE_COLOR_GREEN}}" '[INFO]' '*'
}

# @stderr void ewarn (
#    message, header="WARN"|"*",
#    **MESSAGE_COLOR_WARN=<default>, **__F_MESSAGE_EMITTER
# )
#
ewarn() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_WARN:-${MESSAGE_COLOR_YELLOW}}" '[WARN]' '*'
}

# @stderr void ewarnn (
#    message, header="WARN"|"*",
#    **MESSAGE_COLOR_WARN=<default>, **__F_MESSAGE_EMITTER
# )
#
ewarnn() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '' \
      "${MESSAGE_COLOR_WARN:-${MESSAGE_COLOR_YELLOW}}" '[WARN]' '*'
}

# @stderr void eerror (
#    message, header="ERROR"|"*",
#    **MESSAGE_COLOR_ERROR=<default>, **__F_MESSAGE_EMITTER
# )
#
eerror() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_ERROR:-${MESSAGE_COLOR_RED}}" '[ERROR]' '*'
}

# @stderr void eerrorn (
#    message, header="ERROR"|"*",
#    **MESSAGE_COLOR_ERROR=<default>, **__F_MESSAGE_EMITTER
# )
#
eerrorn() {
   1>&2 ${__F_MESSAGE_EMITTER:?} "${2-}" "${1-}" '\n' \
      "${MESSAGE_COLOR_ERROR:-${MESSAGE_COLOR_RED}}" '[ERROR]' '*'
}

# @stdout void message ( text, **__F_MESSAGE_EMITTER )
#
message() {
   ${__F_MESSAGE_EMITTER:?} "${1-}" "" '\n' "${MESSAGE_COLOR_WHITE}" "" ""
}

# @stdout void messagen ( text, **__F_MESSAGE_EMITTER )
#
messagen() {
   ${__F_MESSAGE_EMITTER:?} "${1-}" "" '' "${MESSAGE_COLOR_WHITE}" "" ""
}

# void message_bind_functions ( **NO_COLOR=n )
#
#  Binds the einfo, ewarn, eerror and message functions according to the
#  current setting of NO_COLOR.
#  ewarn() and eerror() will output to stderr.
#  Also affects veinfo() and printvar(), which depend on einfo().
#
message_bind_functions() {
   HAVE_MESSAGE_FUNCTIONS=n
   __HAVE_MESSAGE_FUNCTIONS=n

   if [ "${NO_COLOR:-n}" != "y" ]; then
      __F_MESSAGE_EMITTER="__message_colored"
      HAVE_COLORED_MESSAGE_FUNCTIONS=y
   else
      __F_MESSAGE_EMITTER="__message_nocolor"
      HAVE_COLORED_MESSAGE_FUNCTIONS=n
   fi

   __HAVE_MESSAGE_FUNCTIONS=y
   HAVE_MESSAGE_FUNCTIONS=y
}

# void veinfo ( message, header, **DEBUG=n )
#
#  Prints the given message/header with einfo() if DEBUG is set to 'y',
#  else does nothing.
#
veinfo() {
   if __verbose__ || __debug__; then
      einfo "$@"
   fi
   return 0
}

# void veinfo_stderr ( message, header, **DEBUG=n )
#
#  Identical to veinfo(), buts prints the message to stderr
#  (instead of stdout).
#
veinfo_stderr() { veinfo "$@" 1>&2; }

# void veinfon ( message, header, **DEBUG= )
#
#  Like veinfo(), but doesn't append a trailing newline.
#
veinfon() {
   if __verbose__ || __debug__; then
      einfon "$@"
   fi
   return 0
}

# void veinfon_stderr ( message, header, **DEBUG=n )
#
#  Identical to veinfon(), buts prints the message to stderr
#  (instead of stdout).
#
veinfo_stderr() { veinfon "$@" 1>&2; }

# void printvar ( *varname, **F_PRINTVAR=einfo, **PRINTVAR_SKIP_EMPTY=n )
#
#  Prints zero or variables (specified by name) by calling
#  F_PRINTVAR ( "<name>=<value> ) for each variable/value pair.
#
#
printvar() {
   local val
   while [ $# -gt 0 ]; do
      eval val="\${${1}-}"
      if [ -n "${val}" ] || [ "${PRINTVAR_SKIP_EMPTY:-n}" != "y" ]; then
         ${F_PRINTVAR:-einfo} "${1}=\"${val}\""
      fi
      shift
   done
}

# void message_indent ( **__MESSAGE_INDENT! )
#
message_indent() { __MESSAGE_INDENT="${__MESSAGE_INDENT-}  "; }

# void message_outdent ( **__MESSAGE_INDENT )
#
message_outdent() {
   if [ -n "${__MESSAGE_INDENT-}" ]; then
      __MESSAGE_INDENT="${__MESSAGE_INDENT% }"
      __MESSAGE_INDENT="${__MESSAGE_INDENT% }"
      return 0
   else
      return 1
   fi
}

# ~int message_indent_call ( *cmdv )
#
message_indent_call() {
   local __MESSAGE_INDENT="${__MESSAGE_INDENT-}"
   message_indent
   "$@"
}

# void message_autoset_nocolor ( force_rebind=n, **NO_COLOR! )
#
#  Sets NO_COLOR to 'y' if any of the following conditions are met:
#  * /NO_COLOR exists (can also be a broken symlink)
#  * stdout or stderr are not connected to a tty
#  * stdin is connected to a special terminal, e.g. serial console (ttyS*)
#  * /dev/null is missing, which prevents the ttyS* check
#
#  Automatically rebinds the message functions if necessary or
#  if %force_rebind is set to 'y'.
#
#  Note that this function never sets NO_COLOR=n.
#
message_autoset_nocolor() {
   if [ "${NO_COLOR:-n}" != "y" ]; then
      if \
         [ -e /NO_COLOR ] || [ -h /NO_COLOR ] || [ ! -c /dev/null ] \
         [ ! -t 1 ] || [ ! -t 2 ]
      then
         NO_COLOR=y
      else
         case "$(tty 2>/dev/null)" in
            ttyS*|/*/ttyS*)
               # stdin from serial console, disable color
               NO_COLOR=y
            ;;
         esac
      fi
   fi

   # assert ${HAVE_COLORED_MESSAGE_FUNCTIONS:-y} in y n
   # * NO_COLOR <=> (not HAVE_COLORED_MESSAGE_FUNCTIONS)
   #
   if \
      [ "${1:-n}" = "y" ] || \
      [ "${NO_COLOR:-n}" = "${HAVE_COLORED_MESSAGE_FUNCTIONS:-y}" ]
   then
      message_bind_functions
   fi
}


### module die_extended

# @private @noreturn die__extended (
#    message=, code=2, **DIE=exit, **F_ON_DIE=, **PRINT_FUNCTRACE=n
# )
#
#  if %F_ON_DIE has is not defined / has a null value:
#   Prints %message to stderr and calls %DIE(code) afterwards.
#   Also prints the function trace if it is available (bash) and
#   PRINT_FUNCTRACE is set to 'y'
#  else:
#   Calls %F_ON_DIE ( message, code ). Does the actions above
#   only if %F_ON_DIE() returns a non-zero value.
#
die__extended() {
   [ "${HAVE_BREAKPOINT_SUPPORT:-n}" != "y" ] || breakpoint die

   local msg header

   if [ -z "${F_ON_DIE:-}" ] || ! ${F_ON_DIE} "${1}" "${2}"; then
      die_get_msg_and_header "${1-}"
      eerror "${msg# }" "${header}"
      if [ "${PRINT_FUNCTRACE:-n}" = "y" ] && [ -n "${FUNCNAME-}" ]; then
         print_functrace eerror
      fi
      ${DIE:-exit} ${2:-2}
   fi
   return 0
}


### module misc/qwhich

# int qwhich ( *prog )
#
#  Returns 0 if all listed programs are found by which, else 1.
#
qwhich() {
   while [ $# -gt 0 ]; do
      [ -z "${1-}" ] || which "${1}" 1>${DEVNULL} 2>${DEVNULL} || return 1
      shift
   done
   return 0
}

# int qwhich_single ( prog, **v0! )
#
#  Returns 0 if the given program could be found by which, else 1.
#  Also stores the path to the program in %v0.
#
qwhich_single() {
   : ${1:?}
   v0="$( which "${1}" 2>${DEVNULL} )"
   [ -n "${v0}" ]
}

### module scriptinfo
eval_scriptinfo() {
   local x
   if [ ${#} -gt 0 ]; then
      x="${1}"
   else
      x="${0}"
   fi

   if [ -n "${x}" ]; then
      SCRIPT_FILE="$( realpath -Ls "${x}" 2>>${DEVNULL} )"
      if [ -z "${SCRIPT_FILE}" ]; then
         SCRIPT_FILE="$(readlink -f "${x}" 2>>${DEVNULL} )"
         [ -n "${SCRIPT_FILE}" ] || SCRIPT_FILE="${x}"
      fi
      SCRIPT_DIR="${SCRIPT_FILE%/*}"

   else
      SCRIPT_FILE="UNDEF"
      SCRIPT_DIR="${PWD}"
   fi

   SCRIPT_FILENAME="${SCRIPT_FILE##*/}"
   SCRIPT_NAME="${SCRIPT_FILENAME%.*}"
}


### module devel/configure/base

### message functions

# void configure_{echo,info,warn,error}{,n} ( message, ... )
#
#  Prints a normal/info/warning/error message (with/without a trailing newline
#  char). The info, warn and error functions accepts additional args.
#
configure_echo()   { echo    "$@"; }
configure_info()   { einfo   "$@"; }
configure_warn()   { ewarn   "$@"; }
configure_error()  { eerror  "$@"; }
configure_echon()  { echo -n "$@"; }
configure_infon()  { einfon  "$@"; }
configure_warnn()  { ewarnn  "$@"; }
configure_errorn() { eerrorn "$@"; }

# void configure_check_message_begin ( message, message_header=<default> )
#
#  Prints a "Checking whether <message> ... " info message, optionally
#  with the given header (instead of the default one).
#
#  Does not append a trailing newline char.
#
configure_check_message_begin() {
   configure_infon "Checking whether ${1} ... " ${2-}
}

# void configure_check_message_end ( message )
#
#  Completes a "checking whether ..." message (including a trailing newline
#  char).
#
configure_check_message_end() {
   configure_echo "${1}"
}

# @function_alias configure_die() is die()
#
#  configure-related modules / script should call this script instead of die().
#
configure_die() { die "$@"; }

# int configure_which_nonfatal ( prog_name, **v0! )
#
#  Returns 0 if program with the given name could be found, else 1.
#  Stores the path to the program in %v0.
#
configure_which_nonfatal() {
   v0=
   [ $# -eq 1 ] && [ -n "${1-}" ] || \
      configure_die "configure_which: bad usage."

   configure_check_message_begin "${1} exists"
   if qwhich_single "${1}"; then
      configure_check_message_end "${v0}"
   else
      configure_check_message_end "no"
      return 1
   fi
}

# int configure_which ( *prog_names, [**v0!] ), raises configure_die()
#
#  Calls configure_which_nonfatal() for each prog_name and dies on first
#  failure.
#
#  Leaks %v0 iff exactly one arg is given.
#
configure_which() {
   if [ $# -eq 1 ]; then
      configure_which_nonfatal "${1}" || configure_die
   else
      local v0
      while [ $# -gt 0 ]; do
         [ -z "${1-}" ] || configure_which_nonfatal "${1}" || configure_die
         shift
      done
   fi
}

# void configure_which_which(), raises configure_die()
#
#  Verifies that "which" can be found.
#
configure_which_which() {
   if configure_which_nonfatal which; then
      return 0
   else
      configure_die \
         "${SCRIPT_NAME} cannot detect whether programs are available."
   fi
}

### module fs/dodir_minimal

# void dodir_create_keepfile ( dir, **KEEPDIR=n )
#
dodir_create_keepfile() {
   if [ "${KEEPDIR:-n}" = "y" ] && [ ! -e "${1}/.keep" ]; then
      touch "${1}/.keep" || true
   fi
}

# int dodir_minimal (
#    dir, **KEEPDIR=n, **MKDIR_OPTS="-p", **MKDIR_OPTS_APPEND=
# )
#
#  Ensures that the given directory exists by creating it if necessary.
#  Also creates a <dir>/.keep file if **KEEPDIR is set to 'y'.
#
#  Returns 0 if the directory exists (at the end of this function),
#  else 1.
#
dodir_minimal() {
   if \
      [ -d "${1:?}" ] || \
      mkdir ${MKDIR_OPTS--p} ${MKDIR_OPTS_APPEND-} -- "${1}" 2>/dev/null || \
      [ -d "${1}" ]
   then
      dodir_create_keepfile "${1}"
      return 0
   else
      return 1
   fi
}

# int dodir_clean ( *dir, **KEEPDIR=n )
#
#  Ensures that the given directories exist by creating then if necessary.
#  Also creates a <dir>/.keep file if **KEEPDIR is set to 'y'.
#
#  (Calls dodir_minimal ( <dir> ) for each <dir> in *dir.)
#
#  Returns the number of directories that could not be created.
#
dodir_clean() {
   local fail=0
   while [ $# -gt 0 ]; do
      dodir_minimal "${1}" || fail=$(( ${fail} + 1 ))
      shift
   done
   return ${fail}
}

# @function_alias keepdir_clean ( *dir )
#  is KEEPDIR=y dodir_clean ( *dir )
#
keepdir_clean() {
   local KEEPDIR=y
   dodir_clean "$@"
}

### module varcheck

# void|int varcheck (
#    *varname,
#    **VARCHECK_ALLOW_EMPTY=n, **VARCHECK_PREFIX=, **VARCHECK_DIE=y
# ), raises die()
#
#  Ensures that zero or more variables are set.
#  Prefixes each variable with VARCHECK_PREFIX if set.
#
#  Returns a non-zero value if any var is unset or has an empty value (and
#  VARCHECK_ALLOW_EMPTY != y).
#
#  Calls die() with a rather meaningful message instead of returning if
#  VARCHECK_DIE is set to 'y'.
#
#  Note:
#     Variables whose name start with VARCHECK_ or varcheck_ cannot be
#     checked properly for technical reasons (private namespace).
#
#  Note:
#     This function is meant for checking many variables at once,
#     e.g. config keys. Functions should use "${<varname>:?}" etc.
#
varcheck() {
   local varcheck_unset \
      varcheck_varname varcheck_val0 varcheck_val1

   for varcheck_varname; do
      varcheck_varname="${VARCHECK_PREFIX-}${varcheck_varname}"

      eval "varcheck_val0=\${${varcheck_varname}-}"
      if [ -z "${varcheck_val0}" ]; then
         if [ "${VARCHECK_ALLOW_EMPTY:-n}" = "y" ]; then
            eval "varcheck_val1=\${${varcheck_varname}-UNDEF}"
            if [ "x${varcheck_val1}" != "x${varcheck_val0}" ]; then
               # UNDEF, "" => not set
               varcheck_unset="${varcheck_unset-} ${varcheck_varname}"
            fi
            # else "", "" empty => allowed
         else
            # empty or unset
            varcheck_unset="${varcheck_unset-} ${varcheck_varname}"
         fi
      fi
   done

   if [ -n "${varcheck_unset-}" ]; then

      if [ "${VARCHECK_DIE:-y}" != "y" ]; then
         return 1
      else
         local varcheck_msg

         if [ "${VARCHECK_ALLOW_EMPTY:-n}" = "y" ]; then
            varcheck_msg="the following variables are not set:"
         else
            varcheck_msg="the following variables are either empty or not set:"
         fi

         for varcheck_varname in ${varcheck_unset}; do
            varcheck_msg="${varcheck_msg}\n ${varcheck_varname}"
         done

         die "${varcheck_msg}"

      fi

   else
      return 0
   fi
}

# @function_alias varcheck_allow_empty(...)
#  is varcheck (..., **VARCHECK_ALLOW_EMPTY=y )
#
varcheck_allow_empty() {
   VARCHECK_ALLOW_EMPTY=y varcheck "$@"
}

# @function_alias varcheck_allow_empty(...)
#  is varcheck (..., **VARCHECK_ALLOW_EMPTY=n )
#
varcheck_forbid_empty() {
   VARCHECK_ALLOW_EMPTY=n varcheck "$@"
}

### module devel/instagitlet
instagitlet_fakecmd() {
   local tag="${1:-cmd}"; shift || die "out of bounds"
   einfo "${*}" "(${tag})"
}

instagitlet_dodir() {
   if __faking__; then
      instagitlet_fakecmd dodir "$@"
   elif dodir_clean "$@"; then
      return 0
   else
      local rc=${?}
      eerror "failed to create directories: ${*}"
      return ${rc}
   fi
}

instagitlet_run_git() {
   #@VARCHECK X_GIT *
   if __faking__; then
      instagitlet_fakecmd git-cmd ${X_GIT} "$@"
   elif ${X_GIT} "$@"; then
      return 0
   else
      local rc=${?}
      eerror "'${X_GIT} ${*}' failed (${rc})."
      return ${rc}
   fi
}

instagitlet_chdir() {
   if __faking__; then
      FAKE_MODE_CHDIR_FAIL=
      instagitlet_fakecmd chdir "$@"
      if ! cd "$@" 2>/dev/null; then
         FAKE_MODE_CHDIR_FAIL="$*"
         ewarn "cd '${*}' failed, continuing anyway." '!!!'
      fi
      return 0
   elif cd "$@"; then
      return 0
   else
      eerror "cd '${*}' failed!"
      return 1
   fi
}

# int git_repo_update ( store_dir, git_uri )
#
git_repo_update() {
   #@VARCHECK 1 2 X_GIT
   instagitlet_dodir "${1%/*}" || return

   if [ -d "${1}" ]; then
      einfo "Updating existing git repo ${1}"
      (
         git=instagitlet_run_git || die "\$git is readonly"

         instagitlet_chdir "${1}" && \
         ${git} fetch && \
         ${git} config merge.defaultToUpstream true && \
         ${git} merge --ff-only
      )
   else
      einfo "Downloading git repo ${2}"
      instagitlet_run_git clone "${2}" "${1}"
   fi
}

# int instagitlet__get_vars_from_passwd (
#    user="",
#    **ID_USER!, **ID_UID!, **ID_GID!, **ID_HOME!
# )
#
instagitlet__get_vars_from_passwd() {
   ID_USER=; ID_UID=; ID_GID=; ID_HOME=;

   local my_uid pwd_entry

   if \
      my_uid="$(id -u ${1-} 2>/dev/null)" && \
      pwd_entry="$( getent passwd "${my_uid}")"
   then
      local IFS=":"
      set -- ${pwd_entry}
      IFS="${IFS_DEFAULT}"

      ID_USER="${1-}"
      ID_UID="${3-}"
      ID_GID="${4-}"
      ID_HOME="${6-}"

      if \
         [ -n "${1-}" ] && [ -n "${3-}" ] && [ -n "${4-}" ] && \
         [ -n "${6+SET}" ]
      then
         return 0
      else
         return 3
      fi
   else

      return 2
   fi
}

# void instagitlet_init_vars (
#    project_name, git_uri,
#    destdir=%GIT_STORE_DIR/%project_name,
#    **GIT_STORE_DIR=%HOME/git-src,
#    **HOME!x,
#    **GIT_APP_NAME!, **GIT_APP_URI!, **GIT_APP_ROOT!, **GIT_APP_REAL_ROOT!
# ), raises die()
#
instagitlet_init_vars() {
   local v0

   [ -n "${1-}" ] || die "project name must not be empty." ${EX_USAGE}
   [ -n "${2-}" ] || ewarn "empty git uri prevents sync actions."

   if ! instagitlet__get_vars_from_passwd; then
      ewarn "failed to get passwd data!"
   fi

   if [ -z "${HOME-}" ] && [ -n "${ID_HOME}" ]; then
      HOME="${ID_HOME}"
      export HOME
   fi

   [ -z "${HOME-}" ] || : ${GIT_STORE_DIR:="${HOME}/git-src"}

   GIT_APP_NAME="${1}"
   GIT_APP_URI="${2-}"

   case "${3-}" in
      '')
         [ -n "${HOME-}" ] || die "\$HOME is not set."
         GIT_APP_ROOT="${GIT_STORE_DIR}/${GIT_APP_NAME}"
      ;;
      ./*|/*)
         GIT_APP_ROOT="${3}"
      ;;
      *)
         GIT_APP_ROOT="${GIT_STORE_DIR}/${3}"
      ;;
   esac

   GIT_APP_REAL_ROOT="$(readlink -m "${GIT_APP_ROOT}")"
   return 0
}

instagitlet_get_src() {
   local KEEPDIR=y
   varcheck GIT_APP_URI GIT_APP_ROOT GIT_APP_REAL_ROOT
   autodie git_repo_update "${GIT_APP_REAL_ROOT}" "${GIT_APP_URI}"
}

### module __main__

# int guess_git_dir ( **SCRIPT_DIR, **v0! )
#
guess_git_dir() {
   v0=
   local pdir

   if [ -z "${SCRIPT_DIR-}" ]; then
      ewarn "\$SCRIPT_DIR is not set. git dir cannot be detected." '!!!'
      return 1
   fi

   case "${SCRIPT_DIR}" in
      */scripts|*/dist)
         pdir="${SCRIPT_DIR%/*}"
      ;;
      *)
         return 2
      ;;
   esac

   if [ -e "${pdir}/.${PN}" ]; then
      v0="${pdir}"
      return 0
   elif \
      [ -d "${pdir}/.git" ] && \
      [ -f "${pdir}/event-scripts/dummy.sh" ] && \
      grep -sqIi -- "installing..*${PN}" "${pdir}/README.rst" && \
      [ -f "${pdir}/Makefile" ]
   then
      v0="${pdir}"
      return 0
   fi

   return 1
}

# int locate_file_in_path_var (
#    filename, path_var, **PATH_SEPARATOR=":", **v0!
# )
#
locate_file_in_path_var() {
   #@VARCHECK 1
   #@VARCHECK_EMPTYOK IFS_DEFAULT 2
   v0=
   local fname="${1}"
   local IFS="${PATH_SEPARATOR:-:}"
   set -- ${2}
   IFS="${IFS_DEFAULT}"
   while [ ${#} -gt 0 ]; do
      if [ -d "${1}/" ]; then
         if [ -f "${1}/${fname}" ]; then
            v0="${1}/${fname}"
            return 0
         elif {
            v0="$(find "${1}/" -xdev -type f -name "${fname}" | head -n 1)"
            [ -n "${v0}" ]
         }; then
            return 0
         else
            v0=
         fi
      fi
      shift
   done
   return 1
}

# void check_for_c_headers ( *header_files )
#
check_for_c_headers() {
   local __MESSAGE_INDENT="${__MESSAGE_INDENT-}"
   local miss_count=0
   local fmt_name

   [ -n "${C_INCLUDE_PATH-}" ] || local C_INCLUDE_PATH="/usr/include"

   einfo "Checking whether C header files are present:"
   message_indent
   while [ ${#} -gt 0 ]; do
      fmt_name="$(printf "%-23s" "${1}")"; : ${fmt_name:=${1}}

      if locate_file_in_path_var "${1}" "${C_INCLUDE_PATH}"; then
         einfo "${fmt_name} ... ${v0}" "->"
      else
         eerror "${fmt_name} ... not found." '!!' 2>&1
         miss_count=$(( ${miss_count} + 1 ))
      fi
      shift
   done
   message_outdent

   if [ ${miss_count} -eq 0 ]; then
      einfo "Found all header files."
   else
      echo 1>&2
      eerror "" '!!!'
      eerror "${miss_count} header files are missing." '!!!'
      eerror "Build process will probably fail." '!!!'
      eerror "" '!!!'
      echo 1>&2
   fi

   return 0
}


##### end section functions #####

##### begin section module_init_vars #####

### module die
: ${HAVE_DIE:=y}

### module function/functrace
readonly FUNCTRACE_AVAILABLE=n

### module die_extended

# make die__extended() available
__F_DIE=die__extended

##### end section module_init_vars #####

##### begin section module_init #####

### module message

# @implicit void main ( **MESSAGE_BIND_FUNCTIONS=y )
#
#  Binds the message functions if %MESSAGE_BIND_FUNCTIONS is set to 'y'.
#
: ${__F_MESSAGE_EMITTER:="__message_nocolor"}
[ "${MESSAGE_BIND_FUNCTIONS:-y}" != "y" ] || message_bind_functions

### module scriptinfo
eval_scriptinfo

##### end section module_init #####


want_depcheck=y
want_src=y
want_compile=y
want_rdepcheck=y
want_run=y
my_git_src_dir=

arg=
doshift=

veinfo "parsing args: '$*'" "(argparse)"
while [ ${#} -gt 0 ]; do
   doshift=1
   arg="${1}"

   case "${arg}" in
      '--dry-run'|'-n')
         FAKE_MODE=y
         : ${DEBUG:=y}
      ;;
      '--no-color'|'-c')
         NO_COLOR=y
         message_bind_functions
      ;;
      '--no-src'|'--offline')
         want_src=
      ;;
      '--no-deps')
         want_depcheck=
      ;;
      '--no-compile')
         want_compile=
      ;;
      '--no-run')
         want_run=
         want_rdepcheck=
      ;;
      '--just-run'|'-X')
         want_depcheck=
         want_src=
         want_compile=
         #want_rdepcheck=
         want_run=y
      ;;

      '--src-dir')
         [ -n "${2-}" ] || die "--src-dir needs an arg." ${EX_USAGE}
         my_git_src_dir="${2}"
         doshift=2
      ;;

      '--help'|'-h')
echo "\
Usage: ${SCRIPT_NAME} [option...] [--] <${PN} args...>

Options:
  -c, --no-color   --
  -h, --help       --
  -n, --dry-run    -- show what whould be done
  --no-src,
  --offline        -- don't update/clone the git repo
  --no-deps        -- don't check for build dependencies
  --no-compile     -- don't build ${PN}
  --no-run         -- don't run ${PN}
  -X, --just-run   -- same as --no-src --no-deps --no-compile
  --src-dir <dir>  -- set src directory
                       (default: <auto-detect>, \$HOME/git-src/${PN})

Environment variables:
* GIT_STORE_DIR    -- git src root directory (\$HOME/git-src)
* MAKEOPTS
* NO_COLOR
* DEBUG
"
         exit 0
      ;;
      --)
         shift
         break
      ;;
      *)
         #doshift=0
         break
      ;;
   esac

   [ ${doshift} -eq 0 ] || shift ${doshift} || die "out of bounds"
done

if __verbose__ || __debug__; then
   einfon "argv remainder:" "(argparse)"
   for arg; do
      printf " \"%s\"" "${arg}"
   done
   printf "\n\n"
fi

unset -v doshift arg

MY_PHASES="\
${want_depcheck:+depcheck }\
${want_rdepcheck:+runtime-depcheck }\
${want_src:+src }\
${want_compile:+compile }\
${want_run:+run }"
MY_PHASES="${MY_PHASES% }"

einfo "Running phases: <${MY_PHASES:-none}>"
echo

### init env
einfo "init env" ">>>"

if __faking__; then
   F_DEPCHECK=configure_which_nonfatal
else
   F_DEPCHECK=configure_which
fi

if [ -z "${my_git_src_dir}" ] && guess_git_dir; then
   my_git_src_dir="${v0}"
fi

if [ -z "${MAKEOPTS+SET}" ]; then
   if qwhich_single nproc; then
      _cpucount="$(${v0})"
   else
      _cpucount="$( grep -c -- ^processor /proc/cpuinfo 2>>${DEVNULL})"
   fi
   [ -z "${_cpucount}" ] || MAKEOPTS="-j${_cpucount}"
   unset -v _cpucount
fi

instagitlet_init_vars \
   "${PN}" "${MY_GIT_BASE_URI}/${PN}.git" "${my_git_src_dir}"
echo

### depcheck (buildtime)
if [ -n "${want_depcheck}" ]; then
   einfo "dependency check" ">>>"
   ${F_DEPCHECK} which

   ${F_DEPCHECK} git || v0="git"
   X_GIT="${v0}"

   for dep in make gcc; do
      ${F_DEPCHECK} ${dep}
   done

   ${F_DEPCHECK} pkg-config || v0="false"
   X_PKG_CONFIG="${v0}"

   # check_for_c_headers() doesn't return != 0, currently
   autodie check_for_c_headers ${C_HEADER_DEPS?}

   configure_check_message_begin "pkg-config finds upower-glib"
   if \
      ${X_PKG_CONFIG} --libs --cflags upower-glib 1>/dev/null 2>/dev/null
   then
      configure_check_message_end "yes"
   else
      configure_check_message_end "no"
      if __faking__; then
         ewarn "upower libs not found, continuing anyway." '!!!'
      else
         die "upower libs are required for building ${PN}"
      fi
   fi

   echo
else
   : ${X_GIT:=git}
   : ${X_PKG_CONFIG:=pkg-config}
fi

### depcheck (runtime)
if [ -n "${want_rdepcheck}" ]; then
   einfo "runtime dependency check" ">>>"
   ${F_DEPCHECK} upower || v0="upower"
   X_UPOWER="${v0}"
   echo
else
   : ${X_UPOWER:=upower}
fi

### get src
if [ "${want_src}" ]; then
   einfo "src" ">>>"
   instagitlet_get_src
   if __faking__; then
      instagitlet_fakecmd touch touch "${GIT_APP_REAL_ROOT}/.${PN}"
   elif [ ! -e "${GIT_APP_REAL_ROOT}/.${PN}" ]; then
      autodie touch "${GIT_APP_REAL_ROOT}/.${PN}"
   fi
   echo
fi

### build
if [ "${want_compile}" ]; then
   einfo "build" ">>>"
   instagitlet_chdir "${GIT_APP_REAL_ROOT}" || die
   if __faking__; then
      instagitlet_fakecmd make make -n ${MAKEOPTS-} "${PN}"
      if [ -n "${FAKE_MODE_CHDIR_FAIL-}" ]; then
         ewarn "skipping make command - chdir failed." '(dry-run)'
      else
         make ${MAKEOPTS-} -n "${PN}" || eerror "make returned ${?}." "!!!"
      fi
   else
      autodie make ${MAKEOPTS-} "${PN}"
   fi
   echo
fi

### run
if [ "${want_run}" ]; then
   echo
   einfo "run" ">>>"

   if [ ! -x "${GIT_APP_REAL_ROOT}/${PN}" ]; then
      if __faking__; then
         ewarn "${PN} binary is missing." '!!!'
      else
         die "${PN} binary is missing." 5
      fi
   fi

   # chdir not necessary here
   instagitlet_chdir "${GIT_APP_REAL_ROOT}" || die

   print_pkill_message=YES
   for arg; do
      case "${arg}" in
         '--pidfile'|'-p'|'-N'|'--no-fork')
            print_pkill_message=
            break
         ;;
      esac
   done

   if [ -n "${print_pkill_message}" ]; then
      ewarn "Neither --pidfile nor --no-fork specified" '!!!'
      ft="for terminating ${PN}." || die "\$ft readonly."

      if qwhich pkill; then
         ewarn "Use 'pkill -u ${USER:-${ID_USER?}} -TERM ${PN}' ${ft}" '!!!'
      elif qwhich pidof kill; then
         ewarn "Use 'kill -TERM \$(pidof ${PN})' ${ft}" '!!!'
      else
         ewarn "No suggestions available ${ft}" '!!!'
      fi
      echo
   fi

   set -- "${GIT_APP_REAL_ROOT}/${PN}" "$@"

   if __faking__; then
      instagitlet_fakecmd "cmd" "$@"
   else
      veinfo "${GIT_APP_REAL_ROOT}/${PN} $*" "(cmd)"
      "$@"
   fi
fi
