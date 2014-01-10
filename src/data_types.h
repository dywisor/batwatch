/*
 * data_types.h
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

#ifndef _BATWATCH_DATA_TYPES_H_
#define _BATWATCH_DATA_TYPES_H_

#include <glib.h>
#include <libgen.h>

enum script_type {
   SCRIPT_TYPE_DEFAULT        = 0,
   SCRIPT_TYPE_EXE_WITH_ARGS  = SCRIPT_TYPE_DEFAULT,
   SCRIPT_TYPE_EXE_NO_ARGS    = 1,

   SCRIPT_TYPE__BUILTIN_BEGIN = 40,
   /* builtin actions (low-prio TODO) */
   SCRIPT_TYPE__BUILTIN_END   = 40,
};

/*
 * script config/status object
 * - exe
 *     script path/name (or any other program)
 *
 * - "critical" range (threshold_low..threshold_high)
 *
 *     The script should only be run if the battery's remaining capacity
 *     (as percentage, 0.0..100.0) is within this range (low/high inclusive).
 *     threshold_low might be added in future.
 *
 *     Should be checked with percentage_in_critical_range() or
 *     battery_in_critical_range().
 *
 * - percentage_last_run:
 *     Any value < 0.0 means that the script should be run as soon as the
 *     battery's remaining_percent is within the critical range.
 *
 *     A value >= 0.0 indicates for which percentage the script has been run
 *     since the battery's remaining_percent entered the critical range.
 *
 *     Should be reset using reset_script_status() once the battery leaves
 *     the threshold range.
 *
 *     Can be checked with script_check_has_been_run().
 *
 * - battery_name:
 *     used to restrict script execution to a single battery, referenced
 *     by name. If set to NULL, the script is run for the _first_ battery
 *     that meets the other constraints (threshold, that is).
 */
struct script_config {
   gdouble          threshold_high;
   /* gdouble threshold_low; // not implemented */
   gdouble          percentage_last_run;
   const gchar*     exe;
   const gchar*     battery_name;
   enum script_type type;
};

struct battery_info {
   const gchar* name;
   const gchar* sysfs_path;
   gdouble      remaining_percent;
};



static inline struct script_config* create_script_config (
   const gchar*  const exe,
   const gdouble threshold_high,
   const gchar*  const battery_name,
   const enum script_type type
) {
   struct script_config* pscript;

   pscript  = g_malloc ( sizeof *pscript );
   *pscript = (struct script_config) {
      .threshold_high      = threshold_high,
      .percentage_last_run = -1.0,
      .exe                 = exe,
      .battery_name        = battery_name,
   };

   return pscript;
}

static inline struct battery_info* create_battery_info (
   const gchar* sysfs_path,
   gdouble      remaining_percent
) {
   struct battery_info* pbat;

   pbat  = g_malloc ( sizeof *pbat );
   *pbat = (struct battery_info) {
      .name              = basename ( (gchar*) sysfs_path ),
      .sysfs_path        = sysfs_path,
      .remaining_percent = remaining_percent,
   };

   return pbat;
}



static inline gint compare_script_config (
   struct script_config* const a,
   struct script_config* const b
) {
   return g_strcmp0 ( a->battery_name, b->battery_name );
}

static inline gint compare_battery_status (
   struct battery_info* const a,
   struct battery_info* const b
) {
   return g_strcmp0 ( a->name, b->name );
}


static inline void reset_script_status (
   struct script_config* const pscript
) {
   pscript->percentage_last_run = -1.0;
}


static inline gboolean script_check_has_been_run (
   const struct script_config* const pscript,
   const struct battery_info*  const pbat
) {
   /*
    * TODO, additional checks (if pbat != NULL)
    * * battery state, example scenario:
    * (a) battery enters crit range -> script is run
    * (b) user plugs in AC          -> nothing happens
    * (c) user plugs out AC, but battery still in crit range
    *     -> nothing happens(!)
    */
   return ( pscript->percentage_last_run < 0.0 ) ? FALSE : TRUE;
}

static inline void script_mark_as_run (
   struct script_config* const pscript,
   const struct battery_info* const pbat
) {
   pscript->percentage_last_run = pbat->remaining_percent;
}

static inline gboolean percentage_in_critical_range (
   const struct script_config* const pscript,
   const gdouble percentage
) {
   return ( percentage > pscript->threshold_high ) ? FALSE: TRUE;
}

static inline gboolean battery_in_critical_range (
   const struct script_config* const pscript,
   const struct battery_info*  const pbat
) {
   return percentage_in_critical_range ( pscript, pbat->remaining_percent );
}

static inline gboolean script_can_handle_battery (
   const struct script_config* const pscript,
   const struct battery_info* const pbat
) {
   return (
      ( pscript->battery_name == NULL ) ||
      ( g_strcmp0 ( pscript->battery_name, pbat->name ) == 0 )
   ) ? TRUE: FALSE;
}


#endif /* _BATWATCH_DATA_TYPES_H_ */
