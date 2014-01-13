/*
 * scriptenv.h
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

#ifndef _SCRIPTENV_H_
#define _SCRIPTENV_H_

#if SCRIPTENV_DEBUG
#include <stdio.h>
#endif

#include "data_types.h"

/* mini-howto for adding new env vars:
 *
 * (a) global env vars (not depending on runtime/battery information)
 *     should be be set in main.c -- no need to do this more than once
 *
 * (b) if additional battery information is necessary, add a data field
 *     to "struct battery_info" AND create_battery_info() in data_types.h,
 *     and read/initialize the data in upower-listener.c->check_batteries()
 *
 *     Run "make batlow" to verify your changes
 *     (as far as the compiler can tell you about that)
 *
 * *Then*:
 *
 * (c) add a SCRIPT_ENV_INDEX_<sth> entry with a *short* description
 *     to the enum below, *before* SCRIPT_ENV_VARCOUNT
 *
 * (d) Add an entry containing the env var's name to SCRIPT_ENV_VARNAMES
 *     in scriptenv.c:
 *       [SCRIPT_ENV_INDEX_<sth>] = "MY_ENV_VAR",
 *
 * (e) create the env var in set_battery_env_vars() (scriptenv.c):
 *
 *      scriptenv_setenv ( SCRIPT_ENV_INDEX_<sth>, <str>|NULL, &ret );
 *
 *     (NULL sets the var to "")
 *     Make sure to set the var in any case (or unconditionally), unless
 *     your really want latch behavior.
 *
 *
 * backup_battery_env_vars_into(), restore_battery_env_vars(),
 * free_battery_env_backup() automatically inherit your changes.
*/

enum {
   /* the battery's name / sysfs path / percentage / remaining running time */
   SCRIPT_ENV_INDEX_BATNAME,
   SCRIPT_ENV_INDEX_BATPATH,
   SCRIPT_ENV_INDEX_BATPERC,
   SCRIPT_ENV_INDEX_BATTIME,

   /* the fallback battery's name / path / perc / charging time / status */
   SCRIPT_ENV_INDEX_FBATNAME,
   SCRIPT_ENV_INDEX_FBATPATH,
   SCRIPT_ENV_INDEX_FBATPERC,
   SCRIPT_ENV_INDEX_FBATTIME,
   SCRIPT_ENV_INDEX_FBATSTATE,

   /* number of elements -- last entry! */
   SCRIPT_ENV_VARCOUNT
};

extern const char* SCRIPT_ENV_VARNAMES[SCRIPT_ENV_VARCOUNT];


extern int unset_battery_env_vars(void);

extern int set_battery_env_vars (
   const struct battery_info* const battery,
   const struct battery_info* const fallback_battery
);

extern void backup_battery_env_vars_into ( char* dest [SCRIPT_ENV_VARCOUNT] );
extern int  restore_battery_env_vars     ( char* src  [SCRIPT_ENV_VARCOUNT] );
extern void free_battery_env_backup      ( char* bak  [SCRIPT_ENV_VARCOUNT] );


#if SCRIPTENV_DEBUG
static inline void scriptenv_test_backup_restore(void) {
   char* bak[SCRIPT_ENV_VARCOUNT];

   backup_battery_env_vars_into ( bak );
   if ( restore_battery_env_vars ( bak ) != 0 ) {
      fprintf(stderr, "env-restore: fail\n" );
   } else {
      fprintf(stderr, "env-restore: success\n" );
   }
   free_battery_env_backup ( bak );
}
#endif

#endif /* _SCRIPTENV_H_ */
