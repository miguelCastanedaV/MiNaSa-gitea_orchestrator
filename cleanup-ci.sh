#!/bin/bash
docker ps -aq --filter "ancestor=mysql:8" | xargs -r docker stop 2>/dev/null
docker ps -aq --filter "ancestor=mysql:8" | xargs -r docker rm -f 2>/dev/null
docker ps -aq --filter "ancestor=redis:7-alpine" | xargs -r docker stop 2>/dev/null
docker ps -aq --filter "ancestor=redis:7-alpine" | xargs -r docker rm -f 2>/dev/null
