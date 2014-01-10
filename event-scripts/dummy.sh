#!/bin/sh
printf "BATSCRIPT<"
if [ ${#} -gt 0 ]; then
   printf "'${1}'"
   shift
   while [ ${#} -gt 0 ]; do
      printf " '${1}'"
      shift
   done
fi
printf ">\n"
