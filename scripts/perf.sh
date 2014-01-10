#!/bin/sh
PERF_EVENTS="cycles,instructions,cache-references,cache-misses,branches,\
branch-misses,cpu-clock,task-clock,faults,cs,migrations,instructions"

__run__() { echo "$*"; "$@"; }

X_PERF="$(which perf 2>/dev/null || echo /usr/sbin/perf )"
if [ -x "${X_PERF}" ]; then
   __run__ "${X_PERF}" ${PERF_OPTS-} ${PERF_COMMAND:-stat} \
      ${PERF_COMMAND_OPTS-} ${PERF_EVENTS:+-e} ${PERF_EVENTS-} "$@"
else
   echo "perf not found." 1>&2
   exit 5
fi
