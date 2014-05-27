FROM cpuguy83/ruby-mri
RUN gem install backup whenever
RUN apt-get update && \
  apt-get install -y cron openssh-server rsync mysql-client postgresql-client -qq && \
  apt-get remove -y build-essential -qq && \
  apt-get autoremove -y -qq  && \
  apt-get clean -qq
RUN backup generate:config

ADD start.sh /Backup/
ADD schedule.rb /Backup/
ADD volbackup.rb /volbackup.rb

WORKDIR /Backup

VOLUME /Backup

ENTRYPOINT ["/Backup/start.sh"]
