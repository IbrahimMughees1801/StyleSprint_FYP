import cv2
import numpy as np

print("=" * 60)
print("OPENCV VERIFICATION")
print("=" * 60)

print(f"\n✓ OpenCV version: {cv2.__version__}")

# Create a test image
test_img = np.zeros((100, 100, 3), dtype=np.uint8)
test_img[:,:] = (255, 0, 0)  # Blue image

# Test basic operations
gray = cv2.cvtColor(test_img, cv2.COLOR_BGR2GRAY)
blurred = cv2.GaussianBlur(test_img, (5, 5), 0)
edges = cv2.Canny(gray, 50, 150)

print("✓ Can create images")
print("✓ Can convert color spaces")
print("✓ Can apply filters (blur, edge detection)")

# Test reading capabilities
print(f"\n✓ Image backends available: {cv2.getBuildInformation()}")

print("\n🎉 OpenCV is working correctly!")
print("\nYou can now:")
print("  - Read images: cv2.imread('image.jpg')")
print("  - Process videos: cv2.VideoCapture('video.mp4')")
print("  - Use camera: cv2.VideoCapture(0)")

print("=" * 60)
