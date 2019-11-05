#!/bin/bash

# Stop Confluent Platform using docker compose
docker-compose down

# Remove unused docker volumes
 docker volume prune -f
 