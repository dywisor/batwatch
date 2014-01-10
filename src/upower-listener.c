/*
 * upower-listener.c
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
#include <glib.h>
#include <libupower-glib/upower.h>

/* #includes<> probably not necessary */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
/* end #includes<> probably not necessary */


#include "upower-listener.h"
#include "data_types.h"
#include "globals.h"
#include "run-script.h"


static inline void log_battery_found (
   const struct battery_info* const pbat,
   const char* const description
) {
   g_debug (
      "found %s battery '%s' with %.1f%% energy (%s)",
      description, pbat->name, pbat->remaining_percent, pbat->sysfs_path
   );
}

/*
 * run_scripts_as_necessary()
 *
 * $$DESCRIPTION$$
 *
 * Returns TRUE if there is any script marked as "has been run" (whether
 * executed by this function call or a previous one), else FALSE.
 * This value gets also stored in globals->scripts_dirty.
 *
 * Important:
 *  batteries_discharging and globals->script smust be sorted before
 *  calling this function.
 */
static gboolean run_scripts_as_necessary (
   struct batwatch_globals* const globals,
   GPtrArray*               const batteries_discharging,
   struct battery_info*     const fallback_battery
);


/*
 * default event handler
 *
 * Calls check_batteries() if the device in question is a battery.
 */
extern void catch_upower_event (
   UpClient* const client, UpDevice* const dev,
   struct batwatch_globals* const globals
) {
   UpDeviceKind dev_type;
   g_object_get ( dev, "kind", &dev_type, NULL );
   if ( dev_type == UP_DEVICE_KIND_BATTERY ) {
      check_batteries ( client, globals );
   }
}

/*
 * resetting event handler
 *
 * Resets all scripts associated with the given device if it is a battery
 * and calls check_batteries() afterwards.
 *
 * TODO (multibat)
 */
extern void catch_upower_event_and_reset (
   UpClient* const client, UpDevice* const dev,
   struct batwatch_globals* const globals
) {
   /* reset scripts that could handle %dev IFF <dev is a battery> AND ... */
   fprintf ( stderr, "catch_upower_event_and_reset(): stub\n" );
   catch_upower_event ( client, dev, globals );
}


/*
 * The actual work function.
 *
 * Collects battery information and determines which scripts need to be run.
 *
*/
extern void check_batteries (
   UpClient* const upower_client,
   struct batwatch_globals* const globals
) {
   /* GPtrArray<UpDevice*> */
   GPtrArray*            devices;
   /* GPtrArray<struct battery_info*> */
   GPtrArray*            batteries_discharging;
   UpDevice*             dev;
   UpDeviceKind          dev_type;
   UpDeviceState         dev_state;
   gboolean              is_present;
   gdouble               percentage;
   const gchar*          sysfs_path;
   /* num_batteries used for logging only */
   guint                 num_batteries;
   guint                 k;
   struct battery_info*  pbat;
   struct battery_info*  fallback_battery;


   g_debug  ( "check_batteries()" );
   g_assert ( upower_client == globals->upower_client );

   /* get device list from upower */
   devices = up_client_get_devices ( globals->upower_client );

   if ( devices != NULL ) {
      /* populate batteries_discharging */
      batteries_discharging = g_ptr_array_new();
      fallback_battery      = NULL;
      num_batteries         = 0;

      for ( k = 0; k < devices->len; k++ ) {
         dev = g_ptr_array_index ( devices, k );
         g_object_get (
            dev,
            "kind",        &dev_type,
            "state",       &dev_state,
            "is-present",  &is_present,
            "percentage",  &percentage,
            "native-path", &sysfs_path,
            NULL
         );

         if ( dev_type == UP_DEVICE_KIND_BATTERY ) {
            g_assert ( percentage >= 0.0 );

            /* add dev to batteries_discharging if it _could_ be discharging */
            if (
               ( dev_state & BATTERY_COULD_BE_DISCHARGING ) ||
               ( is_present && ( dev_state == UP_DEVICE_STATE_UNKNOWN ) )
            ) {
               pbat = create_battery_info ( sysfs_path, percentage );
               log_battery_found ( pbat, "discharging" );
               g_ptr_array_add ( batteries_discharging, pbat );

               pbat = NULL;

            } else if (
               ( is_present ) &&
               ( percentage >= globals->fallback_min_percentage ) &&
               (
                  ( fallback_battery == NULL ) ||
                  ( percentage > fallback_battery->remaining_percent )
               )
            ) {
               /* remember %dev fallback battery */
               if ( fallback_battery != NULL ) {
                  g_free ( fallback_battery );
               }
               fallback_battery = create_battery_info (
                  sysfs_path, percentage
               );
               log_battery_found ( fallback_battery, "fallback" );
            }

            num_batteries++;
         } /* end if is a battery */
      }

      g_debug ( "found %d batteries out of which %d are discharging.",
         num_batteries, batteries_discharging->len
      );

      /* let's see what needs to be run */
      if ( batteries_discharging->len > 0 ) {
         /*
          * sort batteries_discharging, required by run_scripts_as_necessary()
          */
         g_ptr_array_sort (
            batteries_discharging, (GCompareFunc) compare_battery_status
         );

         run_scripts_as_necessary (
            globals, batteries_discharging, fallback_battery
         );

      } else if ( globals->scripts_dirty ) {
         /* sets scripts_dirty */
         batwatch_globals_reset_scripts ( globals );
      }


      g_ptr_array_unref ( batteries_discharging );
      g_ptr_array_unref ( devices );
   } /* end if devices */
}


/*
 * run_scripts_as_necessary()
 *
 * $$DESCRIPTION$$
 *
 * Returns TRUE if there is any script marked as "has been run" (whether
 * executed by this function call or a previous one), else FALSE.
 * This value gets also stored in globals->scripts_dirty.
 *
 * Important:
 *  batteries_discharging and globals->script smust be sorted before
 *  calling this function.
 */
static gboolean run_scripts_as_necessary (
   struct batwatch_globals* const globals,
   GPtrArray*               const batteries_discharging,
   struct battery_info*     const fallback_battery
) {
   guint                 k, j;
   gboolean              any_script_dirty;
   struct script_config* pscript;
   struct battery_info*  pbat;


   /*
    * iterate over globals->scripts, comparing them with the
    * list of discharging batteries and run scripts as necessary
    *
    * script needs to be run <=> (
    *    script's battery is present and its capacity is less or
    *    equal than the activation threshold
    * ) AND (
    *    script has not already been run, which is determined
    *    by checking percentage_last_run
    * )
    *
    * Likewise, reset script->percentage_last_run IFF the script's
    * battery is missing or its capacity is higher than the activation
    * threshold.
    */

   /*
    * any_script_dirty <=> have any script in globals->scripts
    *    where percentage_last_run >= 0.0
    */
   any_script_dirty = FALSE;

   j    = 0;
   pbat = g_ptr_array_index ( batteries_discharging, j );

   for (
      k = 0; (
         k < globals->scripts->len && j < batteries_discharging->len
      ); k++
   ) {
      pscript = g_ptr_array_index ( globals->scripts, k );

      /*
       * fast-forward unknown batteries,
       * assuming that both batteries_discharging and globals->scripts
       * are sorted (by the same key (name, currently))
       */
      while (
         ( j < batteries_discharging->len ) &&
         ( script_can_handle_battery ( pscript, pbat ) == 0 )
      ) {
         if ( ++j < batteries_discharging->len ) {
            pbat = g_ptr_array_index ( batteries_discharging, j );
         } else {
            pbat = NULL;
         }
      }

      if ( j >= batteries_discharging->len ) {
         /* script cannot handle battery */
         reset_script_status ( pscript );
      } else if ( ! battery_in_critical_range ( pscript, pbat ) ) {
         /* remaining_percent not in critical range */
         /* mark the script as "not run" */
         g_debug (
            "reset script %s:%s -- percentage not in critical range",
            pbat->name, pscript->exe
         );
         reset_script_status ( pscript );
      } else if ( script_check_has_been_run ( pscript, pbat ) ) {
         /* script has already been called */
         g_debug (
            "script %s:%s has already been run.",
            pbat->name, pscript->exe
         );
         any_script_dirty = TRUE;

      } else {
         /* run script */
         run_script ( pscript, pbat, fallback_battery );
         any_script_dirty = TRUE;
      }
   }

   /* reset remaining script configs as there's no battery for them */
   for ( ; k < globals->scripts->len; k++ ) {
      reset_script_status ( g_ptr_array_index ( globals->scripts, k ) );
   }


   /* done */
   globals->scripts_dirty = any_script_dirty;
   return any_script_dirty;
}
