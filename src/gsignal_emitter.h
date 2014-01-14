/*
 * gsignal_emitter.h
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

#ifndef _BATWATCH_GSIGNAL_EMITTER_H_
#define _BATWATCH_GSIGNAL_EMITTER_H_

#include <glib-object.h>

#include "gcc-compat.h"

/* https://developer.gnome.org/gobject/stable/howto-gobject.html */

enum BATWATCH_GSIGNALS {
   BATWATCH_GSIGNAL_RELOAD,
   BATWATCH_GSIGNAL_FORCE_RESET,

   BATWATCH_GSIGNAL_COUNT
};

/*
 * Type macros.
 */
#define BATWATCH_TYPE_SIGNAL_EMITTER             (batwatch_signal_emitter_get_type ())
#define BATWATCH_SIGNAL_EMITTER(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), BATWATCH_TYPE_SIGNAL_EMITTER, BatwatchSignalEmitter))
#define BATWATCH_IS_SIGNAL_EMITTER(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), BATWATCH_TYPE_SIGNAL_EMITTER))
#define BATWATCH_SIGNAL_EMITTER_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), BATWATCH_TYPE_SIGNAL_EMITTER, BatwatchSignalEmitterClass))
#define BATWATCH_IS_SIGNAL_EMITTER_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), BATWATCH_TYPE_SIGNAL_EMITTER))
#define BATWATCH_SIGNAL_EMITTER_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), BATWATCH_TYPE_SIGNAL_EMITTER, BatwatchSignalEmitterClass))

typedef struct _BatwatchSignalEmitter      BatwatchSignalEmitter;
typedef struct _BatwatchSignalEmitterClass BatwatchSignalEmitterClass;

struct _BatwatchSignalEmitter {
   GObject parent_instance;
};

struct _BatwatchSignalEmitterClass {
   GObjectClass parent_class;

   guint signal_ids[BATWATCH_GSIGNAL_COUNT];
};


GType batwatch_signal_emitter_get_type (void);

void batwatch_signal_emitter_emit (
   BatwatchSignalEmitter* self,
   const enum BATWATCH_GSIGNALS sig_id
) ATTRIBUTE_UNUSED;


BatwatchSignalEmitter* batwatch_signal_emitter_new(void);


#endif /* _BATWATCH_GSIGNAL_EMITTER_H_ */
