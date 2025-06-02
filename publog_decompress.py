#!/usr/bin/env python3
"""
PUB LOG Decompressor using DLA DLLs
Decompresses TAB files from PUB LOG/FED LOG DVDs using the official DLA libraries
"""

import os
import sys
import platform
import subprocess
from pathlib import Path
import csv

def decompress_with_wine(publog_dir, output_dir):
    """
    Decompress PUB LOG files using Wine and the Windows decompression utility.
    
    Args:
        publog_dir: Path to the PUB LOG DVD directory
        output_dir: Path to output directory for decompressed files
    """
    publog_path = Path(publog_dir)
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Key files we want to decompress for NSN data
    key_files = [
        'V_FLIS_NSN.TAB',          # Main NSN data
        'V_FLIS_PART.TAB',         # Part number cross-references
        'V_MOE_RULE.TAB',          # MOE rules (supply codes, etc.)
        'V_CAGE_ADDRESS.TAB',      # CAGE codes and addresses
        'V_CAGE_STATUS_AND_TYPE.TAB',  # CAGE status info
        'V_CHARACTERISTICS.TAB',   # Item characteristics
        'V_FLIS_MANAGEMENT.TAB',   # Management data
        'V_FLIS_PHRASE.TAB',       # Phrase data
    ]
    
    # Change to PUB LOG directory for Wine
    original_dir = os.getcwd()
    os.chdir(publog_path)
    
    try:
        for tab_file in key_files:
            if not Path(tab_file).exists():
                print(f"Skipping {tab_file} - not found")
                continue
                
            print(f"Processing {tab_file}...")
            
            # Use Wine to run the Windows Decomp.exe
            # The decompressed file will be created without extension
            output_name = tab_file.replace('.TAB', '')
            cmd = ['wine', 'TOOLS/UTILITIES/Decomp.exe', tab_file, output_name]
            
            try:
                # Run the decompression
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0 or Path(output_name).exists():
                    # Move and rename to output directory as TSV
                    source = Path(output_name)
                    dest = output_path / f"{output_name}.tsv"
                    
                    if source.exists():
                        # The Decomp.exe creates a file without extension
                        source.rename(dest)
                        print(f"  ✓ Decompressed to {dest}")
                    else:
                        print(f"  ✗ Decompression failed - no output file created")
                else:
                    print(f"  ✗ Decompression failed: {result.stderr}")
                    
            except Exception as e:
                print(f"  ✗ Error processing {tab_file}: {e}")
                
    finally:
        os.chdir(original_dir)
    
    print("\nDecompression complete!")
    print(f"Decompressed files are in: {output_path}")
    
    # Return paths to key decompressed files
    return {
        'nsn': output_path / 'V_FLIS_NSN.tsv',
        'part': output_path / 'V_FLIS_PART.tsv',
        'moe': output_path / 'V_MOE_RULE.tsv',
        'cage': output_path / 'V_CAGE_ADDRESS.tsv',
    }


def extract_nsn_data_for_import(decompressed_files, output_csv):
    """
    Extract NSN data from decompressed files and create a CSV suitable for import.
    
    This reads the decompressed TSV files and creates a consolidated CSV
    that matches the expected format for the Go NSN service.
    """
    print("\nExtracting NSN data for import...")
    
    # Read the schema file to understand column structure
    schema_path = Path(decompressed_files['nsn']).parent.parent / 'TOOLS' / 'UTILITIES' / 'SCHEMA.TXT'
    
    # Column names based on typical FLIS structure
    # You'll need to verify these against SCHEMA.TXT
    nsn_columns = [
        'NIIN', 'FSC', 'NIIN_FSC', 'ITEM_NAME', 'INC', 'UNIT_ISSUE',
        'UNIT_PRICE', 'DEMIL_CODE', 'DEMIL_IC', 'SOS', 'SOS_IC',
        'AAC', 'QUP', 'QUP_UI', 'JTC', 'JTC_QTY', 'JTC_UI',
        'CONTROLLED_INV_ITEM_CODE', 'CIIC_CATEGORY',
        'HAZMAT_CODE', 'ESD_CODE', 'PMIC', 'ADPEC', 'ENAC'
    ]
    
    # Read NSN data
    nsn_data = []
    if decompressed_files['nsn'].exists():
        print(f"Reading NSN data from {decompressed_files['nsn']}...")
        try:
            with open(decompressed_files['nsn'], 'r', encoding='utf-8', errors='ignore') as f:
                reader = csv.reader(f, delimiter='\t')
                for row in reader:
                    if len(row) >= 7:  # Minimum required fields
                        niin = row[0].strip()
                        fsc = row[1].strip() if len(row) > 1 else ''
                        nsn = fsc + niin if fsc and niin else ''
                        
                        if nsn and len(nsn) == 13:  # Valid NSN length
                            nsn_data.append({
                                'NSN': nsn,
                                'NIIN': niin,
                                'FSC': fsc,
                                'ITEM_NAME': row[3].strip() if len(row) > 3 else '',
                                'UNIT_ISSUE': row[5].strip() if len(row) > 5 else '',
                                'UNIT_PRICE': row[6].strip() if len(row) > 6 else '0',
                                'AAC': row[11].strip() if len(row) > 11 else '',
                            })
        except Exception as e:
            print(f"Error reading NSN data: {e}")
    
    # Read part number cross-references
    part_map = {}
    if decompressed_files['part'].exists():
        print(f"Reading part data from {decompressed_files['part']}...")
        try:
            with open(decompressed_files['part'], 'r', encoding='utf-8', errors='ignore') as f:
                reader = csv.reader(f, delimiter='\t')
                for row in reader:
                    if len(row) >= 4:
                        niin = row[0].strip()
                        cage = row[1].strip()
                        part_no = row[2].strip()
                        if niin not in part_map:
                            part_map[niin] = []
                        part_map[niin].append({'cage': cage, 'part_no': part_no})
        except Exception as e:
            print(f"Error reading part data: {e}")
    
    # Read CAGE data
    cage_map = {}
    if decompressed_files['cage'].exists():
        print(f"Reading CAGE data from {decompressed_files['cage']}...")
        try:
            with open(decompressed_files['cage'], 'r', encoding='utf-8', errors='ignore') as f:
                reader = csv.reader(f, delimiter='\t')
                for row in reader:
                    if len(row) >= 2:
                        cage = row[0].strip()
                        name = row[1].strip()
                        cage_map[cage] = name
        except Exception as e:
            print(f"Error reading CAGE data: {e}")
    
    # Write consolidated CSV for import
    print(f"Writing consolidated data to {output_csv}...")
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow([
            'NSN', 'LIN', 'ITEM_NAME', 'DESCRIPTION', 'CATEGORY',
            'MANUFACTURER', 'PART_NUMBER', 'UNIT_ISSUE', 'UNIT_PRICE', 'AAC'
        ])
        
        for item in nsn_data:
            # Get first part number and manufacturer if available
            parts = part_map.get(item['NIIN'], [])
            if parts:
                part = parts[0]
                manufacturer = cage_map.get(part['cage'], part['cage'])
                part_number = part['part_no']
            else:
                manufacturer = ''
                part_number = ''
            
            # Convert unit price from cents to dollars
            try:
                unit_price = float(item['UNIT_PRICE']) / 100.0
            except:
                unit_price = 0.0
            
            writer.writerow([
                item['NSN'],
                '',  # LIN - would need to be mapped from Army-specific data
                item['ITEM_NAME'],
                '',  # Description - could be populated from characteristics
                item['FSC'],  # Using FSC as category
                manufacturer,
                part_number,
                item['UNIT_ISSUE'],
                f"{unit_price:.2f}",
                item['AAC']
            ])
    
    print(f"✓ Extracted {len(nsn_data)} NSN records")
    return len(nsn_data)


def main():
    """Main function to decompress PUB LOG data and prepare for import."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Decompress PUB LOG data for import')
    parser.add_argument('publog_dir', help='Path to PUB LOG DVD directory')
    parser.add_argument('--output-dir', default='./publog_data', 
                       help='Output directory for decompressed files')
    parser.add_argument('--csv-output', default='./nsn_import.csv',
                       help='Output CSV file for import')
    
    args = parser.parse_args()
    
    # Step 1: Decompress the TAB files
    decompressed_files = decompress_with_wine(args.publog_dir, args.output_dir)
    
    # Step 2: Extract and consolidate data for import
    if any(f.exists() for f in decompressed_files.values() if f):
        record_count = extract_nsn_data_for_import(decompressed_files, args.csv_output)
        print(f"\n✅ Success! Created {args.csv_output} with {record_count} records")
        print("\nNext steps:")
        print("1. Review the CSV file to ensure data quality")
        print("2. Import into your Go application using the NSN service's ImportFromCSV method")
    else:
        print("\n❌ No decompressed files found. Decompression may have failed.")
        return 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main()) 