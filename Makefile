unexport LC_ALL
LC_COLLATE=C
LC_NUMERIC=C
export LC_COLLATE LC_NUMERIC

f_uninstall_file = \
	if test -e $(1) || test -h $(1); then rm -v -- $(1); fi

DESTDIR    :=
DESTPREFIX := /usr
BIN        := $(DESTDIR)/$(DESTPREFIX)/bin
SUDOERS_D  := $(DESTDIR)/etc/sudoers.d

# default -W... flags for CFLAGS
_WARNFLAGS := -Wall -Wextra -Werror -Wno-unused-parameter
_WARNFLAGS += -Wwrite-strings -Wdeclaration-after-statement
_WARNFLAGS += -Wtrampolines
_WARNFLAGS += -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations
_WARNFLAGS += -pedantic

PKG_CONFIG     ?= pkg-config
CFLAGS         ?= -O2 -pipe $(_WARNFLAGS)
CPPFLAGS       ?=
CC             := gcc
LDFLAGS        ?= -Wl,-O1 -Wl,--as-needed
TARGET_CC      := $(CROSS_COMPILE)$(CC)
EXTRA_CFLAGS   ?=
X_EXTRACT_DEF  := $(CURDIR)/scripts/header_extract_def.sh
X_GEN_V_HEADER := $(CURDIR)/scripts/gen_version_header.sh
X_SCANELF      := scanelf

O              := $(CURDIR)/build
SRCDIR         := $(CURDIR)/src
COMMON_OBJECTS := \
	$(addprefix $(O)/,globals.o daemonize.o run-script.o upower-listener.o)

BATWATCH_OBJECTS := $(addprefix $(O)/,main.o)
BATWATCH_NAME    := batwatch

_LAZY_UPOWER_FLAGS := $(shell $(PKG_CONFIG) --cflags --libs upower-glib)

CFLAGS   += $(EXTRA_CFLAGS)
CC_OPTS  :=
CC_OPTS  += -std=gnu99
# _GNU_SOURCE should be set
CPPFLAGS += -D_GNU_SOURCE

COMPILE_C = $(TARGET_CC) $(CC_OPTS) $(_LAZY_UPOWER_FLAGS) $(CPPFLAGS) $(CFLAGS) -c
LINK_O    = $(TARGET_CC) $(CC_OPTS) $(_LAZY_UPOWER_FLAGS) $(CPPFLAGS) $(LDFLAGS)

PHONY :=

PHONY += all
all: $(BATWATCH_NAME)

PHONY += install-all
install-all: install install-contrib

PHONY += uninstall-all
uninstall-all: uninstall uninstall-contrib

$(CURDIR)/$(BATWATCH_NAME): $(COMMON_OBJECTS) $(BATWATCH_OBJECTS)
	$(LINK_O) $^ -o $@

$(BATWATCH_NAME): $(CURDIR)/$(BATWATCH_NAME)

$(O):
	mkdir -p $(O)

$(O)/%.o: $(SRCDIR)/%.c | $(O)
	$(COMPILE_C) $< -o $@

PHONY += version
version: $(X_EXTRACT_DEF) | $(SRCDIR)/version.h
	@$(X_EXTRACT_DEF) $(SRCDIR)/version.h BATWATCH_VERSION

PHONY += setver
setver: $(X_GEN_V_HEADER) FORCE
	$(X_GEN_V_HEADER) "$(VER)" "$(SRCDIR)/version.h"

PHONY += clean
clean:
	-rm -f -- $(COMMON_OBJECTS) $(BATWATCH_OBJECTS) $(CURDIR)/$(BATWATCH_NAME)
	-rmdir $(O)

PHONY += install
install:
	install -d -m 0755 -- $(BIN)
	install -m 0755 -t $(BIN) -- $(CURDIR)/$(BATWATCH_NAME)

PHONY += uninstall
uninstall:
	$(call f_uninstall_file,$(BIN)/$(BATWATCH_NAME))

PHONY += install-contrib
install-contrib: $(CURDIR)/contrib/$(BATWATCH_NAME).sudoers
	install -d -m 0750 -- $(SUDOERS_D)
	install -m 0440    -- \
		$(CURDIR)/contrib/$(BATWATCH_NAME).sudoers $(SUDOERS_D)/$(BATWATCH_NAME)

PHONY += uninstall-contrib
uninstall-contrib:
	$(call f_uninstall_file,$(SUDOERS_D)/$(BATWATCH_NAME))

PHONY += stat
stat: $(BATWATCH_NAME)
	@echo 'size:'
	@size $(CURDIR)/$(BATWATCH_NAME)*
	@echo
	@echo 'scanelf:'
	@$(X_SCANELF) -n $(CURDIR)/$(BATWATCH_NAME)*

PHONY += help
help:
	@echo  'Targets:'
	@echo  '  clean              - Remove generated files'
	@echo  '  all                - Build     all targets marked with [*]'
	@echo  '  install-all        - Install   all targets marked with [+]'
	@echo  '  uninstall-all      - Uninstall all targets marked with [-]'
	@echo  '  version            - Print the version (to stdout)'
	@echo  '* $(BATWATCH_NAME)           - Build $(BATWATCH_NAME)'
	@echo  '+ install            - Install $(BATWATCH_NAME) to DESTDIR/DESTPREFIX'
	@echo  '                       (default: $(DESTDIR)$(DESTPREFIX))'
	@echo  '- uninstall          - (see install)'
	@echo  '+ install-contrib    - Install non-essential files to DESTDIR'
	@echo  '                          (sudoers config)'
ifeq ($(DESTDIR),)
	@echo  '                       (default: /)'
else
	@echo  '                       (default: $(DESTDIR))'
endif
	@echo  '- uninstall-contrib  - (see install-contrib)'
	@echo  ''
	@echo  'Misc targets (devel/release helpers):'
	@echo  '  setver             - Set version to VER (should be done before compiling)'
	@echo  '  stat               - size(1), scanelf(1) [implies $(BATWATCH_NAME)]'
	@echo  ''
	@echo  '  make O=<dir> [targets] Locate all intermediate output files in <dir>'
	@echo  '                          (default: $(O))'
	@echo  ''
	@echo  'Install targets do not imply any build target.'
	@echo  'Run "make" or "make all" before trying to install $(BATWATCH_NAME).'

PHONY += FORCE
FORCE:

.PHONY: $(PHONY)