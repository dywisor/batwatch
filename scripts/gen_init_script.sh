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
${1}: \${BATWACH_PIDFILE:=/run/BATWACH.pid}
${1}: \${BATWACH_BINARY:=/usr/bin/batwatch}
${1}: \${BATWACH_RUNDIR:=/}
${1}: \${BATWACH_OPTS=}
${1}: \${BATWACH_USER=}
${1}: \${BATWACH_GROUP=}

${1}: \${MY_SSD_OPTS=}
${1}if [ -n "\${BATWACH_USER}" ]; then
${1}   MY_SSD_OPTS="\${MY_SSD_OPTS-} -u \${BATWACH_USER}"
${1}fi

${1}if [ -n "\${BATWACH_GROUP}" ]; then
${1}   MY_SSD_OPTS="\${MY_SSD_OPTS-} -g \${BATWACH_GROUP}"
${1}fi
EOF
}

print_START_CODE() {
cat << EOF
${1}start-stop-daemon --start --exec "\${BATWACH_BINARY}" \\
${1}   --pidfile "\${BATWACH_PIDFILE}" \${MY_SSD_OPTS-} -- \\
${1}   -p "\${BATWACH_PIDFILE}" -C "\${BATWACH_RUNDIR}" \\
${1}   \${BATWACH_OPTS-}
EOF
}


print_STOP_CODE() {
cat << EOF
${1}start-stop-daemon --stop --exec "\${BATWACH_BINARY}" \\
${1}   --pidfile "\${BATWACH_PIDFILE}" \${MY_SSD_OPTS-} "\$@"
EOF
}

print_STOP() { echo "${1}do_stop"; }

print_FUNCS() {
   local s="${1}   "


cat << EOF
${1}@@START@@() {
$(print_START_CODE "${s}")
${1})

${1}@@STOP@@() {
$(print_STOP_CODE "${s}")
${1})

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
   -e "$(x CHECK_BINARY_MISSING "[ ! -x \"\${BATWACH_BINARY}\" ]")" \
   -e "$(x BINARY "\${BATWACH_BINARY}" )"
