from ultralytics import YOLO
import torch

print("Testing YOLO setup...")
print(f"Using device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}")

# Load a pre-trained YOLOv8 model
print("\nLoading YOLOv8 nano model...")
model = YOLO('yolov8n.pt')  # nano version (smallest, fastest)

print("✓ YOLO model loaded successfully!")
print(f"✓ Model is on: {next(model.model.parameters()).device}")

# The model will automatically download on first run (about 6MB)
print("\n🎉 YOLO is ready to use!")
print("\nNext steps:")
print("  - Try: model.predict('image.jpg') to detect objects")
print("  - Or: model.train(data='your_dataset.yaml') to train on custom data")
