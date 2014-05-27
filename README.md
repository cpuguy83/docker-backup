Docker Backup
============
Uses Ruby backup gem. http://rubygems.org/gems/backup
Uses whenver gem+cron to schedule backup jobs.  Place your jobs into
/Backup/schedule.rb
Backup scripts should go into /Backup/models

See documentation for backup gem and whenever gem on proper syntax.

A utility called "volbackup" is provided in /volbackup.rb.
To use this you must provide a socket by either bind-mounting in the Docker socket or using a tcp socket.
Have a look inside to see what options are available.
