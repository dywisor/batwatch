#!/bin/bash -u
SCRIPTF="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPTD="${SCRIPTF%/*}"
# very portable:
SCC="$(readlink -f "${SCRIPTD}/../../shlib/CC")"
[ -n "${SCC}" ] || SCC="$(which shlib-shlibcc 2>/dev/null)"

if [ ! -x "${SCC}" ]; then
   echo "cannot locate shlibcc wrapper." 1>&2
   exit 4
fi

sname="${1-}";
case "${sname}" in
   /*)
      sfile="${sname}"
      sname="${sfile##*/}"
      sname="${sname%.sh}"
   ;;
   *)
      sname="${sname%.sh}"
      sfile="${SCRIPTD}/${sname}.in.sh"
   ;;
esac
shift

if [ -z "${sname}" ]; then
   echo "missing script name arg." 1>&2
   exit 64
elif [ ! -f "${sfile}" ]; then
   echo "no such script template: ${sfile}" 1>&2
   exit 2
fi

${SCC} --shell sh -u -D --main "${sfile}" \
   --no-enclose-modules --strip-virtual "$@"
