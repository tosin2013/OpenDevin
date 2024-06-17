#!/bin/bash

# Define the container image name
CONTAINER_IMAGE="ghcr.io/opendevin/sandbox:main"

# Find and kill the Docker container
CONTAINER_ID=$(docker ps -q -f ancestor=$CONTAINER_IMAGE)
if [ -n "$CONTAINER_ID" ]; then
    echo "Found container $CONTAINER_ID running image $CONTAINER_IMAGE, killing it..."
    docker kill $CONTAINER_ID
    docker rm $CONTAINER_ID
else
    echo "No container found running image $CONTAINER_IMAGE"
fi

# Find and kill the process listening on port 3000
PID=$(lsof -t -i :3000)
if [ -z "$PID" ]; then
    echo "No process found listening on port 3000"
else
    echo "Killing process $PID"
    kill -9 $PID
fi

echo "Cleanup complete."
