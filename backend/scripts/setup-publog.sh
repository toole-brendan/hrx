#!/bin/bash

# Setup script for PUB LOG data integration

set -e

echo "=== PUB LOG Data Setup Script ==="
echo ""

# Check if we're in the backend directory
if [ ! -f "go.mod" ]; then
    echo "Error: Please run this script from the backend directory"
    exit 1
fi

# Check if internal/publog directory exists
if [ ! -d "internal/publog" ]; then
    echo "Error: internal/publog directory not found"
    exit 1
fi

# Check for data files
echo "Checking for PUB LOG data files..."
DATA_DIR="internal/publog/data"

if [ -f "$DATA_DIR/master_nsn_all.txt" ]; then
    echo "✓ Found master_nsn_all.txt"
    NSN_COUNT=$(tail -n +2 "$DATA_DIR/master_nsn_all.txt" | wc -l | tr -d ' ')
    echo "  Contains $NSN_COUNT NSN records"
else
    echo "✗ master_nsn_all.txt not found in $DATA_DIR"
fi

if [ -f "$DATA_DIR/part_numbers_sample.txt" ]; then
    echo "✓ Found part_numbers_sample.txt"
    PART_COUNT=$(tail -n +2 "$DATA_DIR/part_numbers_sample.txt" | wc -l | tr -d ' ')
    echo "  Contains $PART_COUNT part number records"
else
    echo "✗ part_numbers_sample.txt not found in $DATA_DIR"
fi

if [ -f "$DATA_DIR/cage_addresses_sample.txt" ]; then
    echo "✓ Found cage_addresses_sample.txt"
    CAGE_COUNT=$(tail -n +2 "$DATA_DIR/cage_addresses_sample.txt" | wc -l | tr -d ' ')
    echo "  Contains $CAGE_COUNT CAGE records"
else
    echo "✗ cage_addresses_sample.txt not found in $DATA_DIR"
fi

echo ""

# Create config if needed
if [ ! -f "configs/config.yaml" ]; then
    echo "Creating config.yaml from example..."
    if [ -f "configs/config.example.yaml" ]; then
        cp configs/config.example.yaml configs/config.yaml
        echo "✓ Created configs/config.yaml"
        echo "  Please update the configuration with your settings"
    else
        echo "✗ config.example.yaml not found"
    fi
fi

echo ""

# Build the test CLI
echo "Building PUB LOG test CLI..."
if go build -o bin/publog-test cmd/publog-test/main.go; then
    echo "✓ Built publog-test CLI at bin/publog-test"
else
    echo "✗ Failed to build publog-test CLI"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Ensure your data files are in internal/publog/data/"
echo "2. Update configs/config.yaml with your settings"
echo "3. Test the integration: ./bin/publog-test -data internal/publog"
echo ""
echo "Example search queries:"
echo "  - NSN: 5820-01-546-5288"
echo "  - Part number: 12003100"
echo "  - Item name: camera television"
echo "  - CAGE code: 00000" 