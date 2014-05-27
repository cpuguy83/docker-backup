#!/bin/bash

# Do this so we can read these vars in cron
env > /Backup/.env

[[ -f /usr/bin/docker ]] ||
  cp /.dockerinit /usr/bin/docker

whenever -f /Backup/schedule.rb --clear-crontab
whenever -f /Backup/schedule.rb --write-crontab



exec cron -f
