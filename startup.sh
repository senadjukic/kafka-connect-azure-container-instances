echo "Installing connector plugins"
confluent-hub install --no-prompt confluentinc/kafka-connect-azure-blob-storage:1.6.10
#
echo "Launching Kafka Connect worker"
/etc/confluent/docker/run &
#
echo "Waiting for Kafka Connect to start listening on localhost:8083 ⏳"
while : ; do
    curl_status=$(curl -s -o /dev/null -w %{http_code} http://localhost:8083/connectors)
    echo -e $(date) " Kafka Connect listener HTTP state: " $curl_status " (waiting for 200)"
    if [ $curl_status -eq 200 ] ; then
    break
    fi
    sleep 5
done
echo -e "\n--\n+> Creating Kafka Connect source connectors"
curl -i -X PUT -H "Accept:application/json" \
    -H  "Content-Type:application/json" \
    http://localhost:8083/connectors/azure-blob-sink/config \
    -d '{
        "connector.class"                                      : "io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector",
        "format.class"                                         : "io.confluent.connect.azure.blob.format.json.JsonFormat",
        "input.data.format"                                    : "JSON",
        "azblob.account.name"                                  : "xxxx",
        "azblob.account.key"                                   : "xxxx",
        "azblob.container.name"                                : "container1",
        "output.data.format"                                   : "JSON",
        "time.interval"                                        : "HOURLY",
        "flush.size"                                           : "10",
        "tasks.max"                                            : "1",
        "offset.flush.interval.ms"                             : 10000,
        "offset.storage.file.filename"                         : "/tmp/connect.offsets",
        "topics"                                               : "topic_1",
        "value.converter"                                      : "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable"                       : "false",
        "key.converter"                                        : "org.apache.kafka.connect.storage.StringConverter",
        "key.converter.schemas.enable"                         : "false",
        "topic.creation.default.partitions"                    : 1,
        "topic.creation.default.replication.factor"            : 3,
        "confluent.license"                                    : "",
        "confluent.topic.bootstrap.servers"                    : "pkc-xxxxx.switzerlandnorth.azure.confluent.cloud:9092",
        "confluent.topic.sasl.jaas.config"                     : "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"xxxx\" password=\"xxxx\";",
        "confluent.topic.security.protocol"                    : "SASL_SSL",
        "confluent.topic.ssl.endpoint.identification.algorithm": "https",
        "confluent.topic.sasl.mechanism"                       : "PLAIN",
        "confluent.topic.request.timeout.ms"                   : "20000",
        "confluent.topic.retry.backoff.ms"                     : "500"
    }'
#
#
sleep infinity