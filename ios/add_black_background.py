#!/usr/bin/env python3

import os
from PIL import Image

def add_black_background(input_path, output_path):
    """Add black background to an image with transparency"""
    # Open the image
    img = Image.open(input_path).convert("RGBA")
    
    # Create a black background
    background = Image.new("RGBA", img.size, (0, 0, 0, 255))
    
    # Composite the image onto the black background
    background.paste(img, (0, 0), img)
    
    # Convert to RGB (remove alpha channel) and save
    background.convert("RGB").save(output_path, "PNG")
    print(f"Processed: {os.path.basename(output_path)}")

def main():
    iconset_dir = "HandReceipt/Assets.xcassets/AppIcon.appiconset"
    
    # Process all PNG files in the iconset directory
    for filename in os.listdir(iconset_dir):
        if filename.endswith(".png") and filename != "Contents.json":
            input_path = os.path.join(iconset_dir, filename)
            output_path = input_path  # Overwrite the original
            
            add_black_background(input_path, output_path)
    
    print("\nAll icons now have black backgrounds!")

if __name__ == "__main__":
    # Check if PIL/Pillow is installed
    try:
        import PIL
        main()
    except ImportError:
        print("Pillow is not installed. Install it with:")
        print("pip3 install Pillow")
        print("\nAlternatively, you can:")
        print("1. Use the online tool https://www.appicon.co")
        print("2. Upload your hr_icon.png")
        print("3. Select 'iOS' platform")
        print("4. Choose black background color")
        print("5. Download and extract the icons to HandReceipt/Assets.xcassets/AppIcon.appiconset/") 