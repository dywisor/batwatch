/*
 * daemonize.c
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
#include <stdlib.h>
#include <unistd.h>
#include <glib.h>
#include <errno.h>
#include <sysexits.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

#include "daemonize.h"
#include "globals.h"
#include "util.h"

extern void daemon_exit_now ( const int* const pretcode ) {
   /* function is not used */
   int exit_code = EXIT_SUCCESS;

   if ( p_batwatch_globals != NULL ) {
      exit_code = p_batwatch_globals->exit_code;
      batwatch_tear_down_globals ( p_batwatch_globals );
   }

   if ( pretcode != NULL ) {
      exit_code = *pretcode;
   }

   exit ( exit_code );
}


/*
 * daemonizes the program
 *
 * Returns TRUE if the daemon has been successfully initialized, else
 * FALSE. FALSE could also mean that fork() failed.
 * Exits the "parent" process if fork() succeeded.
 */
extern gboolean daemonize ( struct batwatch_globals* const globals ) {
   /* could set up logging in this function */
   pid_t    pid;
   pid_t    sid;
   gchar*   pid_str;
   gboolean success;

   pid = fork();
   if ( pid < 0 ) {
      perror ( "fork" );
      globals->exit_code = EX_OSERR;
      return FALSE;
   } else if ( pid > 0 ) {
      /* parent can exit now */
      _exit ( globals->exit_code );
   }

   pid_str = NULL;
   success = FALSE;
   globals->is_daemon = TRUE;

   umask ( S_IWGRP|S_IWOTH );

   /* setsid */
   if ( ( sid = setsid() ) < 0 ) {
      perror ( "setsid" );
      globals->exit_code = EX_OSERR;
      goto daemonize_child_return;
   }

   /* chdir */
   if ( ( globals->rundir != NULL ) && ( chdir ( globals->rundir ) < 0 ) ) {
      perror ( "chdir" );
      globals->exit_code = EX_OSERR;
      goto daemonize_child_return;
   }

   /* pidfile setup */
   if ( globals->pidfile != NULL ) {
      globals->pidfile_fd = open (
         globals->pidfile, O_CREAT|O_RDWR, S_IRUSR|S_IWUSR
      );
      /* open */
      if ( globals->pidfile_fd < 0 ) {
         perror ( "pidfile-open" );
         globals->exit_code = EX_IOERR;
         goto daemonize_child_return;
      }

      /* lock */
      if ( lockf ( globals->pidfile_fd, F_TLOCK, 0 ) < 0 ) {
         perror ( "pidfile-lock" );
         globals->exit_code = EX_IOERR;
         goto daemonize_child_return;
      }

      /* get pid str */
      pid_str = g_strdup_printf ( "%d\n", getpid() );
      g_assert ( pid_str != NULL );

      /* write pid (len(pid_str) > 0) */
      if ( write ( globals->pidfile_fd, pid_str, strlen ( pid_str ) ) <= 0 ) {
         perror ( "pidfile-write" );
         globals->exit_code = EX_IOERR;
         goto daemonize_child_return;
      } else if ( fdatasync ( globals->pidfile_fd ) != 0 ) {
         perror ( "pidfile-fdatasync" );
         globals->exit_code = EX_IOERR;
         goto daemonize_child_return;
      }
   }

   /* close/redirect stdin/stdout/stderr */
   if (
      ( ! verbosely_close_fd ( STDIN_FILENO, stderr ) ) ||
      ( ! verbosely_redirect_or_close_output (
         stdout, STDOUT_FILENO, globals->daemon_stdout_file, stderr, NULL
      ) ) ||
      ( ! verbosely_redirect_or_close_output (
         stderr, STDERR_FILENO, globals->daemon_stderr_file, NULL, NULL
      ) )
   ) {
      /* EX_WHAT? */
      globals->exit_code = EX_OSERR;
      goto daemonize_child_return;
   }

   /* signal setup should be done by caller */

   /* done */
   success = TRUE;

daemonize_child_return:
   if ( pid_str != NULL ) { g_free ( pid_str ); }

   return success;
}
