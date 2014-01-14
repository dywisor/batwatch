/*
 * globals.h
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

#ifndef _BATWATCH_GLOBALS_H_
#define _BATWATCH_GLOBALS_H_

#include <stdlib.h>
#include <unistd.h>
#include <glib.h>
#include <glib-object.h>
#include <libupower-glib/upower.h>

#include "data_types.h"
#include "gsignal_emitter.h"

/*
enum {
   BATWATCH_EVENT_NONE = 0,
   BATWATCH_EVENT_CHECK_BATTERIES = 1<<0,
   ...
   BATWATCH_EVENT_MASK_DEFAULT = BATWATCH_EVENT_CHECK_BATTERIES,
};
*/


struct batwatch_globals {
   /* GPtrArray<struct script_config*> */
   BatwatchSignalEmitter* signal_emitter;
   GPtrArray*     scripts;
   gboolean       scripts_dirty;
   gboolean       is_daemon;
   const gchar*   daemon_stdout_file;
   const gchar*   daemon_stderr_file;
   const gchar*   pidfile;
   gint           pidfile_fd;
   const gchar*   rundir;
   guint          exit_code;
   gdouble        fallback_min_percentage;
   GMainLoop*     main_loop;
   UpClient*      upower_client;
   /* gint           event_mask; */
   gint x;
};


extern const double      DEFAULT_FALLBACK_PERCENTAGE;
extern const double      DEFAULT_PERCENTAGE_THRESHOLD;
extern const char* const SCRIPT_PERCENT_VAR_FMT;
extern const int         SCRIPT_PERCENT_VAR_FMT_BUFSIZE;
extern const char* const SCRIPT_TIME_VAR_FMT;
extern const uint        BATTERY_COULD_BE_DISCHARGING;

/* for signal handling */
extern struct batwatch_globals* p_batwatch_globals;


static inline void batwatch_init_globals (
   struct batwatch_globals* const globals
) {
   globals->signal_emitter          = batwatch_signal_emitter_new();
   g_object_ref ( globals->signal_emitter );
   globals->scripts                 = g_ptr_array_new();
   globals->scripts_dirty           = FALSE;
   globals->is_daemon               = FALSE;
   globals->daemon_stdout_file      = NULL;
   globals->daemon_stderr_file      = NULL;
   globals->pidfile                 = NULL;
   globals->pidfile_fd              = -2;
   globals->rundir                  = "/";
   globals->exit_code               = EXIT_SUCCESS;
   globals->fallback_min_percentage = DEFAULT_FALLBACK_PERCENTAGE;
   globals->main_loop               = NULL;
   globals->upower_client           = NULL;
   /* globals->event_mask              = BATWATCH_EVENT_MASK_DEFAULT; */

   if ( p_batwatch_globals == NULL ) {
      p_batwatch_globals = globals;
   }
}

static inline void batwatch_globals_unset_main_loop_vars (
   struct batwatch_globals* const globals
) {
   if ( globals->main_loop != NULL ) {
      g_main_loop_unref ( globals->main_loop );
      globals->main_loop = NULL;
   }

   if ( globals->upower_client != NULL ) {
      g_object_unref ( globals->upower_client );
      globals->upower_client = NULL;
   }
}

static inline void batwatch_tear_down_globals (
   struct batwatch_globals* const globals
) {
   if ( p_batwatch_globals == globals ) {
      p_batwatch_globals = NULL;
   }

   batwatch_globals_unset_main_loop_vars ( globals );

   if ( globals->signal_emitter != NULL ) {
      g_object_unref ( globals->signal_emitter );
      globals->signal_emitter = NULL;
   }

   if ( globals->scripts != NULL ) {
      g_ptr_array_unref ( globals->scripts );
      globals->scripts = NULL;
   }

   if ( globals->pidfile_fd >= 0 ) {
      close ( globals->pidfile_fd );
   }


}

static inline void batwatch_globals_reset_scripts (
   struct batwatch_globals* const globals
) {
   g_ptr_array_foreach (
      globals->scripts, (GFunc) reset_script_status, NULL
   );
   globals->scripts_dirty = FALSE;
}

static inline void batwatch_globals_sort_scripts (
   struct batwatch_globals* const globals
) {
   g_ptr_array_sort (
      globals->scripts, (GCompareFunc) compare_script_config
   );
}

#endif /* _BATWATCH_GLOBALS_H_ */
