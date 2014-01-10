#!/bin/sh
#  Creates a version header file.
#
#  Usage:
#  * gen_version_header.sh <version>
#     Write version header to stdout,
#     assuming that the file will be named "version.h".
#  * gen_version_header.sh <version> <filepath>
#     Write version header to a file.
#
set -u

: ${YEAR:="$(date +%Y)"}
: ${AUTHOR_NAME='Andre Erdmann'}
: ${AUTHOR_EMAIL='dywi@mailerd.de'}
: ${AUTHOR="${AUTHOR_NAME:-UNKNOWN} <${AUTHOR_EMAIL:-UNKNOWN}>"}
: ${PROG_NAME:="batwatch"}

HEADER_REPLACE_CHARS="\-./+="

die() {
   printf "%s%s\n" "${1:+died: }" "${1:-died.}" 1>&2
   exit ${2:-2}
}

uppercase() { echo "${1}" | tr [:lower:] [:upper:]; }

PROG_NAME_UPCASE="$(uppercase "${PROG_NAME}")"

get_header_name() {
   header_name="_${PROG_NAME_UPCASE}_$(uppercase "${1}" | tr "${HEADER_REPLACE_CHARS}" '_')_"
}

gen_c_license_info() {
echo "\
/*
 * ${1:-<file name>}
 *
 * Copyright (C) ${YEAR:-<unknown year>} ${AUTHOR:-<unknown author>}
 *
 * ${PROG_NAME:?} is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */"
}

gen_c_version_header() {
   local header_name
   get_header_name "${filename}"
   gen_c_license_info "${filename}"
   printf \
      "\n#ifndef %s\n#define %s\n\n#define %s \"%s\"\n\n#endif\n" \
         "${header_name}" "${header_name}" \
         "${PROG_NAME_UPCASE}_VERSION" "${1?}"
}

[ -n "${1-}" ] || die "no version given." 64
version="${1}"
shift
if [ -n "${1-}" ]; then
   filename="${1##*/}"
   gen_c_version_header "${version}" > "${1}"
else
   filename="version.h"
   gen_c_version_header "${version}"
fi
