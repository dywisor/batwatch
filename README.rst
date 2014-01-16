===============================
 batwatch - 13.01.2014 (draft)
===============================


Introduction
============

*batwatch* is a UPower event-driven daemon that runs other programs/scripts
when a discharging battery's remaining energy is within a critical range
(e.g. below 10.0%).
It is able to handle multiple batteries/scripts/thresholds.
Does not execute a program more than once unless a battery leaves the
threshold range (**TODO**: or <some state changes> while in crit range).

---------------
 instagit mode
---------------

For quickly testing *batwatch*, an *instant git applet* is available, which
is a script that takes care of everything (downloads/updates the git repo,
checks for dependencies, builds and runs batwatch). However, it does not
install any of the `dependencies`_ (highly distribution-specific).

For the impatient
   Run the following commands::

      cd ${TMPDIR:-/tmp}
      wget "https://github.com/dywisor/batwatch/blob/master/dist/instagitlet.sh.bz2?raw=true" -O- | bzip2 -dc > ./bw-instagit.sh
      chmod u+x ./bw-instagit.sh
      ./bw-instagit.sh -n && ./bw-instagit.sh -- -N -T 97 -x ./event-scripts/dummy.sh

More detailed
   (Optionally) Change the working directory to some temporary location::

      $ cd ${TMPDIR:-/tmp}

   Download the (compressed) instagitlet.sh script, unpack it and make it
   executable::

      $ wget "https://github.com/dywisor/batwatch/blob/master/dist/instagitlet.sh.bz2?raw=true" -O- | bzip2 -dc > ./bw-instagit.sh
      $ chmod u+x ./bw-instagit.sh

   To see what the script would do, run::

      $ ./bw-instagit.sh -n

   To actually download/build/run *batwatch*::

      $ ./bw-instagit.sh -- -N -T 97 -x ./event-scripts/dummy.sh

   This starts *batwatch* in non-daemon mode with the dummy *event script*,
   which gets activated if *any* of your batteries is discharging and below
   97%.

   Once the *batwatch* git repo has been cloned, you can delete
   ``./bw-instagit.sh`` and use ``~/git-src/scripts/instagitlet.sh`` instead.

   .. code:: sh

      $ rm ./bw-instagit.sh


   To get rid of *batwatch*, run::

      $ rm -rf ~/git-src/batwatch


I don't want these colors!
   Simply pass ``--no-color`` to the instagitlet script (before the ``--``)
   or run ``export NO_COLOR=y``.



Building and Installing batwatch
================================

.. _Dependencies:

Dependencies:

* build- and runtime:

  * libc (tested with glibc 2.17)
  * glib (tested with 2.36.4)
  * upower (tested with 0.9.21, 0.9.23)
  * (dbus, udev, ... required by upower)

* build-time only:

  * GNU Make
  * a C Compiler (gcc preferred)
  * pkgconfig


Simply run ``make`` or ``make batwatch`` (``make help`` lists all targets).

When cross-compiling, ``PKG_CONFIG``, ``PKG_CONFIG_*`` and
``CROSS_COMPILE`` or ``TARGET_CC`` should be set.

For installing `batwatch`, run::

   # install batwatch to its default location (/usr/bin/batwatch)
   $ make install

   # install batwatch to /home/user, binaries to /home/user/bin
   $ make DESTDIR=/home/user BIN=/home/user/bin install

   # install bash-completions, sudo config
   $ make install-contrib

   ## install init script(s)
   # OpenRC
   $ make install-openrc
   # SysVinit
   $ make install-sysvinit

   # as one-liner (example, doesn't work with /bin/dash)
   $ make DESTDIR=/ BASHCOMPDIR=/usr/share/bash-completions install{,-contrib,-openrc}


Running it
==========

Usage::

   $ batwatch [-h] [-V] [option...]
        [-T <percentage>] [-b <name>] [-I <seconds>] -x <prog> {-[TbxI]...}


Required options (can be specified more than once):

-T, --threshold <percentage>
   Sets the activation threshold for *all* following programs (``--exe``).
   Defaults to 10.0.

-x, --exe <prog>
   Program to run if a battery's percentage is below --threshold.
   Usually an `Event Script`_.

-b, --battery <name>
   Restrict the *next* program (``--exe``) to a single battery referenced by
   name, e.g. `BAT0`.

-I, --inhibit <seconds>
   Do not call the *next* program if the time since the last
   system wakeup is less than *seconds*. Also don't call the script when
   about to suspend/hibernate/power down (?or if a fallback battery is available?).
   **TODO/Not implemented**


Options:

-F, --fallback-min <percentage>
   Minimal energy (as percentage) a battery must have in order to be
   considered as fallback battery. Defaults to 30.0.

-h, --help
   Prints the help message to stdout and exits afterwards.

-V, --version
   Prints the version to stdout and exits afterwards.


Daemon options:

-N, --no-fork
   Run in foreground (don't daemonize).

-1, --stdout <file>
   Redirect daemon stdout to `<file>`. Daemon output is suppressed by default.
   ``/proc/self/fd/1`` may be passed for keeping the console's stdout open.

-2, --stderr <file>
   Redirect daemon stderr to `<file>`. Also see ``--stdout``.

-C, --rundir <dir>
   Sets the daemon's run directory to `<dir>`. Defaults to ``/``.

-p, --pidfile <file>
   Instructs the daemon to write its process id to `<file>` after successful
   setup (just before entering the event loop).
   No pid file is written by default.


Running *batwatch* as root is **not recommended**, simply because there is no
need to do so. However, Certain actions like system suspend require root
privileges, which can be achieved with *sudo* (and others):

#. Create the ``batwatch`` group:

   .. code:: text

      $ groupadd --system batwatch

#. Add the batwatch user to this group:

   .. code:: text

      $ gpasswd -a <user> batwatch

#. **Or** create a new user:

   .. code:: text

      $ useradd --system --home=/dev/null -g batwatch --shell=/sbin/nologin batwatch

#. Copy *contrib/batwatch.sudoers* to */etc/sudoers.d/batwatch*:

   .. code:: text

      $ install -m 0440 contrib/batwatch.sudoers /etc/sudoers.d/batwatch

   The sudoers file is automatically installed by ``make install-contrib``.
   Make sure that */etc/sudoers* has a ``#includedir /etc/sudoers.d``
   directive.

#. **Or** add the content of *contrib/batwatch.sudoers* to the end of */etc/sudoers* (``visudo``)

   .. include:: contrib/batwatch.sudoers
      :literal:
      :class:     txtfile
      :name:      /etc/sudoers.d/batwatch
      :tab-width: 3


Refer to the ``sudoers(5)`` man page for details.

.. Caution::

   Arch users need to edit *contrib/batwatch.sudoers*
   if pm-utils is to be used.



---------
 Signals
---------

SIGHUP
   Update battery status and run scripts as necessary.

   **!!!** Might change in future.

SIGUSR1
   Reset all scripts to *not run*, update battery status and run scripts
   as necessary.

   **!!!** Might change in future.

SIGINT, SIGQUIT, SIGTERM
   clean exit.

SIGCHLD, SIGTSTP, SIGTTOU, SIGTTIN
   Ignored.



.. _Event Script:

---------------
 Event scripts
---------------

Scripts (``--exe``) are run if a battery is discharging and its remaining
energy is  within the *critical range* (is less or equal than the script's
threshold). The script is not called more than once, until the battery is
no longer discharging or its percentage leaves the threshold range.

See *event-scripts/* for examples.

The following *environment variables* are passed to scripts (in addition to
the usual system environment):

.. table:: environment variables passed to scripts

   +------------------------------+-------------------------------+-----------------------+
   | name                         | description                   | example               |
   +==============================+===============================+=======================+
   | BATTERY                      | battery name                  | BAT0                  |
   +------------------------------+-------------------------------+-----------------------+
   | BATTERY_PERCENT              | battery's remaining energy as | 20.0                  |
   |                              | percentage rounded to one     |                       |
   |                              | digit after the decimal point |                       |
   |                              | ('.', locale-independent)     |                       |
   +------------------------------+-------------------------------+-----------------------+
   | BATTERY_TIME                 | battery's remaining running   | 37                    |
   |                              | time, in minutes              |                       |
   |                              |                               |                       |
   |                              | Set to 0 if unknown and -1    |                       |
   |                              | if too big to be represented  |                       |
   |                              | by an 32bit integer.          |                       |
   +------------------------------+-------------------------------+-----------------------+
   | BATTERY_SYSFS                | battery sysfs path            | /sys/devices/...      |
   +------------------------------+-------------------------------+-----------------------+
   +------------------------------+-------------------------------+-----------------------+
   | FALLBACK_BATTERY_STATE       | string describing the         | *unknown*,            |
   |                              | fallback battery's status     | *charging*,           |
   |                              |                               | *discharging*,        |
   |                              | empty if no fallback battery  | *empty*,              |
   |                              | available                     | *fully-charged*,      |
   |                              |                               | *pending-charge* or   |
   |                              |                               | *pending-discharge*   |
   +------------------------------+-------------------------------+-----------------------+
   | FALLBACK_BATTERY             | fallback battery name         | BAT1                  |
   |                              | (if any)                      |                       |
   +------------------------------+-------------------------------+-----------------------+
   | FALLBACK_BATTERY_PERCENT     | fallback battery's remaining  | 70.3                  |
   |                              | energy                        |                       |
   +------------------------------+-------------------------------+-----------------------+
   | FALLBACK_BATTERY_TIME        | time in minutes until the     | 0                     |
   |                              | fallback battery is fully     |                       |
   |                              | charged.                      |                       |
   |                              |                               |                       |
   |                              | Set to 0 if unknown or not    |                       |
   |                              | charging and -1 if too big.   |                       |
   +------------------------------+-------------------------------+-----------------------+
   | FALLBACK_BATTERY_SYSFS       | fallback battery sysfs path   | /sys/devices/...      |
   +------------------------------+-------------------------------+-----------------------+
   | ON_AC_POWER                  | 1 if on AC power, else 0      | 1                     |
   +------------------------------+-------------------------------+-----------------------+

These variables may be empty if no information is available.
See *event-scripts/skel.sh* for a script template (**TODO**).

|

More specifically a script is executed if it has not been run and there
is *any discharging* battery with the following properties:

* The battery's remaining percentage is within the critical range

* The script accepts the battery's name (controlled ``--battery``)

  A script without name restrictions is executed for the *first* discharging
  battery (assuming that all other conditions are met)

The script's *has been run* status is reset if there is

1. no discharging battery that the script could handle (i.e. battery name
   is accepted) or

2. *any* battery that changed its state (e.g. from discharging to charging)

   **TODO / state change detection is only partially implemented**


----------
 Examples
----------

Reduce the backlight's brightness if the battery is below 30.1% and suspend
the system if it is below 6%, running as daemon with /run/batwatch.pid
as pidfile::

   $ batwatch -p /run/batwatch.pid -T 30.1 -x /path/to/backlight-script.sh -T 6 -x /path/to/suspend-script.sh

   # update batteries and run scripts as necessary
   $ kill -HUP "$(cat /run/batwatch.pid)"
   ## or (bash)
   $ kill -HUP "$(< /run/batwatch.pid)"

   # reset script status and force update
   $ kill -USR1 "$(cat /run/batwatch.pid)"


.. Note::
   Once that ``--inhibit`` is implemented, this example should be changed
   to something like::

      $ batwatch -p /run/batwatch.pid -T 30.1 -I 0 -x <backlight-script> -T 6 -I 300 -x <suspend script>


.. _DEBUG_EXAMPLE:

Run batwatch with the event test script in foreground and write all output to console::

   # use a value slightly below your battery's current percentage for -T
   $ G_MESSAGES_DEBUG="all" ./batwatch -N -T 97 -x "${PWD}/event-scripts/dummy.sh"

More advanced::

   $ X="${PWD}/event-scripts/dummy.sh"
   $ G_MESSAGES_DEBUG="all" ./batwatch -N -T 97 -x "${X}" -T 96 -b BAT0 -x "${X}" ...

   # reset script status and force update, in another terminal
   $ pkill -USR1 batwatch


Example output::

   <example output here>
