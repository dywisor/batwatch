/*
 * run-script.c
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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sysexits.h>
#include <glib.h>

#include "run-script.h"
#include "data_types.h"
#include "util.h"

/* actual run_script() function */
static uint run_script__blocking (
   const struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
);


extern void run_script (
         struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
) {
   /* there's no script type that cannot be run async so far */
   run_script_async ( script, battery, fallback_battery );
}

extern pid_t run_script_async (
         struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
) {
   pid_t pid;
   uint  retcode;

   /*
    * mark script as run even if fork() fails,
    * else we've got a nifty fork bomb
    */
   script_mark_as_run ( script, battery );

   pid = fork();

   if ( pid == 0 ) {
      retcode = run_script__blocking ( script, battery, fallback_battery );
      _exit ( retcode );
   } else if ( pid < 0 ) {
      g_warning (
         "while trying to run a script: failed to fork!"
      );
   }

   return pid;
}


/*
extern gboolean run_script_sync (
         struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
) {
   // stub
   return FALSE;
}
*/


static uint run_script__blocking (
   const struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
) {
   static const char* const EMPTY_STR = "";

   gchar* bat_percent_str;
   gchar* fbat_percent_str;
   guint  retcode;

   bat_percent_str  = NULL;
   fbat_percent_str = NULL;
   retcode          = EXIT_FAILURE;


   /* if <check script type...> {...} */

   if ( script->type == SCRIPT_TYPE_EXE_WITH_ARGS ) {
      /* TODO/COULDFIX: better argv creation */

      g_debug ( "running script %s for battery %s with args.",
         script->exe, battery->name
      );

      bat_percent_str = format_percentage ( battery->remaining_percent );

      if ( fallback_battery == NULL ) {
         execlp (
            script->exe,
            script->exe,
            /* args 1..3: name, sysfs, percentage */
            battery->name, battery->sysfs_path, bat_percent_str,
            /* args 4..6: fallback name,sysfs,percentage (not set) */
            EMPTY_STR, EMPTY_STR, EMPTY_STR,
            NULL
         );
      } else {
         fbat_percent_str = format_percentage (
            fallback_battery->remaining_percent
         );

         execlp (
            script->exe,
            script->exe,
            /* args 1..3: name, sysfs, percentage */
            battery->name, battery->sysfs_path, bat_percent_str,
            /* args 4..6: fallback name,sysfs,percentage */
            fallback_battery->name,
            fallback_battery->sysfs_path,
            fbat_percent_str,
            NULL
         );
      }

      /* exec should not return */
      g_warning ( "exec %s failed: %s\n", script->exe, strerror ( errno ) );
      retcode = EX_OSERR;

   } else if ( script->type == SCRIPT_TYPE_EXE_NO_ARGS ) {
      g_debug ( "running script %s for battery %s without args.",
         script->exe, battery->name
      );

      execlp ( script->exe, script->exe, NULL );
      /* exec should not return */
      g_warning ( "exec %s failed: %s\n", script->exe, strerror ( errno ) );
      retcode = EX_OSERR;

   } else {
      g_warning ( "unknown script type %d\n", script->type );
   }


/* run_script_sync_return: */
   if ( bat_percent_str  != NULL ) { g_free ( bat_percent_str  ); }
   if ( fbat_percent_str != NULL ) { g_free ( fbat_percent_str ); }

   return retcode;
}
