#!/bin/sh -u
#@HEADER
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
#  --no-compile     -- don't build ${PN}
#  --no-run         -- don't run ${PN}
#  --src-dir <dir>  -- set src directory
#                       (default: <auto-detect>, \$HOME/git-src/batwatch)
#
# Environment variables:
# * GIT_STORE_DIR    -- git src root directory (\$HOME/git-src)
# * MAKEOPTS
# * NO_COLOR
# * DEBUG
#
#@LICENSE
#@DEFAULT GPL-2+
#

#@section const
readonly MY_GIT_BASE_URI='git://github.com/dywisor'
readonly PN=batwatch

#@section func

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


#@section __main__

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
   ${F_DEPCHECK} git
   X_GIT="${v0}"
   ! __faking__ || : ${X_GIT:=git}
   for dep in make gcc pkg-config; do
      ${F_DEPCHECK} ${dep}
   done
   # <C headers>
   echo
else
   : ${X_GIT:=git}
fi

### depcheck (runtime)
if [ -n "${want_rdepcheck}" ]; then
   einfo "runtime dependency check" ">>>"
   ${F_DEPCHECK} upower
   X_UPOWER="${v0}"
   ! __faking__ || : ${X_UPOWER:=upower}
   echo
else
   : ${X_UPOWER:=upower}
fi


### get src
if [ "${want_src}" ]; then
   einfo "src" ">>>"
   instagitlet_get_src
   echo
fi


### build
if [ "${want_compile}" ]; then
   einfo "build" ">>>"
   instagitlet_chdir "${GIT_APP_REAL_ROOT}" || die
   if __faking__; then
      instagitlet_fakecmd make make -n ${MAKEOPTS-} "${PN}"
      if [ -n "${FAKE_MODE_CHDIR_FAIL-}" ]; then
         ewarn "skipping make command - chdir failed."
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
      "${GIT_APP_REAL_ROOT}/${PN}" "$@"
   fi
fi
