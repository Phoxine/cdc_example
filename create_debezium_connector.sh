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