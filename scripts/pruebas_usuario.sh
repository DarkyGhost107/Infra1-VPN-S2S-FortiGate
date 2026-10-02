#!/bin/bash
# Pruebas desde el usuario (Linux) - Diego 2023-0316
SRV="${1:-10.23.16.130}"
echo "===== $(date) ====="
echo "--- IP recibida por DHCP ---"; ip -4 addr show | grep inet
echo "--- Ping al servidor $SRV ---"; ping -c 4 $SRV
echo "--- Traceroute al servidor ---"; traceroute -n -I $SRV
echo "--- HTTPS ---"; curl -k -s -o /dev/null -w "Codigo HTTP: %{http_code}\n" https://$SRV
