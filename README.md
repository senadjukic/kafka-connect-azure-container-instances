# Start a self-managed Kafka Connector in Azure Container Instances

In Confluent Cloud, connectors are fully-managed available. If you like to run your connectors by yourself, you can connect them to Confluent Cloud easily.

This is an example with the Azure Blob Sink Connector.

Inspired by:
- https://nielsberglund.com/2021/09/06/run-self-managed-kusto-kafka-connector-serverless-in-azure-container-instances/
- https://rmoff.net/2021/01/11/running-a-self-managed-kafka-connect-worker-for-confluent-cloud/

## Prerequisites

1. Create a topic and some random data

```
confluent login
confluent environment use env-xxxx
confluent kafka cluster use lkc-xxxxx
confluent api-key store {API_KEY} {API_KEY_SECRET}
confluent api-key use {API_KEY} --resource lkc-xxxxx
confluent kafka topic consume -b topic_1

confluent kafka topic produce topic_1

{"registertime":1490444236577,"userid":"User_9","regionid":"Region_7","gender":"FEMALE"}
{"registertime":1502667709853,"userid":"User_6","regionid":"Region_1","gender":"OTHER"}
{"registertime":1494927604550,"userid":"User_6","regionid":"Region_9","gender":"OTHER"}
{"registertime":1499639713347,"userid":"User_1","regionid":"Region_6","gender":"OTHER"}
{"registertime":1512996028696,"userid":"User_9","regionid":"Region_3","gender":"MALE"}
{"registertime":1490401669334,"userid":"User_7","regionid":"Region_8","gender":"OTHER"}
{"registertime":1507070341972,"userid":"User_1","regionid":"Region_8","gender":"MALE"}
{"registertime":1517830317696,"userid":"User_5","regionid":"Region_5","gender":"FEMALE"}
{"registertime":1501602538638,"userid":"User_8","regionid":"Region_7","gender":"OTHER"}
{"registertime":1490685069433,"userid":"User_5","regionid":"Region_5","gender":"FEMALE"}
{"registertime":1509772082159,"userid":"User_2","regionid":"Region_3","gender":"OTHER"}
{"registertime":1496237513550,"userid":"User_1","regionid":"Region_6","gender":"MALE"}
{"registertime":1491472767647,"userid":"User_2","regionid":"Region_2","gender":"OTHER"}
```

2. Create a Resource Group
az group create --name name-of-rg --location azure-location

3. Create a Azure Storage Account with a Container "container1"
https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-cli

4. Create an Azure Container Registry
``` 
az acr create --resource-group myResourceGroup --name <acrName> --sku Basic
az acr show --name registryname --query loginServer
az acr credential show --name registryname
``` 

5. Create Kafka API Keys for the connector


## Instructions

**Create Docker Image**
```
docker build . -t registryname.azurecr.io/azure-sink-connector:7.1.0
``` 

**Push image to the Azure Container Registry**
``` 
docker login registryname.azurecr.io --username xxxx --password xxxx
docker push registryname.azurecr.io/azure-sink-connector:7.1.0
``` 

**Verify it arrived**
``` 
az acr repository list --name registryname
``` 

**Create the Azure Container Instance. Attention: this is only for demo-purposes as it exposes the config over a public IP!**
``` 
az container create --resource-group sjukic \
--name azuresinkconnector1 \
--image registryname.azurecr.io/azure-sink-connector:7.1.0 \
--restart-policy OnFailure \
--ip-address Public \
--ports 8083 \
--registry-login-server registryname.azurecr.io \
--registry-username xxxx \
--registry-password xxxx \
--environment-variables \
CONNECT_LOG4J_APPENDER_STDOUT_LAYOUT_CONVERSIONPATTERN='[%d] %p %X{connector.context}%m (%c:%L)%n' \
CONNECT_CUB_KAFKA_TIMEOUT='300' \
CONNECT_BOOTSTRAP_SERVERS='pkc-xxxxx.switzerlandnorth.azure.confluent.cloud:9092' \
CONNECT_REST_ADVERTISED_HOST_NAME='kafka-connect-ccloud' \
CONNECT_REST_PORT='8083' \
CONNECT_GROUP_ID='kafka-connect-group-01-v04' \
CONNECT_CONFIG_STORAGE_TOPIC='_kafka-connect-group-01-v04-configs' \
CONNECT_OFFSET_STORAGE_TOPIC='_kafka-connect-group-01-v04-offsets' \
CONNECT_STATUS_STORAGE_TOPIC='_kafka-connect-group-01-v04-status' \
CONNECT_KEY_CONVERTER='io.confluent.connect.avro.AvroConverter' \
CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL='https://psrc-xxxxx.eu-central-1.aws.confluent.cloud' \
CONNECT_KEY_CONVERTER_BASIC_AUTH_CREDENTIALS_SOURCE='USER_INFO' \
CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO='xxxxx:xxxxx' \
CONNECT_VALUE_CONVERTER='io.confluent.connect.avro.AvroConverter' \
CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL='https://psrc-xxxxx.eu-central-1.aws.confluent.cloud' \
CONNECT_VALUE_CONVERTER_BASIC_AUTH_CREDENTIALS_SOURCE='USER_INFO' \
CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO='xxxxx:xxxxx' \
CONNECT_LOG4J_ROOT_LOGLEVEL='INFO' \
CONNECT_LOG4J_LOGGERS='org.apache.kafka.connect.runtime.rest=WARN,org.reflections=ERROR' \
CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR='3' \
CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR='3' \
CONNECT_STATUS_STORAGE_REPLICATION_FACTOR='3' \
CONNECT_PLUGIN_PATH='/usr/share/java,/usr/share/confluent-hub-components/' \
CONNECT_REQUEST_TIMEOUT_MS='20000' \
CONNECT_RETRY_BACKOFF_MS='500' \
CONNECT_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM='https' \
CONNECT_SASL_MECHANISM='PLAIN' \
CONNECT_SECURITY_PROTOCOL='SASL_SSL' \
CONNECT_SASL_JAAS_CONFIG='org.apache.kafka.common.security.plain.PlainLoginModule required username="xxxx" password="xxxx";' \
CONNECT_CONSUMER_SECURITY_PROTOCOL='SASL_SSL' \
CONNECT_CONSUMER_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM='https' \
CONNECT_CONSUMER_SASL_MECHANISM='PLAIN' \
CONNECT_CONSUMER_SASL_JAAS_CONFIG='org.apache.kafka.common.security.plain.PlainLoginModule required username="xxxx" password="xxxx";' \
CONNECT_CONSUMER_REQUEST_TIMEOUT_MS='20000' \
CONNECT_CONSUMER_RETRY_BACKOFF_MS='500' \
CONNECT_PRODUCER_SECURITY_PROTOCOL='SASL_SSL' \
CONNECT_PRODUCER_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM='https' \
CONNECT_PRODUCER_SASL_MECHANISM='PLAIN' \
CONNECT_PRODUCER_SASL_JAAS_CONFIG='org.apache.kafka.common.security.plain.PlainLoginModule required username="xxxx" password="xxxx";' \
CONNECT_PRODUCER_REQUEST_TIMEOUT_MS='20000' \
CONNECT_PRODUCER_RETRY_BACKOFF_MS='500'
``` 

**Verify Container State**
``` 
az container show --resource-group xxxx --name azuresinkconnector1 --query instanceView.state
``` 

**Get Link to Connect State**
``` 
echo "http://"$(az container show --resource-group xxxx --name azuresinkconnector1 --query ipAddress.ip | tr -d '"')":8083/connectors/azure-blob-sink/status"
``` 

**Troubleshoot**
``` 
az container logs --resource-group xxxx --name azuresinkconnector1
``` 

## Clean up

```
confluent kafka topic delete _kafka-connect-group-01-v04-configs
confluent kafka topic delete _kafka-connect-group-01-v04-offsets
confluent kafka topic delete _kafka-connect-group-01-v04-status

# Delete all JSON files from container1
export CONN=$(az storage account show-connection-string --name storageaccountname | jq .[])
az storage blob delete-batch --source container1  --account-name storageaccountname --pattern *.json --connection-string $CONN
```