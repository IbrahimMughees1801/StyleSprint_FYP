"""
Simplified Virtual Try-On - Image Overlay Version
This is a quick working version that doesn't require ML models.
Works immediately while you wait for the full ML pipeline.
"""

from PIL import Image, ImageEnhance, ImageFilter
import numpy as np
from pathlib import Path
import io


def simple_overlay_tryon(person_image_path: str, cloth_image_path: str, output_path: str) -> bool:
    """
    Simple overlay-based virtual try-on
    Overlays clothing on person photo with transparency and positioning
    
    Args:
        person_image_path: Path to person's photo
        cloth_image_path: Path to clothing image
        output_path: Where to save result
    
    Returns:
        bool: Success status
    """
    try:
        # Load images
        person_img = Image.open(person_image_path).convert('RGBA')
        cloth_img = Image.open(cloth_image_path).convert('RGBA')
        
        # Resize person image to standard size
        person_img = person_img.resize((768, 1024), Image.Resampling.LANCZOS)
        
        # Calculate cloth overlay position and size
        # Place clothing in upper-center area (chest/torso region)
        cloth_width = int(person_img.width * 0.6)  # 60% of person width
        cloth_height = int(cloth_width * 1.2)  # Maintain aspect
        
        # Resize cloth
        cloth_resized = cloth_img.resize((cloth_width, cloth_height), Image.Resampling.LANCZOS)
        
        # Position cloth (centered horizontally, upper body area)
        x_offset = (person_img.width - cloth_width) // 2
        y_offset = int(person_img.height * 0.25)  # Start at 25% down
        
        # Create a new image for result
        result = person_img.copy()
        
        # Add slight blur to cloth edges for better blending
        cloth_blurred = cloth_resized.filter(ImageFilter.GaussianBlur(radius=1))
        
        # Reduce opacity for more natural look
        enhancer = ImageEnhance.Brightness(cloth_blurred)
        cloth_adjusted = enhancer.enhance(0.95)
        
        # Composite cloth onto person
        # Use alpha channel for transparency
        result.paste(cloth_adjusted, (x_offset, y_offset), cloth_adjusted)
        
        # Convert back to RGB and save
        result_rgb = result.convert('RGB')
        result_rgb.save(output_path, 'JPEG', quality=95)
        
        print(f"✓ Simple try-on result saved to: {output_path}")
        return True
        
    except Exception as e:
        print(f"Error in simple overlay: {e}")
        return False


def advanced_overlay_tryon(person_image_path: str, cloth_image_path: str, output_path: str) -> bool:
    """
    Slightly more advanced overlay with better positioning
    Uses basic image processing for improved results
    """
    try:
        # Load images
        person_img = Image.open(person_image_path).convert('RGBA')
        cloth_img = Image.open(cloth_image_path).convert('RGBA')
        
        # Resize person to standard size
        person_img = person_img.resize((768, 1024), Image.Resampling.LANCZOS)
        
        # Detect clothing type based on aspect ratio for better positioning
        cloth_aspect = cloth_img.width / cloth_img.height
        
        if cloth_aspect > 1.2:  # Wide clothing (e.g., tops, hoodies)
            cloth_width = int(person_img.width * 0.65)
            cloth_height = int(cloth_width / cloth_aspect)
            y_offset = int(person_img.height * 0.22)
        elif cloth_aspect < 0.8:  # Tall clothing (e.g., dresses, pants)
            cloth_height = int(person_img.height * 0.6)
            cloth_width = int(cloth_height * cloth_aspect)
            y_offset = int(person_img.height * 0.25)
        else:  # Regular clothing
            cloth_width = int(person_img.width * 0.6)
            cloth_height = int(cloth_width * 1.2)
            y_offset = int(person_img.height * 0.24)
        
        # Resize cloth
        cloth_resized = cloth_img.resize((cloth_width, cloth_height), Image.Resampling.LANCZOS)
        
        # Center horizontally
        x_offset = (person_img.width - cloth_width) // 2
        
        # Create result
        result = person_img.copy()
        
        # Apply subtle edge blur for natural blending
        cloth_processed = cloth_resized.filter(ImageFilter.GaussianBlur(radius=0.5))
        
        # Adjust transparency based on cloth brightness
        # Lighter clothes = more opaque, darker clothes = slightly transparent
        alpha = cloth_processed.split()[3]  # Get alpha channel
        alpha_adjusted = ImageEnhance.Brightness(alpha).enhance(0.92)
        cloth_processed.putalpha(alpha_adjusted)
        
        # Composite
        result.paste(cloth_processed, (x_offset, y_offset), cloth_processed)
        
        # Optional: Add slight shadow effect for depth
        shadow = Image.new('RGBA', result.size, (0, 0, 0, 0))
        shadow_offset = 2
        shadow.paste(cloth_processed, (x_offset + shadow_offset, y_offset + shadow_offset))
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=3))
        shadow_alpha = shadow.split()[3]
        shadow_alpha = ImageEnhance.Brightness(shadow_alpha).enhance(0.3)
        shadow.putalpha(shadow_alpha)
        
        # Combine shadow + result
        final = person_img.copy()
        final.paste(shadow, (0, 0), shadow)
        final.paste(cloth_processed, (x_offset, y_offset), cloth_processed)
        
        # Convert and save
        final_rgb = final.convert('RGB')
        final_rgb.save(output_path, 'JPEG', quality=95)
        
        print(f"✓ Advanced overlay result saved to: {output_path}")
        return True
        
    except Exception as e:
        print(f"Error in advanced overlay: {e}")
        return False


if __name__ == "__main__":
    # Test the function
    print("Simple Virtual Try-On - Overlay Version")
    print("This is a working placeholder until ML models are available")
