#!/usr/bin/env bash

#######################################
# Debug PRAM file to analyze boot order settings
# Usage: ./debug-pram.sh <pram_file>
#######################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <pram_file>"
    echo "Example: $0 755/pram_755_q800.img"
    exit 1
fi

pram_file="$1"

if [ ! -f "$pram_file" ]; then
    echo "Error: PRAM file '$pram_file' not found"
    exit 1
fi

echo "PRAM Boot Order Analysis"
echo "========================"
echo "File: $pram_file"
echo "Size: $(stat -c%s "$pram_file") bytes"
echo ""

echo "Boot-related PRAM locations:"
echo "-----------------------------"

# Check offset 0x78 (120) - DriveId/PartitionId
echo "Offset 0x78 (120) - DriveId/PartitionId:"
hexdump -C -s 120 -n 1 "$pram_file" | sed 's/^/  /'

# Check offset 0x7A (122) - RefNum (main boot order)
echo "Offset 0x7A (122) - RefNum (boot order):"
hexdump -C -s 122 -n 2 "$pram_file" | sed 's/^/  /'

# Read the 16-bit RefNum value and calculate SCSI ID
if [ -s "$pram_file" ]; then
    # Read bytes at offset 122 (0x7A)
    byte1=$(hexdump -s 122 -n 1 -e '"%02x"' "$pram_file" 2>/dev/null)
    byte2=$(hexdump -s 123 -n 1 -e '"%02x"' "$pram_file" 2>/dev/null)
    
    if [ -n "$byte1" ] && [ -n "$byte2" ]; then
        # Convert hex to decimal (little-endian)
        byte1_dec=$((0x$byte1))
        byte2_dec=$((0x$byte2))
        refnum=$((byte1_dec + (byte2_dec << 8)))
        
        echo ""
        echo "RefNum Analysis:"
        echo "  Raw bytes: 0x$byte1 0x$byte2"
        echo "  RefNum value: 0x$(printf '%04x' $refnum) ($refnum)"
        
        # Calculate expected SCSI ID using Laurent's reverse formula
        # Note: bash arithmetic might have issues with large numbers, so we'll be careful
        if [ $refnum -eq 65503 ]; then
            echo "  Calculated SCSI ID: 0 (HDD) - matches 0xffdf"
        elif [ $refnum -eq 65501 ]; then
            echo "  Calculated SCSI ID: 2 (CD-ROM) - matches 0xffdd"
        else
            echo "  Calculated SCSI ID: Unknown RefNum value"
        fi
    fi
fi

echo ""
echo "Complete PRAM dump (first 32 bytes):"
echo "-----------------------------------"
hexdump -C -n 32 "$pram_file"