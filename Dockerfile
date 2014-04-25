FROM mri
RUN gem install backup whenever
RUN apt-get update && apt-get install cron && apt-get remove -y build-essential -qq && apt-get autoremove -y -qq  && apt-get clean -qq
RUN backup generate:config

ADD start.sh /Backup/

WORKDIR /Backup

VOLUME /Backup

ENTRYPOINT ["/Backup/start.sh"]
