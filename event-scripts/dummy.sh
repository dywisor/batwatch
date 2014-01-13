#!/bin/sh
RE_VARNAMES="((.+_)?BATTERY(_.+)?|PATH|HOME|DISPLAY|USER|LOGNAME|LANG|LC_ALL|PWD|TMPDIR|T)"

echo "--- batwatch dummy event script ---"
if [ -n "$*" ]; then
   echo "argv = <${*}>"
   echo "---"
fi
# print env, filter out functions, get interesting vars, sort them
{ printenv || command -p printenv; } | \
   command -p sed -r -e '/^\s+/d' -e '/=\(\)\s+\{/d' -e '/^}/d' | \
   command -p grep -E "^${RE_VARNAMES}=" | command -p sort
echo "--- end batwatch dummy event script ---"

exit 0
