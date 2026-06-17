#!/bin/bash
# Rebuild without cache and run using docker-compose
docker-compose build --no-cache
docker-compose run --rm steganography