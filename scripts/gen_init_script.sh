#!/bin/sh
# creates init openrc/debian init scripts
#
# Usage: gen-init-script <.in file> [<out file>]
#
set -u


die() {
   printf "%s\n" "${1:-died.}" 1>&2
   exit ${2:-2}
}


print_VARS() {
cat << EOF
${1}: \${BATWATCH_PIDFILE:=/run/batwatch/batwatch.pid}
${1}: \${BATWATCH_BINARY:=/usr/bin/batwatch}
${1}: \${BATWATCH_RUNDIR:=/}
${1}: \${BATWATCH_OPTS=}
${1}: \${BATWATCH_USER=}
${1}: \${BATWATCH_GROUP=}

${1}: \${MY_SSD_OPTS=}
${1}if [ -n "\${BATWATCH_USER}" ]; then
${1}   MY_SSD_OPTS="\${MY_SSD_OPTS-} -u \${BATWATCH_USER}"
${1}fi

${1}if [ -n "\${BATWATCH_GROUP}" ]; then
${1}   MY_SSD_OPTS="\${MY_SSD_OPTS-} -g \${BATWATCH_GROUP}"
${1}fi
EOF
}

print_START_CODE() {
cat << EOF
${1}start-stop-daemon --start --exec "\${BATWATCH_BINARY}" \\
${1}   --pidfile "\${BATWATCH_PIDFILE}" \${MY_SSD_OPTS-} -- \\
${1}   -p "\${BATWATCH_PIDFILE}" -C "\${BATWATCH_RUNDIR}" \\
${1}   \${BATWATCH_OPTS-}
EOF
}


print_STOP_CODE() {
cat << EOF
${1}start-stop-daemon --stop --exec "\${BATWATCH_BINARY}" \\
${1}   --pidfile "\${BATWATCH_PIDFILE}" \${MY_SSD_OPTS-} "\$@"
EOF
}

print_STOP() { echo "${1}do_stop"; }

print_F_EXE_CHECK() {
cat << EOF
${1}@@EXE_CHECK@@() {
${1}   set -- \${BATWATCH_OPTS-}
${1}   while [ \${#} -gt 0 ]; do
${1}      case "\${1}" in
${1}         '-x'|'--exe')
${1}            [ -z "\${2-}" ] || return 0
${1}         ;;
${1}      esac
${1}      shift
${1}   done
${1}   return 1
${1}}
EOF
}

print_FUNCS() {
   local s="${1}   "

   print_F_EXE_CHECK "${1}"

cat << EOF

${1}@@START@@() {
$(print_START_CODE "${s}")
${1}}

${1}@@STOP@@() {
$(print_STOP_CODE "${s}")
${1}}

${1}@@RELOAD@@() {
${s}@@STOP@@ @@RELOAD_ARGS@@
${1}}

${1}@@GET_STATUS@@() {
${s}@@STOP@@ @@GET_STATUS_ARGS@@
${1}}
EOF
}


readonly INFILE="${1--}"
if [ -z "${INFILE}" ]; then
   die "Usage: ${0} <infile> [<outfile>]" 64
fi

readonly OUTFILE="${2:--}"
case "${OUTFILE}" in
   '-')
      true
   ;;
   "${INFILE}")
      die "infile == outfile" 64
   ;;
   *.in)
      die "outfile ${OUTFILE} seems to be an input file." 2
   ;;
esac



if [ "${INFILE}" != "-" ]; then
   exec 0<"${INFILE}" || die "failed to open file ${INFILE} @stdin" 3
fi

if [ "${OUTFILE}" != "-" ]; then
   exec 1>"${OUTFILE}" || die "failed to open file ${OUTFILE} @stdout" 4
fi

x() {
   local k="${1}"; shift
   echo "s=@@${k}@@=${*}=g"
}

IFS=
while read -r line; do
   if echo "${line}"| grep -qEx -- '\s*@@[a-zA-Z_0-9_]+@@\s*'; then
      kw="${line#*@@}"; kw="${kw%@@*}"
      indent="${line%%@@*}"
      if ! print_${kw} "${indent}"; then
         echo "unknown keyword ${kw}" 1>&2
         echo "${line}"
      fi
   else
      echo "${line}"
   fi
done | sed \
   -e "$(x NAME batwatch)" -e "$(x SVCNAME batwatch)" \
   -e "$(x START do_start)" -e "$(x STOP do_stop)" \
   -e "$(x RELOAD do_reload)" -e "$(x GET_STATUS get_status)" \
   -e "$(x RELOAD_ARGS --signal HUP)" \
   -e "$(x GET_STATUS_ARGS --test --quiet)" \
   -e "$(x CHECK_BINARY_MISSING "[ ! -x \"\${BATWATCH_BINARY}\" ]")" \
   -e "$(x EXE_CHECK batwatch_check_exe_arg)" \
   -e "$(x BINARY "\${BATWATCH_BINARY}" )"
