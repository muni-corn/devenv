#!/usr/bin/env bash

set -euo pipefail

echo "testing surrealdb service..."

# start the environment and run the test
devenv up &
DEVENV_PID=$!

# wait for services to start with timeout
timeout=30
elapsed=0
until devenv shell surrealdb-test 2>/dev/null; do
  if [ $elapsed -ge $timeout ]; then
    echo "error: timed out waiting for surrealdb to start"
    kill $DEVENV_PID || true
    wait $DEVENV_PID || true
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

echo "surrealdb test completed successfully!"

# clean up
kill $DEVENV_PID || true
wait $DEVENV_PID || true