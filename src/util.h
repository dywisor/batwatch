/*
 * util.h
 *
 * Copyright (C) 2014 Andre Erdmann <dywi@mailerd.de>
 *
 * batwatch is free software: you can redistribute it and/or modify
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
 */

#ifndef _BATWATCH_UTIL_H_
#define _BATWATCH_UTIL_H_

#include <errno.h>
#include <glib.h>
#include <stdio.h>
#include <string.h>

#include "globals.h"
#include "gcc-compat.h"


static inline gchar* format_time_int   ( const gint32 i  )
   ATTRIBUTE_WARN_UNUSED_RESULT;
static inline gchar* format_percentage ( const gdouble p )
   ATTRIBUTE_WARN_UNUSED_RESULT;

/*
 * converts an gint64 to gint32
 *
 * Returns TRUE if the number could be converted without loss of information
 * (and sets *result = <number>), else FALSE (and sets *result = -1).
 * */
static inline gboolean util_gint64_to_32 (
   const gint64 big, gint32* result
) {
   if ( big >= G_MININT32 && big <= G_MAXINT32 ) {
      *result = (gint32) big;
      return TRUE;
   } else {
      *result = -1;
      return FALSE;
   }
}

/* converts an gint32 represting seconds or minutes to a str */
static inline gchar* format_time_int ( const gint32 i ) {
   gchar* retstr;
   retstr = g_strdup_printf ( SCRIPT_TIME_VAR_FMT, i );
   return retstr;
}


/* converts a gdouble into a str */
static inline gchar* format_percentage ( const gdouble p ) {
   gchar* retstr;

   retstr = g_malloc ( SCRIPT_PERCENT_VAR_FMT_BUFSIZE );
   return g_ascii_formatd (
      retstr, SCRIPT_PERCENT_VAR_FMT_BUFSIZE, SCRIPT_PERCENT_VAR_FMT, p
   );
}

/*
 * Converts a str into a double > 0.
 * Returns 0 on success, else an error code.
 * Stores the converted double in %d_out (only if successful).
 */
static inline gint parse_percentage (
   const char* input_str, gdouble* d_out
) {
   /* g_strtod(), strtod()? */
   const gint errsv = errno;
   gint       conv_err;
   gchar*     pchar_end;
   gdouble    result;

   errno    = 0;
   result   = g_strtod ( input_str, &pchar_end );
   conv_err = errno;
   errno    = errsv;

   if ( conv_err == 0 ) {
      if ( pchar_end && ( *pchar_end != '\0' ) ) {
         conv_err = EINVAL;
      } else if ( ( result - 0.1 ) < 0.0 ) {
         /* d_out near or below zero */
         conv_err = EINVAL;
      } else {
         *d_out = result;
      }
   }

   return conv_err;
}

static inline gboolean verbosely_redirect_output (
   FILE* const stream,
   const char* const new_output_file,
   FILE* const err_stream,
   const char* const mode
) {
   if (
      NULL != freopen (
         new_output_file, ( ( mode == NULL ) ? "a": mode ), stream
      )
   ) {
      return TRUE;
   } else if ( err_stream == NULL ) {
      return FALSE;
   } else {
      fprintf ( err_stream,
         "failed to redirect output to %s: %s",
         new_output_file, strerror ( errno )
      );
      return FALSE;
   }
}

static inline gboolean verbosely_close_fd (
   const int fd, FILE* const err_stream
) {
   if ( close ( fd ) == 0 ) {
      return TRUE;
   } else if ( err_stream == NULL ) {
      return FALSE;
   } else {
      fprintf ( err_stream,
         "failed to close fd %d: %s\n", fd, strerror ( errno )
      );
      return FALSE;
   }
}

static inline gboolean verbosely_redirect_or_close_output (
   FILE* const stream,
   const int fd,
   const char* const new_output_file,
   FILE* const err_stream,
   const char* const mode
) {
   if ( new_output_file == NULL ) {
      return verbosely_close_fd ( fd, err_stream );
   } else {
      return verbosely_redirect_output (
         stream, new_output_file, err_stream, mode
      );
   }
}

#endif /* _BATWATCH_UTIL_H_ */
