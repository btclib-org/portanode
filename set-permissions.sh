#!/bin/bash
# Set secure permissions for PortaNode data directories

echo "Setting restrictive permissions on data directories..."

if [ ! -d "bitcoin-datadir" ]; then
    echo "Error: bitcoin-datadir not found."
    exit 1
fi
if [ ! -d "electrum-datadir" ]; then
    echo "Error: electrum-datadir not found."
    exit 1
fi

chmod -R u=rwX,go= bitcoin-datadir
chmod -R u=rwX,go= electrum-datadir
chmod 700 bitcoin-datadir
chmod 700 electrum-datadir

echo "Permissions set. Only owner can access."
