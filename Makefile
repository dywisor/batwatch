unexport LC_ALL
LC_COLLATE=C
LC_NUMERIC=C
export LC_COLLATE LC_NUMERIC

f_uninstall_file = \
	if test -e $(1) || test -h $(1); then rm -v -- $(1); fi

f_which  = $(shell which $(1) 2>/dev/null)
f_getver = $(shell \
	$(X_EXTRACT_DEF) $(SRCDIR)/version.h BATWATCH_VERSION 2>/dev/null \
)
f_gen_checksums = ( \
	sha256sum $(1) > $(1).sha256 && sha512sum $(1) > $(1).sha512 \
)


X_SH   := $(call f_which,sh)
#X_ASH  := $(call f_which,ash)
X_BASH := $(call f_which,bash)
X_DASH := $(call f_which,dash)


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
X_GEN_SHLIBCC  := $(CURDIR)/scripts/gen_shlib_script.sh
X_SCANELF      := scanelf

O              := $(CURDIR)/build
SRCDIR         := $(CURDIR)/src
DISTDIR        := $(CURDIR)/dist
CONTRIB_DIR    := $(CURDIR)/contrib
INITSCRIPT_DIR := $(CONTRIB_DIR)/init-scripts

COMMON_OBJECTS := $(addprefix $(O)/,\
	globals.o daemonize.o scriptenv.o run-script.o upower-listener.o)

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

PHONY += regen
regen: gen-instagit init-scripts



$(CURDIR)/$(BATWATCH_NAME): $(COMMON_OBJECTS) $(BATWATCH_OBJECTS)
	$(LINK_O) $^ -o $@

$(BATWATCH_NAME): $(CURDIR)/$(BATWATCH_NAME)

$(O):
	mkdir -p $(O)

$(O)/%.o: $(SRCDIR)/%.c | $(O)
	$(COMPILE_C) $< -o $@

$(INITSCRIPT_DIR)/%: $(INITSCRIPT_DIR)/%.in $(X_GEN_INIT)
	$(X_GEN_INIT) "$<" "$@"

$(CURDIR)/scripts/%.sh: $(CURDIR)/scripts/%.in.sh $(X_GEN_SHLIBCC)
	$(X_GEN_SHLIBCC) $< > $@.shlib_tmp
ifneq ($(X_SH),)
	$(X_SH) -n $@.shlib_tmp
endif
ifneq ($(X_BASH),)
	$(X_BASH) -n $@.shlib_tmp
endif
ifneq ($(X_DASH),)
	$(X_DASH) -n $@.shlib_tmp
endif
	mv -f -- $@.shlib_tmp $@



$(DISTDIR):
	mkdir -p $(DISTDIR)


PHONY += version
version: $(X_EXTRACT_DEF) $(SRCDIR)/version.h
	@$(X_EXTRACT_DEF) $(SRCDIR)/version.h BATWATCH_VERSION


PHONY += dist
dist: regen | $(DISTDIR)
	$(eval MY_$@_VER := $(call f_getver))
	git archive --worktree-attributes --format=tar HEAD \
		--prefix=$(BATWATCH_NAME)-$(MY_$@_VER) \
		> $(DISTDIR)/$(BATWATCH_NAME)-$(MY_$@_VER).tar

	gzip -c $(DISTDIR)/$(BATWATCH_NAME)-$(MY_$@_VER).tar \
		> $(DISTDIR)/$(BATWATCH_NAME)-$(MY_$@_VER).tar.gz

	xz -c $(DISTDIR)/$(BATWATCH_NAME)-$(MY_$@_VER).tar \
		> $(DISTDIR)/$(BATWATCH_NAME)-$(MY_$@_VER).tar.xz

	( cd $(DISTDIR) && \
		$(call f_gen_checksums,$(BATWATCH_NAME)-$(MY_$@_VER).tar) && \
		$(call f_gen_checksums,$(BATWATCH_NAME)-$(MY_$@_VER).tar.gz) && \
		$(call f_gen_checksums,$(BATWATCH_NAME)-$(MY_$@_VER).tar.xz) \
	)



PHONY += setver
setver: $(X_GEN_V_HEADER) FORCE
	$(X_GEN_V_HEADER) "$(VER)" "$(SRCDIR)/version.h"



PHONY += clean
clean:
	-rm -f -- $(COMMON_OBJECTS) $(BATWATCH_OBJECTS) $(CURDIR)/$(BATWATCH_NAME)
	-rm -f -- $(CURDIR)/scripts/*.shlib_tmp
	-test ! -d $(O) || rmdir $(O)


PHONY += genclean
genclean: \
	$(addprefix $(CURDIR)/scripts/,instagitlet.in.sh instagitlet.in.depend) \
	$(addprefix $(INITSCRIPT_DIR)/$(BATWATCH_NAME).,init.in openrc.in)

	rm -f -- $(addprefix $(INITSCRIPT_DIR)/$(BATWATCH_NAME).,init openrc)
	rm -f -- $(CURDIR)/scripts/instagitlet.sh


PHONY += distclean
distclean: clean genclean




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


PHONY += gen-instagit
gen-instagit: $(CURDIR)/scripts/instagitlet.sh


PHONY += _init-scripts__shell
_init-scripts__shell: \
	$(addprefix $(INITSCRIPT_DIR)/$(BATWATCH_NAME).,init openrc)

ifneq ($(X_SH),)
	$(foreach f,$^,$(X_SH) -n $(f) || exit 1;)
endif
ifneq ($(X_DASH),)
	$(foreach f,$^,$(X_DASH) -n $(f) || exit 1;)
endif


PHONY += _init-scripts__others
_init-scripts__others:


PHONY += init-scripts
init-scripts: _init-scripts__shell _init-scripts__others





PHONY += help
help:
	@echo  'Targets:'
	@echo  '  clean              - Remove most generated files'
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
	@echo  '  regen              - Regenerate all scripts'
	@echo  '  genclean           - Remove generated scripts'
	@echo  '  setver             - Set version to VER'
	@echo  '                       (should be done before compiling/packing)'
	@echo  '  init-scripts       - Regenerate init scripts'
	@echo  'Z gen-instagit       - Regenerate scripts/instagitlet.sh'
	@echo  'Z stat               - size(1), scanelf(1) [implies $(BATWATCH_NAME)]'
	@echo  '  distclean          - clean + genclean'
	@echo  '  dist               - Pack source as tarball to DISTDIR [implies regen]'
	@echo  '                       (default: $(DISTDIR))'
	@echo  ''
	@echo  '  make O=<dir> [targets] Locate all intermediate output files in <dir>'
	@echo  '                          (default: $(O))'
	@echo  ''
	@echo  'Install targets do not imply any build target.'
	@echo  'Targets marked with [Z] have special dependencies,'
	@echo  'which are likely not installed on your system.'
	@echo  ''
	@echo  'Run "make" or "make all" to build $(BATWATCH_NAME).'

PHONY += FORCE
FORCE:

.PHONY: $(PHONY)
