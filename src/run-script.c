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
#include <syslog.h>

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
   uint  retcode;
   int   exec_errno;

   retcode = EXIT_FAILURE;

   /* if <check script type...> {...} */

   syslog ( LOG_NOTICE, "running script %s for battery %s (type %#x)",
      script->exe, battery->name, script->type
   );

   if ( script->type == SCRIPT_TYPE_EXE_NO_ARGS ) {
      g_debug ( "running script %s for battery %s without args.",
         script->exe, battery->name
      );

      execlp ( script->exe, script->exe, NULL );
      /* exec should not return */
      exec_errno = errno;
      g_warning ( "exec %s failed: %s\n",
         script->exe, strerror ( exec_errno )
      );
      syslog ( LOG_ERR, "exec %s failed: %s",
         script->exe, strerror ( exec_errno )
      );
      retcode = EX_OSERR;

/*
   } else if ( script->type == SCRIPT_TYPE_EXE_WITH_ARGS ) {
      // stub -- no args passed to scripts
      g_debug ( "running script %s for battery %s with args.",
         script->exe, battery->name
      );

      execlp ( script->exe, script->exe, NULL );
      // exec should not return
      exec_errno = errno;
      g_warning ( "exec %s failed: %s\n",
         script->exe, strerror ( exec_errno )
      );
      syslog ( LOG_WARNING, "exec %s failed: %s",
         script->exe, strerror ( exec_errno )
      );
      retcode = EX_OSERR;
*/
   } else {
      g_warning ( "unknown script type %d\n", script->type );
      syslog ( LOG_ERR, "%s: unknown script type %#x",
         script->exe, script->type
      );
   }


/* run_script_sync_return: */

   return retcode;
}
