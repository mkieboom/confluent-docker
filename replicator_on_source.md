# Run Replicator on source datacenter with connect-* topics on source

### Goal
Launch Confluent Replicator on the source datacenter with the connect-* topics on the source as well.

In order to create the connect-* topics on the source cluster, configure the following

```
1. Set the Connect bootstrap.servers to the cluster where you want to store the connect-* topics
# Either in /etc/kafka/connect-distributed.properties:
bootstrap.servers=kafkasource:9092

# or in Docker
CONNECT_BOOTSTRAP_SERVERS: kafkasource:9092


2. Set connector.client.config.override.policy to All
# Either in /etc/kafka/connect-distributed.properties:
connector.client.config.override.policy=All

# or in Docker
CONNECT_CONNECTOR_CLIENT_CONFIG_OVERRIDE_POLICY: "All"

3. Set the destination bootstrap.servers where the topic should be replicated to in the connector REST call
"dest.kafka.bootstrap.servers": "kafkadest:9092",
"producer.override.bootstrap.servers": "kafkadest:9092",

# Optional for secured clusters: set the JAAS config for both dest.kafka as well as producer.override in the REST call
dest.kafka.sasl.jaas.
producer.override.sasl.jaas.*

# Optional for offset translation: set the consumer.override in the REST call
consumer.override.*
```

### Clone the github project
```
git clone https://github.com/mkieboom/confluent-docker
cd 2clusters-1broker
```

### Launch the clusters using docker-compose
```
docker-compose up -d
```

### Check if all containers are up and running
```
docker-compose ps
```

### Deploying Replicator is done using the following curl command (note the producer.override):
```
curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicator",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.kafka.bootstrap.servers": "kafkasource:9092",
          "dest.kafka.bootstrap.servers": "kafkadest:9092",
          "producer.override.bootstrap.servers": "kafkadest:9092",
          "dest.kafka.replication.factor": "1",
          "tasks.max": "1",
          "confluent.topic.replication.factor": "1",
          "topic.whitelist": "my-onprem-topic",
          "topic.rename.format": "${topic}-replica"}
          }'  \
          http://localhost:8083/connectors
```

### Trace the Connect logs (optional)
```
docker logs connect -f
```

### Get the connector status
```
curl localhost:8083/connectors/replicator/status | jq
```

### Create a topic on the source cluster
```
docker exec -it kafkasource \
  kafka-topics --bootstrap-server kafkasource:9092 --create --topic my-onprem-topic --partitions 6 --replication-factor 1
```

### List the created topic
```
docker exec -it kafkasource \
  kafka-topics --bootstrap-server kafkasource:9092 --list
```

### Launch the console producer and consumer on the source cluster
```
docker exec -it kafkasource \
  kafka-console-producer --broker-list kafkasource:9092 --topic my-onprem-topic
```

```
docker exec -it kafkasource \
  kafka-console-consumer --bootstrap-server kafkasource:9092 --topic my-onprem-topic --from-beginning
```

### List the topics on the SOURCE cluster
```
docker exec -it kafkasource \
  kafka-topics --bootstrap-server kafkasource:9092 --list
```

### List the topics on the DESTINATION cluster
```
docker exec -it kafkadest \
  kafka-topics --bootstrap-server kafkadest:9092 --list
```

### List "my-onprem-topic-replica" topic on DESTINATION cluster
```
docker exec -it kafkadest \
  kafka-topics --bootstrap-server kafkadest:9092 --describe --topic my-onprem-topic-replica
```

### Launch consumer on replica at the DESTINATION cluster
```
docker exec -it kafkadest \
  kafka-console-consumer --bootstrap-server kafkadest:9092 --topic my-onprem-topic-replica --from-beginning
```


### Remove the connector if required
```
curl -X DELETE http://localhost:8083/connectors/replicator
```