"""
StyleSprint Logo Generator
Creates app logo with shopping cart and lightning bolt
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_logo(size=1024):
    """Create StyleSprint logo with shopping cart and lightning bolt"""
    
    # Create image with white background
    img = Image.new('RGB', (size, size), color='white')
    draw = ImageDraw.Draw(img)
    
    # Define colors
    primary_color = '#FF6B35'  # Orange/red
    accent_color = '#FFD700'   # Gold
    cart_color = '#2C3E50'     # Dark blue-gray
    
    # Calculate dimensions - make cart much bigger
    center_x = size // 2
    center_y = size // 2 - size // 10  # Move up slightly to center better with text
    cart_size = int(size * 0.6)  # Much bigger cart (60% of image)
    
    # Draw shopping cart
    # Cart body (trapezoid)
    cart_left = center_x - cart_size // 2
    cart_right = center_x + cart_size // 2
    cart_top = center_y - cart_size // 4
    cart_bottom = center_y + cart_size // 4
    
    # Cart body
    cart_body = [
        (cart_left + cart_size // 6, cart_top),
        (cart_right - cart_size // 6, cart_top),
        (cart_right, cart_bottom),
        (cart_left, cart_bottom)
    ]
    draw.polygon(cart_body, fill=cart_color, outline=cart_color)
    
    # Cart handle
    handle_width = size // 40
    handle_start_y = cart_top - cart_size // 3
    draw.arc(
        [cart_left - cart_size // 8, handle_start_y, 
         cart_left + cart_size // 4, cart_top + handle_width],
        180, 0, fill=cart_color, width=handle_width
    )
    
    # Cart wheels
    wheel_radius = cart_size // 10
    wheel_y = cart_bottom + wheel_radius
    # Left wheel
    draw.ellipse(
        [cart_left + cart_size // 6 - wheel_radius, wheel_y - wheel_radius,
         cart_left + cart_size // 6 + wheel_radius, wheel_y + wheel_radius],
        fill=cart_color, outline=cart_color
    )
    # Right wheel
    draw.ellipse(
        [cart_right - cart_size // 4 - wheel_radius, wheel_y - wheel_radius,
         cart_right - cart_size // 4 + wheel_radius, wheel_y + wheel_radius],
        fill=cart_color, outline=cart_color
    )
    
    # Draw lightning bolt in the CENTER of the cart
    lightning_x = center_x
    lightning_y = center_y - cart_size // 8
    lightning_size = int(cart_size * 0.5)  # Bigger lightning bolt
    
    # Better lightning bolt shape (more dramatic)
    lightning = [
        (lightning_x, lightning_y),
        (lightning_x - lightning_size // 3, lightning_y + lightning_size // 2),
        (lightning_x + lightning_size // 10, lightning_y + lightning_size // 2),
        (lightning_x - lightning_size // 4, lightning_y + lightning_size),
        (lightning_x + lightning_size // 3, lightning_y + int(lightning_size * 0.55)),
        (lightning_x + lightning_size // 10, lightning_y + int(lightning_size * 0.45))
    ]
    
    # Draw lightning with thicker outline for better visibility
    for offset in range(4):
        offset_lightning = [(x + offset, y) for x, y in lightning] + \
                          [(x - offset, y) for x, y in lightning] + \
                          [(x, y + offset) for x, y in lightning] + \
                          [(x, y - offset) for x, y in lightning]
        for shifted in offset_lightning[:6]:
            pass  # Just for the outline effect
    
    # Draw the actual lightning bolt
    draw.polygon(lightning, fill=accent_color, outline=primary_color)
    
    # Add text "StyleSprint" at the bottom - bigger and bolder
    text = "StyleSprint"
    text_y = center_y + cart_size // 2 + size // 15
    
    # Try to use a nice font, fallback to default - MUCH BIGGER
    try:
        font_size = size // 8  # Bigger font
        font = ImageFont.truetype("arialbd.ttf", font_size)  # Bold
    except:
        try:
            font = ImageFont.truetype("arial.ttf", size // 8)
        except:
            font = ImageFont.load_default()
    
    # Get text bounding box
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_x = center_x - text_width // 2
    
    # Draw text with shadow for better visibility
    shadow_offset = size // 100
    draw.text((text_x + shadow_offset, text_y + shadow_offset), text, fill='#888888', font=font)
    draw.text((text_x, text_y), text, fill=primary_color, font=font)
    
    return img

def save_logo_variants(base_img, output_dir):
    """Save logo in various sizes for mobile apps"""
    
    # Common icon sizes for mobile apps
    sizes = {
        'android': {
            'mipmap-mdpi': 48,
            'mipmap-hdpi': 72,
            'mipmap-xhdpi': 96,
            'mipmap-xxhdpi': 144,
            'mipmap-xxxhdpi': 192,
        },
        'ios': {
            'AppIcon-20x20@1x': 20,
            'AppIcon-20x20@2x': 40,
            'AppIcon-20x20@3x': 60,
            'AppIcon-29x29@1x': 29,
            'AppIcon-29x29@2x': 58,
            'AppIcon-29x29@3x': 87,
            'AppIcon-40x40@1x': 40,
            'AppIcon-40x40@2x': 80,
            'AppIcon-40x40@3x': 120,
            'AppIcon-60x60@2x': 120,
            'AppIcon-60x60@3x': 180,
            'AppIcon-76x76@1x': 76,
            'AppIcon-76x76@2x': 152,
            'AppIcon-83.5x83.5@2x': 167,
            'AppIcon-1024x1024@1x': 1024,
        }
    }
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Save main logo
    main_logo_path = os.path.join(output_dir, 'stylesprint_logo_1024.png')
    base_img.save(main_logo_path, 'PNG')
    print(f"✓ Saved main logo: {main_logo_path}")
    
    # Save Android variants
    android_dir = os.path.join(output_dir, 'android')
    for folder, size in sizes['android'].items():
        folder_path = os.path.join(android_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        resized = base_img.resize((size, size), Image.Resampling.LANCZOS)
        icon_path = os.path.join(folder_path, 'ic_launcher.png')
        resized.save(icon_path, 'PNG')
        print(f"✓ Saved Android icon: {icon_path}")
    
    # Save iOS variants
    ios_dir = os.path.join(output_dir, 'ios')
    os.makedirs(ios_dir, exist_ok=True)
    
    for name, size in sizes['ios'].items():
        resized = base_img.resize((size, size), Image.Resampling.LANCZOS)
        icon_path = os.path.join(ios_dir, f'{name}.png')
        resized.save(icon_path, 'PNG')
        print(f"✓ Saved iOS icon: {icon_path}")
    
    # Save standard size for web and other uses
    standard_sizes = [512, 192, 144, 96, 72, 48]
    for size in standard_sizes:
        resized = base_img.resize((size, size), Image.Resampling.LANCZOS)
        icon_path = os.path.join(output_dir, f'icon_{size}x{size}.png')
        resized.save(icon_path, 'PNG')
        print(f"✓ Saved icon: {icon_path}")

def main():
    print("🎨 Generating StyleSprint Logo...")
    print("-" * 50)
    
    # Create logo
    logo = create_logo(1024)
    
    # Save variants
    output_dir = 'app_logos'
    save_logo_variants(logo, output_dir)
    
    print("-" * 50)
    print("✅ Logo generation complete!")
    print(f"\nMain logo saved in: {output_dir}/")
    print(f"Android icons saved in: {output_dir}/android/")
    print(f"iOS icons saved in: {output_dir}/ios/")

if __name__ == '__main__':
    main()
