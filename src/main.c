/*
 * batwatch (main.c)
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

/*
 *
 * ref/docs:
 * - https://github.com/zdobersek/UPower-Battery-Status-API
 * - http://upower.freedesktop.org/docs/
 * - http://www.4pmp.com/2009/12/a-simple-daemon-in-c/
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sysexits.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <getopt.h>
#include <libgen.h>
#include <glib.h>
#include <signal.h>
#include <libupower-glib/upower.h>

#include "version.h"
#include "globals.h"
#include "data_types.h"
#include "util.h"
#include "daemonize.h"
#include "upower-listener.h"
#include "scriptenv.h"


#ifdef GLIB_VERSION_2_36
/* g_type_init() deprecated since 2.36 */
static inline void batwatch_g_type_init(void) {}
#else
static inline void batwatch_g_type_init(void) { g_type_init(); }
#endif


static inline gboolean running_in_foreground(void) {
   return p_batwatch_globals->is_daemon ? FALSE: TRUE;
}


static void batwatch_catch_signal ( const int sig ) {
   char* env_backup[SCRIPT_ENV_VARCOUNT];
   gboolean signal_handled;

   signal_handled = FALSE;

   switch ( sig ) {
      case SIGHUP:
         /* might change in future */

         /* back up env vars */
         backup_battery_env_vars_into ( env_backup );

         check_batteries (
            p_batwatch_globals->upower_client, p_batwatch_globals
         );

         /* restore env vars */
         if ( restore_battery_env_vars ( env_backup ) != 0 ) {
            g_warning ( "failed to restore env vars!" );
         }
         free_battery_env_backup ( env_backup );

         /* done */
         /* signal_handled = TRUE; */
         break;

      case SIGINT:
      case SIGQUIT:
      case SIGTERM:
         /* quit main loop if possible, else exit here */
         /* signal_handled = TRUE; */

         if ( p_batwatch_globals != NULL ) {
            if ( p_batwatch_globals->main_loop != NULL ) {
               g_main_loop_quit ( p_batwatch_globals->main_loop );
            } else {
               g_warning ( "catch_signal: no main loop." );
            }
            if ( running_in_foreground() && sig == SIGINT ) {
               fprintf ( stdout, "\n" );
            }

         } else {
            g_warning ( "catch_signal: no globals." );
            exit ( EXIT_SUCCESS );
         }
         break;

      case SIGUSR1:
         /* reset script status, check batteries */

         /* back up env vars */
         backup_battery_env_vars_into ( env_backup );

         if (
            p_batwatch_globals != NULL && p_batwatch_globals->scripts != NULL
         ) {
            batwatch_globals_reset_scripts ( p_batwatch_globals );
            if ( p_batwatch_globals->upower_client != NULL ) {
               check_batteries (
                  p_batwatch_globals->upower_client, p_batwatch_globals
               );
               signal_handled = TRUE;
            }
         }

         /* restore env vars */
         if ( restore_battery_env_vars ( env_backup ) != 0 ) {
            g_warning ( "failed to restore env vars!" );
         }
         free_battery_env_backup ( env_backup );

         /* done */
         if ( signal_handled ) { break; }

      default:
         /* stub */
         g_warning ( "unhandled signal %d (%s)", sig, strsignal ( sig ) );
         break;
   }
}

static gboolean batwatch_signal_setup (
   struct batwatch_globals* const globals
) {
   struct sigaction my_sigaction;
   sigset_t         sigset_ignore;

   /* ignored signals */
   if (
      sigemptyset ( &sigset_ignore ) ||
      sigaddset ( &sigset_ignore, SIGCHLD ) ||
      sigaddset ( &sigset_ignore, SIGTSTP ) ||
      sigaddset ( &sigset_ignore, SIGTTOU ) ||
      sigaddset ( &sigset_ignore, SIGTTIN ) ||
      sigprocmask ( SIG_BLOCK, &sigset_ignore, NULL )
   ) {
      perror ( "signal-setup/ignore-set" );
      globals->exit_code = EX_SOFTWARE;
      return FALSE;
   }

   /* setup signal handler */
   my_sigaction.sa_flags   = 0 ;
   my_sigaction.sa_handler = batwatch_catch_signal;

   if (
      sigemptyset ( &my_sigaction.sa_mask ) ||
      sigaction ( SIGHUP,  &my_sigaction, NULL ) ||
      sigaction ( SIGINT,  &my_sigaction, NULL ) ||
      sigaction ( SIGQUIT, &my_sigaction, NULL ) ||
      sigaction ( SIGTERM, &my_sigaction, NULL ) ||
      sigaction ( SIGUSR1, &my_sigaction, NULL )
   ) {
      perror ( "signal-setup/sigaction" );
      globals->exit_code = EX_OSERR;
      return FALSE;
   }

   return TRUE;
}

/*
 * main loop
 */
static void main_run ( struct batwatch_globals* const globals ) {
   GError* my_error;

   my_error = NULL;

   if ( globals->upower_client != NULL ) {
      g_error ( "main_run(): globals->upower_client != NULL" );
      return; /* unreachable */
   } else if ( globals->main_loop != NULL ) {
      g_error ( "main_run(): globals->main_loop != NULL" );
      return; /* unreachable */
   }

   globals->upower_client = up_client_new();
   g_assert ( globals->upower_client != NULL );

   if ( up_client_enumerate_devices_sync (
      globals->upower_client, NULL, &my_error
   ) ) {
      g_signal_connect (
         globals->upower_client, "device-changed",
         G_CALLBACK(catch_upower_event), (gpointer*) globals
      );
      g_signal_connect (
         globals->upower_client, "device-added",
         G_CALLBACK(catch_upower_event_and_reset), (gpointer*) globals
      );
      g_signal_connect (
         globals->upower_client, "device-removed",
         G_CALLBACK(catch_upower_event_and_reset), (gpointer*) globals
      );

      check_batteries ( globals->upower_client, globals );
      globals->main_loop = g_main_loop_new ( NULL, FALSE );
      g_main_loop_run ( globals->main_loop );
   } else {
      g_error ( "error while enumerating devices: %s", my_error->message );
   }


   /* main loop returned, most likely due to SIGINT/SIGTERM */
   batwatch_globals_unset_main_loop_vars ( globals );
   if ( my_error != NULL ) { g_error_free ( my_error ); }
}


static void print_help_message (
   const char* const prog_name, FILE* const stream
) {
   fprintf (
      ( ( stream == NULL ) ? stdout: stream ),
      (
         /* --inhibit,-I */
         "Usage: %s [-h] [option...] [-T <percentage>] [-b <name>] -x <prog> {-[Tbx]...}\n"
         "\n"
         "required options (can be specified more than once):\n"
         "  -T, --threshold <percentage>  set activation threshold for all following --exe(s) [%.1f]\n"
         /* actually s/below --threshold/less or equal than --threshold/ */
         "  -x, --exe       <prog>        program to run if a battery's percentage is below --threshold\n"
         "  -b, --battery   <name>        restrict next --exe to <name>, e.g. 'BAT0'\n"
         "  -0, --no-args                 don't pass any args to the next --exe\n"
         "\n"
         "options:\n"
         "  -F,                           minimal energy (as percentage) a battery must have\n"
         "  --fallback-min  <percentage>   in order to be considered as fallback battery [%.1f]\n"
         "  -h, --help                    print this message and exit\n"
         "  -V, --version                 print the version and exit\n"
         "\n"
         "daemon options:\n"
         "  -N, --no-fork                 don't daemonize\n"
         "  -1, --stdout    <file>        redirect stdout  to <file> [disabled]\n"
         "  -2, --stderr    <file>        redirect stderr  to <file> [disabled]\n"
         "  -C, --rundir    <dir>         $$daemon run directory$$   ['/']\n"
         "  -p, --pidfile   <file>        write daemon pid to <file> [disabled]\n"
         "\n"
         "File paths must be absolute (or relative to --rundir) in daemon mode.\n"
      ),
      prog_name, DEFAULT_PERCENTAGE_THRESHOLD, DEFAULT_FALLBACK_PERCENTAGE
   );
}


int main ( const int argc, char* const* argv ) {
   static const struct option const long_options[] = {
      { "threshold",    required_argument, NULL, 'T' },
      { "exe",          required_argument, NULL, 'x' },
      { "battery",      required_argument, NULL, 'b' },
      { "fallback-min", required_argument, NULL, 'F' },
      { "no-fork",      no_argument,       NULL, 'N' },
      { "stdout",       required_argument, NULL, '1' },
      { "stderr",       required_argument, NULL, '2' },
      { "rundir",       required_argument, NULL, 'C' },
      { "pidfile",      required_argument, NULL, 'p' },
      { "help",         no_argument,       NULL, 'h' },
      { "version",      no_argument,       NULL, 'V' },
      { NULL,           no_argument,       NULL,  0  }
   };
   static const char* const short_options = "T:x:b:F:N1:2:C:p:hV";

   const char* const prog_name = basename(argv[0]);
   struct batwatch_globals globals;
   /* enum script_type script_type; */
   gint     i;
   gint     conv_err;
   gchar*   battery_restriction;
   gdouble  threshold;
   gboolean want_daemonize;


   batwatch_g_type_init();
   batwatch_init_globals ( &globals );

   /* script_type         = SCRIPT_TYPE_DEFAULT; */
   battery_restriction = NULL;
   threshold           = DEFAULT_PERCENTAGE_THRESHOLD;
   want_daemonize      = TRUE;


   /* logging */
   //g_log_set_handler ( NULL, G_LOG_LEVEL_MASK, g_log_default_handler, NULL );

   while (
      ( i = getopt_long (
         argc, argv, short_options, long_options, NULL
      ) ) != -1
   ) {
      switch ( i ) {
         case 'T':
            if ( ( conv_err = parse_percentage ( optarg, &threshold ) ) ) {
               fprintf ( stderr,
                  "--threshold '%s': %s\n", optarg, strerror ( conv_err )
               );
               globals.exit_code = EX_USAGE;
               goto main_exit;
            }
            break;

         case 'b':
            battery_restriction = optarg;
            break;

         case 'x':
            g_ptr_array_add ( globals.scripts,
               create_script_config (
                  optarg, threshold, battery_restriction,
                  SCRIPT_TYPE_DEFAULT
                  /* script_type */
               )
            );
            /* script_type         = SCRIPT_TYPE_DEFAULT; */
            battery_restriction = NULL;
            break;

         case 'F':
            if ( ( conv_err = parse_percentage (
               optarg, &(globals.fallback_min_percentage)
            ) ) ) {
               fprintf ( stderr,
                  "--fallback-min '%s': %s\n", optarg, strerror ( conv_err )
               );
               globals.exit_code = EX_USAGE;
               goto main_exit;
            }
            break;

         case 'N':
            want_daemonize = FALSE;
            break;

         case '1':
            globals.daemon_stdout_file = optarg;
            break;

         case '2':
            globals.daemon_stderr_file = optarg;
            break;

         case 'C':
            globals.rundir = optarg;
            break;

         case 'p':
            globals.pidfile = optarg;
            break;

         case 'h':
            print_help_message ( prog_name, NULL );
            goto main_exit;

         case 'V':
            printf ( "%s\n", BATWATCH_VERSION );
            goto main_exit;

         default:
            fprintf ( stderr, "unknown option: '%c' (%o)\n", i, i );
            globals.exit_code = EX_USAGE;
            goto main_exit;
      }
   }

   /* globals.scripts must be sorted */
   batwatch_globals_sort_scripts ( &globals );

   if ( optind < argc ) {
      print_help_message ( prog_name, stderr );
      fprintf ( stderr, "\n%s: Too many args. \n", prog_name );
      globals.exit_code = EX_USAGE;
      /* goto main_exit; */

   } else if ( globals.scripts->len < 1 ) {
      print_help_message ( prog_name, stderr );
      fprintf ( stderr,
         "\n%s: at least one --exe must be specified.\n", prog_name
      );
      globals.exit_code = EX_USAGE;
      /* goto main_exit; */

   } else if ( unset_battery_env_vars() != 0 ) {
      perror ( "unset battery env vars" );
      globals.exit_code = EX_SOFTWARE;
      /* got main_exit; */

   } else if ( want_daemonize ) {
      /* setup main loop for running as daemon */
      if (
         daemonize ( &globals ) && batwatch_signal_setup ( &globals )
      ) {
         main_run ( &globals );
      }
      /* else goto main_exit; */

   } else {
      /* setup main loop for running in foreground */
      umask ( S_IWGRP|S_IWOTH );
      /* chdir()? */

      if ( ! verbosely_close_fd ( STDIN_FILENO, stderr ) ) {
         globals.exit_code = EX_OSERR;
         /* goto main_exit; */
      } else if ( ! batwatch_signal_setup ( &globals ) ) {
         /* goto main_exit; */
      } else {
         /* run */
         main_run ( &globals );
      }
   }

main_exit:
   batwatch_tear_down_globals ( &globals );
   return globals.exit_code;
}
