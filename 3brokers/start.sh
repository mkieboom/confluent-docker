#!/bin/bash

# Launch Confluent Platform using docker compose
docker-compose up -d

echo "Sleeping 120 seconds to wait for all services to come up"
sleep 120
