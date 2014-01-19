/*
 * upower-listener.h
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

#ifndef _BATWATCH_UPOWER_LISTENER_H_
#define _BATWATCH_UPOWER_LISTENER_H_

#include <libupower-glib/upower.h>

#include "globals.h"

/*
 * minimal interval for calling check_batteries(), seconds (per event!)
 */
#ifndef BW_EVENT_MIN_INTERVAL
#define BW_EVENT_MIN_INTERVAL 1.15
#endif

void catch_upower_event_device_changed (
   UpClient* const client, UpDevice* const dev,
   struct batwatch_globals* const globals
);

void catch_upower_event_device_added (
   UpClient* const client, UpDevice* const dev,
   struct batwatch_globals* const globals
);

void catch_upower_event_device_removed (
   UpClient* const client, UpDevice* const dev,
   struct batwatch_globals* const globals
);

void check_batteries (
   UpClient* const upower_client,
   struct batwatch_globals* const globals
);

#endif /* _BATWATCH_UPOWER_LISTENER_H_ */
