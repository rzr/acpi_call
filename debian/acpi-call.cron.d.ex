#
# Regular cron jobs for the acpi-call package
#
0 4	* * *	root	[ -x /usr/bin/acpi-call_maintenance ] && /usr/bin/acpi-call_maintenance
