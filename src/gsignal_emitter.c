/*
 * gsignal_emitter.c
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

#include "gsignal_emitter.h"

BatwatchSignalEmitter* batwatch_signal_emitter_new(void) {
   return g_object_new ( BATWATCH_TYPE_SIGNAL_EMITTER, NULL );
}


G_DEFINE_TYPE ( BatwatchSignalEmitter, batwatch_signal_emitter, G_TYPE_OBJECT )


static void batwatch_signal_emitter_class_init (
   BatwatchSignalEmitterClass* klass
) {
   klass->signal_ids [BATWATCH_GSIGNAL_RELOAD] = g_signal_new (
      "batwatch-reload",
      G_TYPE_FROM_CLASS ( klass ),
      G_SIGNAL_RUN_FIRST|G_SIGNAL_NO_RECURSE,
      0, NULL, NULL, NULL, G_TYPE_NONE, 0, NULL
   );

   klass->signal_ids [BATWATCH_GSIGNAL_FORCE_RESET] = g_signal_new (
      "batwatch-force-reset",
      G_TYPE_FROM_CLASS ( klass ),
      G_SIGNAL_RUN_FIRST|G_SIGNAL_NO_RECURSE,
      0, NULL, NULL, NULL, G_TYPE_NONE, 0, NULL
   );
}

static void batwatch_signal_emitter_init (
   BatwatchSignalEmitter* self
) {
}

void batwatch_signal_emitter_emit (
   BatwatchSignalEmitter* self,
   const enum BATWATCH_GSIGNALS sig_id
) {
   g_signal_emit (
      G_OBJECT ( self ),
      BATWATCH_SIGNAL_EMITTER_GET_CLASS ( self )->signal_ids[sig_id],
      0
   );
}
