===============================
 batwatch - 10.01.2014 (draft)
===============================


Introduction
============

*batwatch* is a UPower event-driven daemon that runs other programs/scripts
when a discharging battery's remaining energy is within a critical range
(e.g. below 10.0%).
It is able to handle multiple batteries/scripts/thresholds.
Does not execute a program more than once unless a battery leaves the
threshold range (**TODO**: or <some state changes> while in crit range).


Building and Installing batwatch
================================

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

   # install batwatch to /home/user/bin/batwatch
   $ make DESTDIR=/home/user DESTPREFIX=/bin install



Running it
==========

Usage::

   $ batwatch [-h] [-V] [option...]
        [-T <percentage>] [-b <name>] [-0] [-I <seconds>] -x <prog> {-[Tbx0I]...}


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

-0, --no-args
   Do not pass any args to the *next* program.

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

#. **Or** add the following text to the end of */etc/sudoers* (``visudo``).

   .. include:: contrib/batwatch.sudoers
      :literal:
      :class:     txtfile
      :name:      /etc/sudoers.d/batwatch
      :tab-width: 3


Refer to the ``sudoers(5)`` man page for details.



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

The following arguments are passed to scripts, unless ``--no-args`` has been
specified:

.. table:: args passed to scripts

   +-------+-------------------------------+-----------------------+
   | argno | description                   | example               |
   +=======+===============================+=======================+
   | 0     | program name/path             | /bin/true             |
   +-------+-------------------------------+-----------------------+
   | 1     | battery name                  | BAT0                  |
   +-------+-------------------------------+-----------------------+
   | 2     | battery sysfs path            | /sys/devices/...      |
   +-------+-------------------------------+-----------------------+
   | 3     | battery's remaining energy as | 20.0                  |
   |       | percentage rounded to one     |                       |
   |       | digit after the decimal point |                       |
   |       | ('.', locale-independent)     |                       |
   +-------+-------------------------------+-----------------------+
   | 4     | fallback battery name         | BAT1                  |
   |       | (if any)                      |                       |
   +-------+-------------------------------+-----------------------+
   | 5     | fallback battery sysfs path   | /sys/devices/...      |
   +-------+-------------------------------+-----------------------+
   | 6     | fallback battery' remaining   | 70.3                  |
   |       | energy                        |                       |
   +-------+-------------------------------+-----------------------+


Args 4-6 are empty if no fallback battery is available.
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
