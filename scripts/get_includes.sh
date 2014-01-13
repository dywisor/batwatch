#!/bin/sh
# Usage: get_includes.sh [-i] src_dir [src_dir...]
#
#  Get system #includes from C files.
#  (no end-of-line comments allowed in #include lines)
#
if [ "x${1-}" = "x-i" ]; then
   RE_INCLUDE='(#include\s+<.+[.]h>)\s*'
   shift
else
   RE_INCLUDE='#include\s+<(.+[.]h)>\s*'
fi

: ${1:?}
find "$@" -type f -not -type l -name '*.[hc]' -print0 | \
   xargs -0 sed -nr -e "s,^${RE_INCLUDE}$,\1,p" | sort -u
