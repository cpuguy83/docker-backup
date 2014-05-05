FROM cpuguy83/ruby-mri
RUN gem install backup whenever
RUN apt-get update && apt-get install -y cron openssh-server rsync -qq && apt-get remove -y build-essential -qq && apt-get autoremove -y -qq  && apt-get clean -qq
RUN backup generate:config

ADD start.sh /Backup/
ADD schedule.rb /Backup/

WORKDIR /Backup

VOLUME /Backup

ENTRYPOINT ["/Backup/start.sh"]
