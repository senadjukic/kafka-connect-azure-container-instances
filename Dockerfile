FROM confluentinc/cp-kafka-connect-base:7.1.0
COPY startup.sh .
CMD ["/bin/bash","-c","./startup.sh"]