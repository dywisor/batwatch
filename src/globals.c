/*
 * globals.c
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
#include <libupower-glib/upower.h>

#include "globals.h"

struct batwatch_globals* p_batwatch_globals = NULL;

const double      DEFAULT_FALLBACK_PERCENTAGE    = 30.0;
const double      DEFAULT_PERCENTAGE_THRESHOLD   = 10.0;
const char* const SCRIPT_PERCENT_VAR_FMT         = "%.1f";
const int         SCRIPT_PERCENT_VAR_FMT_BUFSIZE = 7;
const char* const SCRIPT_TIME_VAR_FMT            = "%" G_GINT32_FORMAT;
const uint        BATTERY_COULD_BE_DISCHARGING   = (
   UP_DEVICE_STATE_DISCHARGING
);
