#!/bin/bash
# Nightly Docker Cleanup Script
# Deletes stopped containers, unused networks, and dangling images.

echo "Running Docker Prune..."
docker system prune -f

# Check for disk usage
USAGE=$(df -h / | awk 'NR==2 {print $5}')
echo "Disk Usage: $USAGE"
