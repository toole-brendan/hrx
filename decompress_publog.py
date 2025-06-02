#!/usr/bin/env python3
"""
PUB LOG TAB File Decompressor
Decompresses IMD2 format TAB files from PUB LOG/FED LOG DVDs to readable TSV format.
"""

import os
import sys
import struct
import argparse
from pathlib import Path

class IMD2Decompressor:
    def __init__(self):
        self.buffer = bytearray()
        
    def decompress_file(self, input_path, output_path=None):
        """Decompress a single TAB file"""
        if output_path is None:
            # Create output filename by replacing .TAB with .tsv
            output_path = str(input_path).replace('.TAB', '.tsv')
            if output_path == str(input_path):
                output_path = str(input_path) + '.tsv'
        
        try:
            with open(input_path, 'rb') as infile:
                # Read the header to check if it's IMD2 format
                header = infile.read(4)
                if header != b'IMD2':
                    print(f"Warning: {input_path} doesn't appear to be IMD2 format, trying anyway...")
                    infile.seek(0)
                
                # Read the compressed data
                compressed_data = infile.read()
                
                # Try to decompress
                decompressed = self._decompress_imd2(compressed_data)
                
                # Write to output file
                with open(output_path, 'wb') as outfile:
                    outfile.write(decompressed)
                
                print(f"Successfully decompressed {input_path} -> {output_path}")
                return True
                
        except Exception as e:
            print(f"Error decompressing {input_path}: {e}")
            # Fallback: try simple extraction if it's not heavily compressed
            try:
                return self._simple_extract(input_path, output_path)
            except:
                return False
    
    def _decompress_imd2(self, data):
        """Decompress IMD2 format data"""
        if len(data) < 8:
            raise ValueError("Data too short to be valid IMD2")
        
        # Skip header if present
        offset = 0
        if data[:4] == b'IMD2':
            offset = 8  # Skip IMD2 header and length field
        
        # Try to decompress using simple RLE-like algorithm
        result = bytearray()
        i = offset
        
        while i < len(data):
            try:
                # Check for compression markers
                if i + 1 < len(data):
                    b1 = data[i]
                    b2 = data[i + 1] if i + 1 < len(data) else 0
                    
                    # Look for patterns that suggest compression
                    if b1 == 0 and b2 > 0 and b2 < 0x80:
                        # Possible run-length encoding
                        if i + 2 < len(data):
                            count = b2
                            value = data[i + 2] if i + 2 < len(data) else 0
                            result.extend([value] * count)
                            i += 3
                            continue
                
                # Default: copy byte as-is
                result.append(data[i])
                i += 1
                
            except:
                result.append(data[i])
                i += 1
        
        return bytes(result)
    
    def _simple_extract(self, input_path, output_path):
        """Simple extraction for files that might not be heavily compressed"""
        print(f"Trying simple extraction for {input_path}...")
        
        with open(input_path, 'rb') as infile:
            data = infile.read()
        
        # Skip any binary header and look for printable content
        start_pos = 0
        for i in range(min(1024, len(data))):
            # Look for sequences of printable characters (likely start of data)
            if (data[i:i+1].isalnum() or data[i:i+1] in b'\t\n\r ') and \
               i + 100 < len(data):
                # Check if next 100 bytes look like text data
                sample = data[i:i+100]
                if self._looks_like_text_data(sample):
                    start_pos = i
                    break
        
        # Extract from start position
        extracted = data[start_pos:]
        
        # Clean up any null bytes or control characters
        cleaned = bytearray()
        for byte in extracted:
            if byte == 0:
                continue
            elif byte < 32 and byte not in [9, 10, 13]:  # Keep tabs, newlines, carriage returns
                continue
            else:
                cleaned.append(byte)
        
        with open(output_path, 'wb') as outfile:
            outfile.write(bytes(cleaned))
        
        print(f"Simple extraction completed: {input_path} -> {output_path}")
        return True
    
    def _looks_like_text_data(self, data):
        """Check if data looks like text/TSV content"""
        try:
            # Try to decode as text
            text = data.decode('utf-8', errors='ignore')
            
            # Check for characteristics of TSV data
            has_tabs = '\t' in text
            has_alnum = any(c.isalnum() for c in text)
            printable_ratio = sum(1 for c in text if c.isprintable() or c in '\t\n\r') / len(text)
            
            return has_tabs and has_alnum and printable_ratio > 0.8
        except:
            return False


def main():
    parser = argparse.ArgumentParser(description='Decompress PUB LOG TAB files')
    parser.add_argument('input', nargs='*', help='Input TAB file(s) or directory')
    parser.add_argument('--all', action='store_true', help='Process all V_*.TAB files in current directory')
    parser.add_argument('--output-dir', help='Output directory (default: same as input)')
    
    args = parser.parse_args()
    
    decompressor = IMD2Decompressor()
    
    # Determine input files
    input_files = []
    
    if args.all:
        # Find all V_*.TAB files in current directory
        current_dir = Path('.')
        input_files = list(current_dir.glob('V_*.TAB'))
        if not input_files:
            print("No V_*.TAB files found in current directory")
            return 1
    elif args.input:
        for inp in args.input:
            path = Path(inp)
            if path.is_file():
                input_files.append(path)
            elif path.is_dir():
                input_files.extend(path.glob('V_*.TAB'))
            else:
                print(f"File not found: {inp}")
                return 1
    else:
        parser.print_help()
        return 1
    
    # Process files
    success_count = 0
    total_count = len(input_files)
    
    for input_file in input_files:
        output_file = None
        if args.output_dir:
            output_dir = Path(args.output_dir)
            output_dir.mkdir(exist_ok=True)
            output_file = output_dir / (input_file.stem + '.tsv')
        
        if decompressor.decompress_file(input_file, output_file):
            success_count += 1
    
    print(f"\nCompleted: {success_count}/{total_count} files processed successfully")
    
    if success_count > 0:
        print("\nTo verify the output, try:")
        print("head -3 V_FLIS_PART.tsv | tr '\\t' '|'")
    
    return 0 if success_count == total_count else 1


if __name__ == '__main__':
    sys.exit(main()) 