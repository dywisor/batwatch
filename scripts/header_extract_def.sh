#!/bin/sh -u
#
#  extracts #defines from C header files
#   as long as they don't span over multiple lines.
#
#  Usage: <script> [-a|--all] file def_name
#
#  Returns 0 if at least occurence of %def_name was found, else non-zero.
#

# void unquote__<implementation> ( str )
#
#  Unquoting strings with xargs should be safer,
#  but fall back to eval if xargs is not available (unlikely).
#
unquote__xargs() { echo "${1}" | ${X_XARGS} echo; }
unquote__eval()  { eval "echo \"${1}\""; }

# shbool fnmatch ( fname, pattern:? )
#
fnmatch() {
   case "${1}" in ${2:?}) return 0 ;; esac
   return 1
}

X_XARGS="$(which xargs 2>/dev/null)"
F_UNQUOTE="unquote__xargs"
[ -n "${X_XARGS}" ] || F_UNQUOTE="unquote__eval"

exit_code=; keep_going=;
case "${1-}" in
   '-a'|'--all') keep_going=YES; shift ;;
esac

# check for non-empty file / def_name args
[ -n "${1-}" ] && [ -n "${2-}" ] || exit 64

# open file @stdin
[ "${1}" = "-" ] || exec 0<"${1}" || exit 4

while read -r def key value; do
   if [ "${def}" = '#define' ] && fnmatch "${key}" "${2}"; then
      ${F_UNQUOTE} "${value}"
      : ${exit_code:=0}
      [ -n "${keep_going-}" ] || break
   fi
done

exit ${exit_code:-1}
