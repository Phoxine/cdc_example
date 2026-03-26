# CDC_Example

## introduction

Changed Data Capture (CDC) is a technique used to track and capture changes made to data in a database. It allows you to identify and capture insertions, updates, and deletions of data in real-time or near real-time. CDC is commonly used for data replication, data warehousing, and real-time analytics.

you can see more information about CDC in this [links](https://debezium.io/documentation/reference/stable/tutorial.html#considerations-running-debezium-docker)

## setup

### start the services
```
docker compose up
```

### access pgweb via the following url:
```
http://localhost:8081/
```

### create a table named users in the postgres database
```
create table users(
  id UUID PRIMARY key,
  name VARCHAR(32) NOT NULL,
  created_data timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_active bool NOT NULL DEFAULT false
)
```

### create a role for debezium with replication permission
```
CREATE ROLE debezium WITH LOGIN PASSWORD 'dbz' REPLICATION;
```


### set up debezium connector

This step registers a Debezium PostgreSQL source connector with Kafka Connect REST API.

- `name`: connector identifier
- `connector.class`: Debezium PostgreSQL connector class
- `database.*`: PostgreSQL source database connection settings
- `database.server.name`: logical server name in Kafka topic namespace
- `plugin.name`: PostgreSQL replication plugin (`pgoutput` for Debezium 8+)
- `slot.name` + `publication.name`: persistence for CDC position and subscribed data
- `table.include.list`: only captures changes from `public.users`
- `schema.history.internal.kafka.*`: stores schema history in Kafka topic

running the following command in the terminal
```
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "postgres-connector",
    "config": {
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "db",
      "database.port": "5432",
      "database.user": "postgres",
      "database.password": "postgres",
      "database.server.id": "184054",
      "database.dbname": "postgres",
      "database.server.name": "pgserver1",
      "plugin.name": "pgoutput",
      "slot.name": "debezium_slot",
      "publication.name": "debezium_pub",
      "table.include.list": "public.users",
      "topic.prefix": "dbserver1",
      "schema.history.internal.kafka.bootstrap.servers": "broker:9092",
      "schema.history.internal.kafka.topic": "schema-changes.users"
    }
}'
```


### execute insert users sql via pgweb
```
INSERT INTO users (id, name, created_data, is_active)
VALUES (
  '550e8400-e29b-41d4-a716-446655440000',
  'Alice',
  CURRENT_TIMESTAMP,
  true
);
```

### debezium connector log:

```
kafkaconnect-1  | 2026-03-25 02:55:53,610 INFO   ||  1 records sent during previous 00:00:40.161, last recorded offset of {server=dbserver1} partition is {lsn_proc=24997760, messageType=INSERT, lsn=24997760, txId=773, ts_usec=1774407353055367}   [io.debezium.connector.common.BaseSourceTask]
```

### enter kafka container
```
docker exec -it {kafka_container} /bin/bash
```
### consume messages from the topic
```
kafka-console-consumer.sh \
  --bootstrap-server broker:9092 \
  --topic dbserver1.public.users \
  --from-beginning
```

### you should see the following message in the console:
```
"payload": {
    "before": null,
    "after": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Alice",
      "created_data": 1774407353054330,
      "is_active": true
    },
    "source": {
      "version": "2.7.3.Final",
      "connector": "postgresql",
      "name": "dbserver1",
      "ts_ms": 1774407353055,
      "snapshot": "false",
      "db": "postgres",
      "sequence": "[null,\"24997760\"]",
      "ts_us": 1774407353055367,
      "ts_ns": 1774407353055367000,
      "schema": "public",
      "table": "users",
      "txId": 773,
      "lsn": 24997760,
      "xmin": null
    },
    "transaction": null,
    "op": "c",
    "ts_ms": 1774407353274,
    "ts_us": 1774407353274371,
    "ts_ns": 1774407353274371600
  }
```

## follow up

```
Postgres
   ↓ (CDC)
Debezium Connector
   ↓
Kafka Topic
   ↓
Sink Connector
   ↓
Elasticsearch / ClickHouse
```

### Elasticsearch

[information](https://debezium.io/blog/2018/01/17/streaming-to-elasticsearch/)

add the following code to the compose.yaml file to start an elasticsearch container
```
elasticsearch:
  image: docker.io/library/elasticsearch:9.3.2
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
  ports:
    - "9200:9200"
```

install the elasticsearch sink connector by running the following command in the terminal
```
docker exec -it {debezium_container} bash
confluent-hub install confluentinc/kafka-connect-elasticsearch:latest
```

create a connector to sink data from the topic to elasticsearch by running the following command in the terminal
```
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "es-sink",
    "config": {
      "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
      "topics": "dbserver1.public.users",
      "connection.url": "http://elasticsearch:9200",
      "key.ignore": "true",
      "schema.ignore": "true",
      "transforms": "unwrap",
      "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
      "transforms.unwrap.drop.tombstones": "false"
    }
}'
```
test
```
curl http://localhost:9200/dbserver1.public.users/_search
```
should see the following message in the console:
```
{
  "_source": {
    "id": "...",
    "name": "Alice"
  }
}
```
