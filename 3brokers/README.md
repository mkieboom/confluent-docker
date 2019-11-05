Confluent Cloud 2 Onprem

### Launch local Confluent cluster with 3 brokers using Docker
```
git clone https://github.com/mkieboom/confluent-docker
cd confluent-docker/3brokers
./start.sh
```

Wait a minute or two to let the Docker environment launch
Open a browser to http://localhost:9021

### Create a topic in Confluent Cloud
Follow the "CLI and client configuration" in https://confluent.cloud/ to create the "test-topic"

### Configure Confluent Replicator on the ONPREM cluster
NOTE: please make sure to change the following items in below REST API call:
src.kafka.bootstrap.servers - to reflect your confluent cloud cluster
src.kafka.sasl.jaas.config - username & password to reflect your API_KEY and API_SECRET

```
curl -X POST http://localhost:8083/connectors \
-H "Content-Type: application/json" \
-d \
'{
  "name": "replicator",
  "config": {
    "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
    "topic.whitelist": "test-topic",
    "topic.rename.format":"${topic}-replica",
    "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
    "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
    "src.kafka.bootstrap.servers": "my.confluent.cloud:9092",
    "src.kafka.security.protocol": "SASL_SSL",
    "src.kafka.sasl.mechanism": "PLAIN",
    "src.kafka.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"MY_API_KEY\" password=\"MY_API_SECRET\";",
    "dest.kafka-replication.factor": 3,
    "dest.kafka.bootstrap.servers": "kafka1:9092",
    "src.consumer.group.id": "connect-replicator",
    "src.consumer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor",
    "tasks.max": "1"
  }
}'
```

Validate the connector got deployed correctly
```
curl -X GET http://localhost:8083/connectors 
```

# Wait a minute or two to allow Replicator to connect with the Confluent Cloud and automatically create the ONPREM topic

# List topics on ONPREM cluster
docker-compose exec kafka1 bash -c 'kafka-topics --bootstrap-server localhost:9092 --list'

# Read messages from ONPREM topic
docker-compose exec kafka1 bash -c 'kafka-console-consumer --bootstrap-server localhost:9092 --topic test-topic-replica --from-beginning'

# Write more messages to the CLOUD topic and notice they will show up in the ONPREM topic
ccloud kafka topic produce test-topic
hello
world


# Cleanup
curl -X DELETE http://localhost:8083/connectors/replicator
