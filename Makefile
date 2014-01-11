unexport LC_ALL
LC_COLLATE=C
LC_NUMERIC=C
export LC_COLLATE LC_NUMERIC

f_uninstall_file = \
	if test -e $(1) || test -h $(1); then rm -v -- $(1); fi

DESTDIR     :=
BIN         := $(DESTDIR)/usr/bin
SUDOERS_D   := $(DESTDIR)/etc/sudoers.d
BASHCOMPDIR := $(DESTDIR)/usr/share/bash-completions/completions

OPENRC_INIT_D := $(DESTDIR)/etc/init.d
OPENRC_CONF_D := $(DESTDIR)/etc/conf.d
SYSV_INIT_D   := $(DESTDIR)/etc/init.d
SYSV_CONF_D   := $(DESTDIR)/etc/default

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
X_GEN_INIT     := $(CURDIR)/scripts/gen_init_script.sh
X_SCANELF      := scanelf

O              := $(CURDIR)/build
SRCDIR         := $(CURDIR)/src
CONTRIB_DIR    := $(CURDIR)/contrib
INITSCRIPT_DIR := $(CONTRIB_DIR)/init-scripts

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

$(INITSCRIPT_DIR)/%: $(INITSCRIPT_DIR)/%.in $(X_GEN_INIT)
	$(X_GEN_INIT) "$<" "$@"



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
install-contrib: $(CONTRIB_DIR)/$(BATWATCH_NAME).sudoers
	install -d -m 0750 -- $(SUDOERS_D)
	install -d -m 0755 -- $(BASHCOMPDIR)
	install -m 0440    -- \
		$(CONTRIB_DIR)/$(BATWATCH_NAME).sudoers \
		$(SUDOERS_D)/$(BATWATCH_NAME)
	install -m 0644    -- \
		$(CONTRIB_DIR)/$(BATWATCH_NAME).bashcomp \
		$(BASHCOMPDIR)/$(BATWATCH_NAME)

PHONY += uninstall-contrib
uninstall-contrib:
	$(call f_uninstall_file,$(SUDOERS_D)/$(BATWATCH_NAME))
	$(call f_uninstall_file,$(BASHCOMPDIR)/$(BATWATCH_NAME))



PHONY += install-sysvinit
install-sysvinit:
	install -d -m 0755 -- $(SYSV_INIT_D)
	insall -m 0755 -- \
		$(INITSCRIPT_DIR)/$(BATWATCH_NAME).init $(SYSV_INIT_D)/$(BATWATCH_NAME)

PHONY += uinstall-sysvinit
uninstall-sysvinit:
	$(call f_uninstall_file,$(SYSV_INIT_D)/$(BATWATCH_NAME))



PHONY += install-openrc
install-openrc:
	install -d -m 0755 -- $(OPENRC_INIT_D)
	install -m 0755 -- \
		$(INITSCRIPT_DIR)/$BATWATCH_NAME).openrc $(OPENRC_INIT_D)/$(BATWATCH_NAME)

PHONY += uninstall-openrc
uninstall-openrc:
	$(call f_uninstall_file,$(OPENRC_INIT_D)/$(BATWATCH_NAME))



PHONY += stat
stat: $(BATWATCH_NAME)
	@echo 'size:'
	@size $(CURDIR)/$(BATWATCH_NAME)*
	@echo
	@echo 'scanelf:'
	@$(X_SCANELF) -n $(CURDIR)/$(BATWATCH_NAME)*



PHONY += init-scripts
init-scripts: \
	$(INITSCRIPT_DIR)/$(BATWATCH_NAME).init \
	$(INITSCRIPT_DIR)/$(BATWATCH_NAME).openrc



PHONY += help
help:
	@echo  'Targets:'
	@echo  '  clean              - Remove generated files'
	@echo  '  all                - Build     all targets marked with [*]'
	@echo  '  install-all        - Install   all targets marked with [+]'
	@echo  '  uninstall-all      - Uninstall all targets marked with [-]'
	@echo  '  version            - Print the version (to stdout)'
	@echo  '* $(BATWATCH_NAME)           - Build $(BATWATCH_NAME)'
	@echo  '+ install            - Install $(BATWATCH_NAME) to DESTDIR'
ifeq ($(DESTDIR),)
	@echo  '                       (default: /)'
else
	@echo  '                       (default: $(DESTDIR))'
endif
	@echo  '- uninstall          -'
	@echo  '+ install-contrib    - Install non-essential files to DESTDIR'
	@echo  '                       * sudo config to SUDOERS_D'
	@echo  '                         (default: $(SUDOERS_D))'
	@echo  '                       * bash completion to BASHCOMPDIR'
	@echo  '                         (default: $(BASHCOMPDIR))'
ifeq ($(DESTDIR),)
	@echo  '                       (default: /)'
else
	@echo  '                       (default: $(DESTDIR))'
endif
	@echo  '- uninstall-contrib  -'
	@echo  ''
	@echo  'Init script/config install targets:'
	@echo  '  install-sysvinit   - SysVinit ($(SYSV_INIT_D), $(SYSV_CONF_D))'
	@echo  '  uninstall-sysvinit -'
	@echo  '  install-openrc     - OpenRC ($(OPENRC_INIT_D), $(OPENRC_CONF_D))'
	@echo  '  uninstall-openrc   -'
#	@echo  '! install-systemd    - systemd [NOT AVAILABLE]'
#	@echo  '! uninstall-systemd  -'
#	@echo  '! install-upstart    - Upstart [NOT AVAILABLE]'
#	@echo  '! uninstall-upstart  -'
	@echo  ''
	@echo  'Misc targets (devel/release helpers):'
	@echo  '  setver             - Set version to VER (should be done before compiling)'
	@echo  '  init-scripts       - Regenerate init scripts'
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
