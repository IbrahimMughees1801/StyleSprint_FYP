"""
Install StyleSprint logo files to Flutter project
"""

import os
import shutil
import json

def copy_android_icons():
    """Copy Android icons to the correct locations"""
    print("\n📱 Installing Android icons...")
    
    android_mappings = {
        'mipmap-mdpi': 'android/app/src/main/res/mipmap-mdpi',
        'mipmap-hdpi': 'android/app/src/main/res/mipmap-hdpi',
        'mipmap-xhdpi': 'android/app/src/main/res/mipmap-xhdpi',
        'mipmap-xxhdpi': 'android/app/src/main/res/mipmap-xxhdpi',
        'mipmap-xxxhdpi': 'android/app/src/main/res/mipmap-xxxhdpi',
    }
    
    for folder, dest_path in android_mappings.items():
        source = os.path.join('app_logos', 'android', folder, 'ic_launcher.png')
        
        # Create destination directory
        os.makedirs(dest_path, exist_ok=True)
        
        if os.path.exists(source):
            dest = os.path.join(dest_path, 'ic_launcher.png')
            shutil.copy2(source, dest)
            print(f"✓ Copied to {dest}")

def copy_ios_icons():
    """Copy iOS icons to the correct locations"""
    print("\n🍎 Installing iOS icons...")
    
    # Create AppIcon.appiconset directory
    ios_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(ios_dir, exist_ok=True)
    
    # Copy all iOS icons
    ios_source_dir = 'app_logos/ios'
    if os.path.exists(ios_source_dir):
        for filename in os.listdir(ios_source_dir):
            if filename.endswith('.png'):
                source = os.path.join(ios_source_dir, filename)
                dest = os.path.join(ios_dir, filename)
                shutil.copy2(source, dest)
                print(f"✓ Copied {filename}")
    
    # Create Contents.json for iOS
    contents = {
        "images": [
            {"size": "20x20", "idiom": "iphone", "filename": "AppIcon-20x20@2x.png", "scale": "2x"},
            {"size": "20x20", "idiom": "iphone", "filename": "AppIcon-20x20@3x.png", "scale": "3x"},
            {"size": "29x29", "idiom": "iphone", "filename": "AppIcon-29x29@1x.png", "scale": "1x"},
            {"size": "29x29", "idiom": "iphone", "filename": "AppIcon-29x29@2x.png", "scale": "2x"},
            {"size": "29x29", "idiom": "iphone", "filename": "AppIcon-29x29@3x.png", "scale": "3x"},
            {"size": "40x40", "idiom": "iphone", "filename": "AppIcon-40x40@2x.png", "scale": "2x"},
            {"size": "40x40", "idiom": "iphone", "filename": "AppIcon-40x40@3x.png", "scale": "3x"},
            {"size": "60x60", "idiom": "iphone", "filename": "AppIcon-60x60@2x.png", "scale": "2x"},
            {"size": "60x60", "idiom": "iphone", "filename": "AppIcon-60x60@3x.png", "scale": "3x"},
            {"size": "20x20", "idiom": "ipad", "filename": "AppIcon-20x20@1x.png", "scale": "1x"},
            {"size": "20x20", "idiom": "ipad", "filename": "AppIcon-20x20@2x.png", "scale": "2x"},
            {"size": "29x29", "idiom": "ipad", "filename": "AppIcon-29x29@1x.png", "scale": "1x"},
            {"size": "29x29", "idiom": "ipad", "filename": "AppIcon-29x29@2x.png", "scale": "2x"},
            {"size": "40x40", "idiom": "ipad", "filename": "AppIcon-40x40@1x.png", "scale": "1x"},
            {"size": "40x40", "idiom": "ipad", "filename": "AppIcon-40x40@2x.png", "scale": "2x"},
            {"size": "76x76", "idiom": "ipad", "filename": "AppIcon-76x76@1x.png", "scale": "1x"},
            {"size": "76x76", "idiom": "ipad", "filename": "AppIcon-76x76@2x.png", "scale": "2x"},
            {"size": "83.5x83.5", "idiom": "ipad", "filename": "AppIcon-83.5x83.5@2x.png", "scale": "2x"},
            {"size": "1024x1024", "idiom": "ios-marketing", "filename": "AppIcon-1024x1024@1x.png", "scale": "1x"}
        ],
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }
    
    contents_path = os.path.join(ios_dir, 'Contents.json')
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    print(f"✓ Created {contents_path}")

def copy_web_icons():
    """Copy web icons"""
    print("\n🌐 Installing web icons...")
    
    web_icons = [
        ('icon_192x192.png', 'web/icons/Icon-192.png'),
        ('icon_512x512.png', 'web/icons/Icon-512.png'),
    ]
    
    for source_name, dest_path in web_icons:
        source = os.path.join('app_logos', source_name)
        
        # Create web/icons directory if it doesn't exist
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        
        if os.path.exists(source):
            shutil.copy2(source, dest_path)
            print(f"✓ Copied to {dest_path}")
    
    # Also copy a favicon
    favicon_source = 'app_logos/icon_48x48.png'
    if os.path.exists(favicon_source):
        shutil.copy2(favicon_source, 'web/favicon.png')
        print(f"✓ Copied favicon to web/favicon.png")

def update_web_manifest():
    """Update web manifest with new icons"""
    print("\n📝 Updating web manifest...")
    
    manifest_path = 'web/manifest.json'
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        
        # Update icons
        manifest['icons'] = [
            {
                "src": "icons/Icon-192.png",
                "sizes": "192x192",
                "type": "image/png",
                "purpose": "maskable any"
            },
            {
                "src": "icons/Icon-512.png",
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "maskable any"
            }
        ]
        
        # Update name if needed
        manifest['name'] = 'StyleSprint'
        manifest['short_name'] = 'StyleSprint'
        
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print(f"✓ Updated {manifest_path}")

def main():
    print("🚀 Installing StyleSprint Logo to Flutter Project")
    print("=" * 60)
    
    try:
        copy_android_icons()
        copy_ios_icons()
        copy_web_icons()
        update_web_manifest()
        
        print("\n" + "=" * 60)
        print("✅ Logo installation complete!")
        print("\nNext steps:")
        print("1. For Android: The icons are automatically used")
        print("2. For iOS: Run 'flutter clean' and rebuild")
        print("3. For Web: The icons will be used on next build")
        print("\nYou may need to uninstall and reinstall the app to see the new icon.")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
