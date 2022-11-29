FROM confluentinc/cp-kafka-connect-base:7.1.0
COPY startup.sh /tmp/startup.sh
ENTRYPOINT ["/bin/bash","-c","/tmp/startup.sh"]