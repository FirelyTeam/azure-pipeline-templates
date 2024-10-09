#!/bin/bash

command=$1
retries=10
count=0

echo "Scan command: $command"
echo "Starting scan with retries..."

while [ $count -lt $retries ]; do
  log_output=$($command 2>&1)
  echo "$log_output"
  if echo "$log_output" | grep "Fatal" | grep "failed to download artifact from any source" | grep -q "failed to download vulnerability DB"; then
    count=$((count + 1))
    echo "Scan failed due to DB download error. Attempt $count/$retries. Retrying in 30 seconds..."
    sleep 30
  else
    if [ $? -eq 0 ]; then
      echo "Scan completed successfully."
      break
    else
      echo "Scan failed due to other errors."
      exit 1
    fi
  fi
done

if [ $count -eq $retries ]; then
  echo "Scan failed after $retries attempts due to DB download error."
  exit 1
fi