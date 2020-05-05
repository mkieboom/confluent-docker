# Use Replicator to replicate schema’s between two Schema Registries
Note: this configuration is not supported by Confluent and schema's can end up out of order in the destination schema registry.

### Deploy two clusters using Docker
```
git clone https://github.com/mkieboom/confluent-docker
cd confluent-docker/2clusters-1broker
docker-compose up -d
docker-compose ps
```

### Create a topic on the source cluster
```
docker exec -it kafkasource kafka-topics --bootstrap-server kafkasource:9092 --create --topic sourceclustertopic --replication-factor 1 --partitions 1

docker exec -it schema-registrysource kafka-avro-console-producer --broker-list kafkasource:9092 --topic sourceclustertopic \
--property value.schema='{
    "type": "record",
    "name": "product",
    "fields": [
      { "name": "customer_id", "type": "int", "doc": "Customer ID" },
      { "name": "firstname", "type": "string", "doc": "Customer firstname"},
      { "name": "lastname", "type": "string", "doc": "Customer lastname" }
    ]
}'
{"customer_id": 1, "firstname": "Ewan", "lastname": "Thomas"}
{"customer_id": 2, "firstname": "James", "lastname": "Read"}
{"customer_id": 3, "firstname": "Kevin", "lastname": "Spencer"}
```

### List the schema with id 1 as that should be the just created schema
```
docker exec -it schema-registrysource curl -X GET http://localhost:8081/schemas/ids/1 | jq
```


### Create a dummy schema in the destination SR prior to starting replication to see if SR correctly creates a new schema
```
docker exec -it schema-registrydest curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\": \"string\"}"}' \
  http://localhost:8081/subjects/dummyschema/versions
```

### List the dummy created schema with id 1
```
docker exec -it schema-registrydest curl -X GET http://localhost:8081/schemas/ids/1 | jq
```

### Deploy replicator on the source cluster
```
docker exec -it connect curl -X POST \
-H "Content-Type: application/json" \
      --data '{
      "name": "replicator",
      "config": {
            "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
            "src.key.converter": "io.confluent.connect.avro.AvroConverter",
            "src.key.converter.schema.registry.url": "http://schema-registrysource:8081",
            "src.key.converter.schemas.enable": true,
            "src.value.converter": "io.confluent.connect.avro.AvroConverter",
            "src.value.converter.schema.registry.url": "http://schema-registrysource:8081",
            "src.value.converter.schemas.enable": true,
            "key.converter": "io.confluent.connect.avro.AvroConverter",
            "key.converter.schema.registry.url": "http://schema-registrydest:8081",
            "key.converter.schemas.enable": true,
            "value.converter": "io.confluent.connect.avro.AvroConverter",
            "value.converter.schema.registry.url": "http://schema-registrydest:8081",
            "value.converter.schemas.enable": true,
            "src.kafka.bootstrap.servers": "kafkasource:9092",
            "dest.kafka.bootstrap.servers": "kafkadest:9092",
            "producer.override.bootstrap.servers": "kafkadest:9092",
            "dest.kafka.replication.factor": "1",
            "tasks.max": "1",
            "confluent.topic.replication.factor": "1",
            "topic.whitelist": "sourceclustertopic",
            "topic.rename.format": "${topic}-replica"
      }}' \
      http://localhost:8083/connectors

# Following are optional fields in the above REST API call
# "src.header.converter": "io.confluent.connect.avro.AvroConverter",
# "src.header.converter.schema.registry.url": "http://schema-registrysource:8081",
# "src.header.converter.schemas.enable": true,
# "header.converter": "io.confluent.connect.avro.AvroConverter",
# "header.converter.schema.registry.url": "http://schema-registrydest:8081",
# "header.converter.schemas.enable": true,
```

### List te deployed connectors
```
docker exec -it connect curl -X GET localhost:8083/connectors
```

### List the replicated topic
```
docker exec -it kafkadest kafka-topics \
 --bootstrap-server localhost:9092 \
 --list
```

### CPN02 - Consume the events from the replicated topic
```
docker exec -it schema-registrydest \
  kafka-avro-console-consumer \
  --bootstrap-server kafkadest:9092 \
  --topic sourceclustertopic-replica \
  --from-beginning
```

### CPN02 - List the schema with id 2 as that should be the schema as created by the
```
docker exec -it schema-registrydest curl -X GET http://localhost:8081/schemas/ids/2 | jq
```

### CPN02 - Consume events from the replicated topic while using the SOURCE Schema Registry
```
# Not: This should fail as schema id 2 doesn't exist in the source schema registry, eg:
# org.apache.kafka.common.errors.SerializationException: Error retrieving Avro schema for id 2
docker exec -it schema-registrysource kafka-avro-console-consumer \
  --bootstrap-server kafkadest:9092 \
  --topic sourceclustertopic-replica \
  --property schema.registry.url=http://schema-registrysource:8081 \
  --from-beginning
```


### Cleanup
```
docker exec -it connect curl -X DELETE http://localhost:8083/connectors/replicator
```

### Connect logs
```
docker logs connect -f
```
