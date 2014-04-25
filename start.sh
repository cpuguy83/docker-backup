#!/bin/bash

whenever -f /Backup/schedule.rb --clear-crontab
whenever -f /Backup/schedule.rb --write-crontab
exec cron -f
