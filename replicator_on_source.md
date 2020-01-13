# Run Replicator on source cluster

### Goal
Launch Confluent Replicator on the source cluster 

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

### Kafka Connect configuration:
### As Replicator is running on the source, Kafka Connect is mandatory to point to the destination cluster, eg:
```
CONNECT_BOOTSTRAP_SERVERS: kafkadest:9092
```

### Deploying Replicator is done using the following curl command as outlined in the following documentation:
```
curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicator",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.zookeeper.connect": "zookeepersource:2181",
          "src.kafka.bootstrap.servers": "kafkasource:9092",
          "dest.zookeeper.connect": "zookeeperdest:2181",
          "dest.kafka.bootstrap.servers": "kafkadest:9092",
          "dest.kafka.replication.factor": "1",
          "tasks.max": "1",
          "confluent.topic.replication.factor": "1",
          "topic.whitelist": "my-onprem-topic",
          "topic.rename.format": "${topic}-replica"}
          }'  \
          http://localhost:8083/connectors
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

### "my-onprem-topic-replica" topic on DESTINATION cluster
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