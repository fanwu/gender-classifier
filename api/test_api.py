import requests
import json

# Test the API
API_URL = "http://localhost:8000"  # Change to your deployed URL

def test_health():
    response = requests.get(f"{API_URL}/health")
    print("Health check:", response.json())

def test_prediction(image_path):
    with open(image_path, 'rb') as f:
        files = {'file': f}
        response = requests.post(f"{API_URL}/predict", files=files)
        print("Prediction:", response.json())

def test_batch_prediction(image_paths):
    files = [('files', open(path, 'rb')) for path in image_paths]
    response = requests.post(f"{API_URL}/predict-batch", files=files)
    
    # Close files
    for _, f in files:
        f.close()
    
    print("Batch prediction:", response.json())

if __name__ == "__main__":
    # Run tests
    test_health()
    
    # Test with your images
    # test_prediction("path/to/test/image.jpg")
    # test_batch_prediction(["image1.jpg", "image2.jpg"])