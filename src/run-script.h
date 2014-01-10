/*
 * run-script.h
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

#ifndef _BATWATCH_RUN_SCRIPT_H_
#define _BATWATCH_RUN_SCRIPT_H_

#include <unistd.h>
/* #include <glib.h> */

#include "data_types.h"

void run_script (
         struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
);

pid_t run_script_async (
         struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
);

/*
gboolean run_script_sync (
         struct script_config* const script,
   const struct battery_info*  const battery,
   const struct battery_info*  const fallback_battery
);
*/

#endif
