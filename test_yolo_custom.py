"""
Test script for your custom trained YOLO model
Run this after placing your best.pt file in the weights/ folder
"""

from ultralytics import YOLO
import torch
import os
from pathlib import Path

def test_yolo_model():
    """Test the custom YOLO model"""
    
    print("=" * 60)
    print("Testing Custom YOLO Model")
    print("=" * 60)
    
    # Check device
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"\n✓ Using device: {device.upper()}")
    if device == 'cuda':
        print(f"  GPU: {torch.cuda.get_device_name(0)}")
    
    # Check if model file exists
    model_path = Path("weights/best.pt")
    if not model_path.exists():
        print(f"\n❌ Model file not found at: {model_path.absolute()}")
        print("\n📥 Please download your best.pt from Colab:")
        print("   1. In Colab: files.download('runs/detect/train/weights/best.pt')")
        print("   2. Place it in: weights/best.pt")
        return
    
    print(f"\n✓ Model file found: {model_path.absolute()}")
    
    # Load the model
    print("\n🔄 Loading model...")
    try:
        model = YOLO(str(model_path))
        print("✓ Model loaded successfully!")
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return
    
    # Print model information
    print("\n" + "=" * 60)
    print("Model Information")
    print("=" * 60)
    
    print(f"\n📊 Classes detected by your model:")
    for idx, name in model.names.items():
        print(f"  {idx}: {name}")
    
    print(f"\n📈 Total classes: {len(model.names)}")
    
    try:
        total_params = sum(p.numel() for p in model.model.parameters())
        print(f"📦 Total parameters: {total_params:,}")
    except:
        print("📦 Parameters: Unable to calculate")
    
    # Test prediction on a sample image if available
    print("\n" + "=" * 60)
    print("Testing Prediction")
    print("=" * 60)
    
    # Look for test images
    test_image_paths = [
        "test_image.jpg",
        "test.jpg",
        "sample.jpg",
        "test_image.png",
        "test.png"
    ]
    
    test_image = None
    for path in test_image_paths:
        if os.path.exists(path):
            test_image = path
            break
    
    if test_image:
        print(f"\n✓ Found test image: {test_image}")
        print("🔄 Running prediction...")
        
        try:
            # Run prediction
            results = model.predict(
                test_image, 
                conf=0.25,  # Lower confidence threshold for testing
                device=device,
                verbose=False
            )
            
            print(f"✓ Prediction complete!")
            
            # Print results
            for r in results:
                boxes = r.boxes
                if len(boxes) > 0:
                    print(f"\n🎯 Found {len(boxes)} detection(s):")
                    for box in boxes:
                        cls = int(box.cls[0])
                        conf = float(box.conf[0])
                        print(f"  - {model.names[cls]}: {conf:.2%} confidence")
                else:
                    print("\n⚠ No detections found. Try:")
                    print("  - Lower confidence threshold (currently 0.25)")
                    print("  - Different test image")
                    print("  - Check if image matches training data")
            
            # Save annotated image
            output_path = "test_yolo_output.jpg"
            r.save(filename=output_path)
            print(f"\n💾 Saved annotated image to: {output_path}")
            
        except Exception as e:
            print(f"❌ Error during prediction: {e}")
    else:
        print("\n⚠ No test image found")
        print("  To test prediction, place an image:")
        print("  - test_image.jpg")
        print("  - test.jpg") 
        print("  - sample.jpg")
        print("\n  Then run this script again.")
    
    # Usage example
    print("\n" + "=" * 60)
    print("Usage in Your Code")
    print("=" * 60)
    print("""
from ultralytics import YOLO

# Load model
model = YOLO('weights/best.pt')

# Predict on image
results = model.predict('image.jpg', conf=0.5)

# Process results
for r in results:
    boxes = r.boxes
    for box in boxes:
        cls = int(box.cls[0])
        conf = float(box.conf[0])
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        
        print(f"Class: {model.names[cls]}")
        print(f"Confidence: {conf:.2%}")
        print(f"Bbox: ({x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f})")
    """)
    
    print("\n" + "=" * 60)
    print("Next Steps")
    print("=" * 60)
    print("""
1. ✅ Model is loaded and ready
2. 📝 Update backend config in backend/api_server.py
3. 🚀 Start backend: cd backend && python api_server_simple.py
4. 📱 Connect from Flutter app
    """)
    
    print("=" * 60)
    print("🎉 YOLO Model Test Complete!")
    print("=" * 60)


if __name__ == "__main__":
    test_yolo_model()
