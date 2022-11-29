#!/bin/sh

[[ -z "$CONNECTOR_WITH_VERSION" ]] && echo "ERROR! Variable 'CONNECTOR_WITH_VERSION' was not set." || \
confluent-hub install --no-prompt confluentinc/${CONNECTOR_WITH_VERSION}

echo "Launching Kafka Connect worker"
/etc/confluent/docker/run &

echo "Waiting for Kafka Connect to start listening on localhost:8083 ⏳"
while : ; do
    curl_status=$(curl -s -o /dev/null -w %{http_code} http://localhost:8083/connectors)
    echo -e $(date) " Kafka Connect listener HTTP state: " $curl_status " (waiting for 200)"
    if [ $curl_status -eq 200 ] ; then
    break
    fi
    sleep 5
done

echo "Creating Kafka Connect source connectors"
[[ -z "$CONNECTOR_NAME" ]] && echo "ERROR! Variable 'CONNECTOR_NAME' was not set." || \ 
  curl -i -X PUT -H "Accept:application/json" \
    -H  "Content-Type:application/json" \
    http://localhost:8083/connectors/${CONNECTOR_NAME}/config \
    -d "$(cat <<EOF
{
    "connector.class"                                      : "$CONNECTOR_CLASS",
    "format.class"                                         : "$FORMAT_CLASS",
    "input.data.format"                                    : "JSON",
    "azblob.account.name"                                  : "$AZBLOB_ACCOUNT_NAME",
    "azblob.account.key"                                   : $AZBLOB_ACCOUNT_KEY,
    "azblob.container.name"                                : "$AZBLOB_CONTAINER_NAME",
    "output.data.format"                                   : "JSON",
    "time.interval"                                        : "HOURLY",
    "flush.size"                                           : "3",
    "tasks.max"                                            : "1",
    "offset.flush.interval.ms"                             : 100,
    "offset.storage.file.filename"                         : "/tmp/connect.offsets",
    "topics"                                               : "$CLUSTER_TOPIC",
    "value.converter"                                      : "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable"                       : "false",
    "key.converter"                                        : "org.apache.kafka.connect.storage.StringConverter",
    "key.converter.schemas.enable"                         : "false",
    "topic.creation.default.partitions"                    : 1,
    "topic.creation.default.replication.factor"            : 3,
    "confluent.license"                                    : "",
    "confluent.topic.bootstrap.servers"                    : "$CONNECT_BOOTSTRAP_SERVERS",
    "confluent.topic.sasl.jaas.config"                     : "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$SERVICE_ACCOUNT_API_KEY\" password=\"$SERVICE_ACCOUNT_API_KEY_SECRET\";",
    "confluent.topic.security.protocol"                    : "SASL_SSL",
    "confluent.topic.ssl.endpoint.identification.algorithm": "https",
    "confluent.topic.sasl.mechanism"                       : "PLAIN",
    "confluent.topic.request.timeout.ms"                   : "20000",
    "confluent.topic.retry.backoff.ms"                     : "500"
}
EOF
)"

sleep infinity