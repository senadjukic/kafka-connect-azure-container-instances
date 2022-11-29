# Start a self-managed Kafka Connector in Azure Container Instances

In Confluent Cloud, one can use fully-managed connectors. If you prefer to run your connectors by yourself, here is a way to run self-managed connectors against Confluent Cloud.

This is an example with the Azure Blob Sink Connector that reads from a Kafka topic and posts it into a Azure Blob Container. The connector itself is deployed on Azure Container Instances.

## Prerequisites

0. Install the Confluent CLI & Azure CLI
```
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

This tutorial was tested with the version:
```
$ confluent version
confluent - Confluent CLI

Version:     v2.33.0
Git Ref:     e96971b9
Build Date:  2022-11-17T23:19:22Z
Go Version:  go1.18.1 (linux/amd64)
Development: false
```

1. Create a topic and some random data

```
confluent login
confluent environment list
confluent environment use env-xxxx
confluent kafka cluster list
confluent kafka cluster use lkc-xxxxx

confluent api-key create --resource lkc-xxxxxx --description "SA Key for ACI Connector and CLI"
OR:
confluent api-key store {SERVICE_ACCOUNT_API_KEY} {SERVICE_ACCOUNT_API_KEY_SECRET}
confluent api-key use {SERVICE_ACCOUNT_API_KEY} --resource lkc-xxxxx

confluent kafka topic create topic_1

```

2. Login to Azure, define variables, create a Resource Group \
```
az login --use-device-code

# Change variables if needed
export AzureLocation=switzerlandnorth
export AzureResourceGroup=sjukic
export StorageAccountName=acsconnecttest
export BlobContainerName=testcontainer
export AzureContainerInstancesName=azuresinkconnector1
export AzureContainerRegistryName=acrsju
export ContainerImageWithTag=azure-sink-connector:7.1.1

az group create --name $AzureResourceGroup --location $AzureLocation
```

3. Create a Azure Storage Account with a Container "container1" \

```
# Create Storage Account + Container
az storage account create \
    --name $StorageAccountName \
    --resource-group $AzureResourceGroup \
    --location $AzureLocation \
    --sku Standard_ZRS \
    --encryption-services blob

# Get a storage account key
export StorageAccountKey=$(az storage account keys list -g $AzureResourceGroup -n $StorageAccountName | jq .[0].value)

# Create a container using the key
az storage container create -n $BlobContainerName --account-name $StorageAccountName --account-key $StorageAccountKey
```

Same instructions: \
Via CLI: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-cli \
Via Azure Portal: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal

4. Create an Azure Container Registry
``` 
az acr create --resource-group $AzureResourceGroup --name $AzureContainerRegistryName --sku Basic
az acr update -n $AzureContainerRegistryName --admin-enabled true
az acr credential show --name $AzureContainerRegistryName
``` 

## Instructions

**Create Docker Image**
```
export AzureContainerRegistryFQDN=$(az acr show --name $AzureContainerRegistryName --query loginServer | jq -r)
docker build . -t ${AzureContainerRegistryFQDN}/${ContainerImageWithTag}
``` 

**Push image to the Azure Container Registry**
``` 
export AzureContainerRegistryPassword=$(az acr credential show --name ${AzureContainerRegistryName} | jq .passwords[0].value -r)
docker login ${AzureContainerRegistryFQDN} --username ${AzureContainerRegistryName} --password ${AzureContainerRegistryPassword}
docker push ${AzureContainerRegistryFQDN}/${ContainerImageWithTag}
``` 

**Verify that the Container Image was successfully pushed**
``` 
az acr repository list --name ${AzureContainerRegistryName}
``` 

**Set your Bootstrap URL & Service API Keys and other environment variables**
```
export CONFLUENT_CLOUD_BOOTSTRAP_SERVERS='pkc-xxxxx.switzerlandnorth.azure.confluent.cloud:9092'
export SERVICE_ACCOUNT_API_KEY="xxx"
export SERVICE_ACCOUNT_API_KEY_SECRET="xxx"
export CONFLUENT_CLOUD_SCHEMA_REGISTRY_ENDPOINT='https://psrc-xxxxx.eu-central-1.aws.confluent.cloud'
export CONFLUENT_CLOUD_SCHEMA_REGISTRY_CREDENTIALS='username:password'
export CONNECTOR_NAME='azure-blob-sink'
```

**Create the Azure Container Instance. Attention: this is only for demo-purposes as it exposes the config over a public IP!**
``` 
az container create \
--resource-group $AzureResourceGroup \
--name $AzureContainerInstancesName \
--image ${AzureContainerRegistryFQDN}/${ContainerImageWithTag} \
--restart-policy OnFailure \
--ip-address Public \
--ports 8083 \
--registry-login-server ${AzureContainerRegistryFQDN} \
--registry-username ${AzureContainerRegistryName} \
--registry-password  ${AzureContainerRegistryPassword} \
--environment-variables \
CONNECT_LOG4J_APPENDER_STDOUT_LAYOUT_CONVERSIONPATTERN='[%d] %p %X{connector.context}%m (%c:%L)%n' \
CONNECT_CUB_KAFKA_TIMEOUT='300' \
CONNECT_REST_ADVERTISED_HOST_NAME='kafka-connect-ccloud' \
CONNECT_REST_PORT='8083' \
CONNECT_GROUP_ID='connect-01' \
CONNECT_CONFIG_STORAGE_TOPIC='_connect-01-configs' \
CONNECT_OFFSET_STORAGE_TOPIC='_connect-01-offsets' \
CONNECT_STATUS_STORAGE_TOPIC='_connect-01-status' \
CONNECT_KEY_CONVERTER='io.confluent.connect.avro.AvroConverter' \
CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_ENDPOINT} \
CONNECT_KEY_CONVERTER_BASIC_AUTH_CREDENTIALS_SOURCE='USER_INFO' \
CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_CREDENTIALS} \
CONNECT_VALUE_CONVERTER='io.confluent.connect.avro.AvroConverter' \
CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_ENDPOINT} \
CONNECT_VALUE_CONVERTER_BASIC_AUTH_CREDENTIALS_SOURCE='USER_INFO' \
CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_CREDENTIALS} \
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
CONNECT_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${SERVICE_ACCOUNT_API_KEY}\" password=\"${SERVICE_ACCOUNT_API_KEY_SECRET}\";" \
CONNECT_CONSUMER_SECURITY_PROTOCOL='SASL_SSL' \
CONNECT_CONSUMER_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM='https' \
CONNECT_CONSUMER_SASL_MECHANISM='PLAIN' \
CONNECT_CONSUMER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${SERVICE_ACCOUNT_API_KEY}\" password=\"${SERVICE_ACCOUNT_API_KEY_SECRET}\";" \
CONNECT_CONSUMER_REQUEST_TIMEOUT_MS='20000' \
CONNECT_CONSUMER_RETRY_BACKOFF_MS='500' \
CONNECT_PRODUCER_SECURITY_PROTOCOL='SASL_SSL' \
CONNECT_PRODUCER_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM='https' \
CONNECT_PRODUCER_SASL_MECHANISM='PLAIN' \
CONNECT_PRODUCER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${SERVICE_ACCOUNT_API_KEY}\" password=\"${SERVICE_ACCOUNT_API_KEY_SECRET}\";" \
CONNECT_PRODUCER_REQUEST_TIMEOUT_MS='20000' \
CONNECT_PRODUCER_RETRY_BACKOFF_MS='500' \
CLUSTER_TOPIC='topic_1' \
CONNECTOR_WITH_VERSION='kafka-connect-azure-blob-storage:1.6.10' \
CONNECTOR_NAME=${CONNECTOR_NAME} \
CONNECTOR_CLASS='io.confluent.connect.azure.blob.AzureBlobStorageSinkConnector' \
FORMAT_CLASS='io.confluent.connect.azure.blob.format.json.JsonFormat' \
CONNECT_BOOTSTRAP_SERVERS=${CONFLUENT_CLOUD_BOOTSTRAP_SERVERS} \
SERVICE_ACCOUNT_API_KEY=${SERVICE_ACCOUNT_API_KEY} \
SERVICE_ACCOUNT_API_KEY_SECRET=${SERVICE_ACCOUNT_API_KEY_SECRET} \
AZBLOB_ACCOUNT_NAME=${StorageAccountName} \
AZBLOB_ACCOUNT_KEY=${StorageAccountKey} \
AZBLOB_CONTAINER_NAME=${BlobContainerName}
``` 

**Verify Container State**
``` 
az container show --resource-group $AzureResourceGroup --name $AzureContainerInstancesName --query instanceView.state
``` 

**Get Link to Connect State**
``` 
echo "http://"$(az container show --resource-group $AzureResourceGroup --name $AzureContainerInstancesName --query ipAddress.ip | tr -d '"')":8083/connectors/${CONNECTOR_NAME}/status"
``` 

**Produce some data to the topic**
```
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

## CTRL+C
```

**Check if some blobs arrived**
```
export StorageAccountConnectionString=$(az storage account show-connection-string --name $StorageAccountName | jq .[])
az storage blob list --account-name $StorageAccountName --container-name $BlobContainerName --connection-string $StorageAccountConnectionString
```

**Troubleshoot**
``` 
# Get logs from container
az container logs --resource-group $AzureResourceGroup --name $AzureContainerInstancesName

# Stop the container
az container stop --resource-group $AzureResourceGroup --name $AzureContainerInstancesName 

# List all containers
az container list --resource-group $AzureResourceGroup

# Show state of container
az container show --resource-group $AzureResourceGroup --name $AzureContainerInstancesName --query instanceView.state

# Attach a Bash shell of the container
az container exec --resource-group $AzureResourceGroup --name $AzureContainerInstancesName --exec-command "/bin/bash"
``` 

## Clean up

```
# Delete container & list all remaining
az container delete --resource-group $AzureResourceGroup --name $AzureContainerInstancesName --yes
az container list --resource-group $AzureResourceGroup

# Delete connector Kafka topics
confluent kafka topic delete _connect-01-configs
confluent kafka topic delete _connect-01-offsets
confluent kafka topic delete _connect-01-status

# Delete all JSON files from Azure Storage Blob Container
export StorageAccountConnectionString=$(az storage account show-connection-string --name $StorageAccountName | jq .[])
az storage blob delete-batch --source $BlobContainerName  --account-name $StorageAccountName --pattern *.json --connection-string $StorageAccountConnectionString
```

## Inspired by:
- https://nielsberglund.com/2021/09/06/run-self-managed-kusto-kafka-connector-serverless-in-azure-container-instances/
- https://rmoff.net/2021/01/11/running-a-self-managed-kafka-connect-worker-for-confluent-cloud/