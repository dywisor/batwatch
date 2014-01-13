/*
 * scriptenv.c
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

#include <glib.h>
#include <errno.h>
#include <stdlib.h>
#include <libupower-glib/upower.h>

#include "scriptenv.h"
#include "data_types.h"
#include "util.h"


/*
 * setenv() variant that
 * (a) catches value == NULL (setting the env var to "").
 * (b) gets the varname from SCRIPT_ENV_VARNAMES, using the given index
 * (c) always replaces the env var
 * (d) stores -1 in retcode if an error occurred
 *     (else leaves retcode unmodified)
 *
 */
static inline void scriptenv_setenv (
   const uint index, const char* value, int* const retcode
) {
   if (
      setenv (
         SCRIPT_ENV_VARNAMES[index], ( value == NULL ? "" : value ), 1
      ) != 0
   ) {
      *retcode = -1;
   }
}


const char* SCRIPT_ENV_VARNAMES[SCRIPT_ENV_VARCOUNT] = {
   /* battery */
   [SCRIPT_ENV_INDEX_BATNAME]   = "BATTERY",
   [SCRIPT_ENV_INDEX_BATPATH]   = "BATTERY_SYSFS",
   [SCRIPT_ENV_INDEX_BATPERC]   = "BATTERY_PERCENT",
   [SCRIPT_ENV_INDEX_BATTIME]   = "BATTERY_TIME",

   /* fallback battery */
   [SCRIPT_ENV_INDEX_FBATNAME]  = "FALLBACK_BATTERY",
   [SCRIPT_ENV_INDEX_FBATPATH]  = "FALLBACK_BATTERY_SYSFS",
   [SCRIPT_ENV_INDEX_FBATPERC]  = "FALLBACK_BATTERY_PERCENT",
   [SCRIPT_ENV_INDEX_FBATTIME]  = "FALLBACK_BATTERY_TIME",
   [SCRIPT_ENV_INDEX_FBATSTATE] = "FALLBACK_BATTERY_STATE",
};



extern int unset_battery_env_vars(void) {
   int  ret;
   uint k;

   ret = 0;

   for ( k = 0; k < SCRIPT_ENV_VARCOUNT; k++ ) {
      if ( unsetenv ( SCRIPT_ENV_VARNAMES[k] ) != 0 ) { ret = -1; }
   }

   return ret;
}


extern int set_battery_env_vars (
   const struct battery_info* const battery,
   const struct battery_info* const fallback_battery
) {
   gchar* strbuf;
   int    ret;
   gint32 minutes_32;

   ret    = 0;
   strbuf = NULL;

   /* battery */
   scriptenv_setenv (
      SCRIPT_ENV_INDEX_BATNAME, battery->name, &ret
   );
   scriptenv_setenv (
      SCRIPT_ENV_INDEX_BATPATH, battery->sysfs_path, &ret
   );

   strbuf = format_percentage ( battery->remaining_percent );
   scriptenv_setenv (
      SCRIPT_ENV_INDEX_BATPERC, strbuf, &ret
   );

   if ( strbuf != NULL ) {
      g_free ( strbuf );
      strbuf = NULL;
   }

   /* remaining running time, in minutes */
   util_gint64_to_32 ( (battery->time)/60, &minutes_32 );
   strbuf = format_time_int ( minutes_32 );
   scriptenv_setenv ( SCRIPT_ENV_INDEX_BATTIME, strbuf, &ret );

   if ( strbuf != NULL ) {
      g_free ( strbuf );
      strbuf = NULL;
   }


   /* fallback battery */
   if ( fallback_battery != NULL ) {
      scriptenv_setenv (
         SCRIPT_ENV_INDEX_FBATNAME, fallback_battery->name, &ret
      );
      scriptenv_setenv (
         SCRIPT_ENV_INDEX_FBATPATH, fallback_battery->sysfs_path, &ret
      );

      strbuf = format_percentage ( fallback_battery->remaining_percent );
      scriptenv_setenv (
         SCRIPT_ENV_INDEX_FBATPERC, strbuf, &ret
      );

      if ( strbuf != NULL ) {
         g_free ( strbuf );
         strbuf = NULL;
      }

      /* time until fully charged, in minutes */
      util_gint64_to_32 ( (fallback_battery->time)/60, &minutes_32 );
      strbuf = format_time_int ( minutes_32 );
      scriptenv_setenv ( SCRIPT_ENV_INDEX_FBATTIME, strbuf, &ret );

      if ( strbuf != NULL ) {
         g_free ( strbuf );
         strbuf = NULL;
      }

      scriptenv_setenv (
         SCRIPT_ENV_INDEX_FBATSTATE,
         up_device_state_to_string ( fallback_battery->state ),
         &ret
      );

   } else {
      scriptenv_setenv ( SCRIPT_ENV_INDEX_FBATNAME,  NULL, &ret );
      scriptenv_setenv ( SCRIPT_ENV_INDEX_FBATPATH,  NULL, &ret );
      scriptenv_setenv ( SCRIPT_ENV_INDEX_FBATPERC,  NULL, &ret );
      scriptenv_setenv ( SCRIPT_ENV_INDEX_FBATTIME,  NULL, &ret );
      scriptenv_setenv ( SCRIPT_ENV_INDEX_FBATSTATE, NULL, &ret );
   }

   return ret;
}

extern void backup_battery_env_vars_into ( char* dest[SCRIPT_ENV_VARCOUNT] ) {
   uint k;

   for ( k = 0; k < SCRIPT_ENV_VARCOUNT; k++ ) {
      dest[k] = getenv ( SCRIPT_ENV_VARNAMES[k] );
   }
}


extern int restore_battery_env_vars ( char* src[SCRIPT_ENV_VARCOUNT] ) {
   uint k;
   int  ret;

   ret = 0;
   for ( k = 0; k < SCRIPT_ENV_VARCOUNT; k++ ) {
      if ( src[k] != NULL ) {
         scriptenv_setenv ( k, src[k], &ret );
      } else if ( unsetenv ( SCRIPT_ENV_VARNAMES[k] ) != 0 ) {
         ret = -1;
      }
   }

   return ret;
}

extern void free_battery_env_backup ( char* bak[SCRIPT_ENV_VARCOUNT] ) {
   uint k;
   for ( k = 0; k < SCRIPT_ENV_VARCOUNT; k++ ) {
      if ( bak[k] != NULL ) {
         g_free ( bak[k] );
         bak[k] = NULL;
      }
   }
}
