# app.py - Main FastAPI application
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from transformers import ViTImageProcessor, ViTForImageClassification, pipeline
from PIL import Image
import torch
import io
import logging
import os
import boto3
from typing import Dict, Any
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Gender Classification API",
    description="API for classifying gender from images using Vision Transformer",
    version="1.0.0"
)

# Enable CORS for web app integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for model
processor = None
model = None
person_detector = None

def download_model_from_s3():
    """Download model from S3 if not exists locally"""
    model_dir = "./model"
    
    if not os.path.exists(model_dir):
        logger.info("Downloading model from S3...")
        s3 = boto3.client('s3')
        
        # Download model files from S3
        bucket_name = os.getenv('MODEL_BUCKET', 'your-bucket-name')
        model_prefix = os.getenv('MODEL_PREFIX', 'models/gender-classification-final/')
        
        os.makedirs(model_dir, exist_ok=True)
        
        # List all model files
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=model_prefix)
        
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    key = obj['Key']
                    if not key.endswith('/'):
                        local_path = os.path.join(model_dir, os.path.basename(key))
                        s3.download_file(bucket_name, key, local_path)
                        logger.info(f"Downloaded {key} to {local_path}")
        
        logger.info("Model download completed!")
    
    return model_dir

def load_models():
    """Load the gender classification model and person detector"""
    global processor, model, person_detector
    
    try:
        # Download model from S3 if needed
        model_dir = download_model_from_s3()
        
        # Load gender classification model
        logger.info("Loading gender classification model...")
        processor = ViTImageProcessor.from_pretrained(model_dir)
        model = ViTForImageClassification.from_pretrained(model_dir)
        model.eval()  # Set to evaluation mode
        
        # Load person detection model
        logger.info("Loading person detection model...")
        person_detector = pipeline("object-detection", model="facebook/detr-resnet-50")
        
        logger.info("All models loaded successfully!")
        
    except Exception as e:
        logger.error(f"Error loading models: {e}")
        raise e

def count_people_in_image(image: Image.Image) -> int:
    """Count number of people in image"""
    try:
        detections = person_detector(image)
        
        # Filter for people with good confidence and reasonable size
        img_width, img_height = image.size
        valid_people = 0
        
        for detection in detections:
            if 'person' in detection['label'].lower():
                score = detection['score']
                box = detection['box']
                
                # Calculate relative size
                det_width = box['xmax'] - box['xmin']
                det_height = box['ymax'] - box['ymin']
                relative_area = (det_width * det_height) / (img_width * img_height)
                relative_height = det_height / img_height
                
                # Filter criteria for close-up person photos
                if (score > 0.7 and 
                    relative_area > 0.05 and 
                    relative_height > 0.2):
                    valid_people += 1
        
        return valid_people
        
    except Exception as e:
        logger.error(f"Error in person detection: {e}")
        return 1  # Default to 1 person if detection fails

@app.on_event("startup")
async def startup_event():
    """Load models when the app starts"""
    load_models()

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Gender Classification API",
        "status": "healthy",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "processor_loaded": processor is not None,
        "detector_loaded": person_detector is not None
    }

@app.post("/predict")
async def predict_gender(file: UploadFile = File(...)):
    """
    Predict gender from uploaded image
    
    Returns:
    - prediction: 'male' or 'female'
    - confidence: confidence score (0-1)
    - person_count: number of people detected
    - error: error message if any issues
    """
    
    if not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        # Read and process image
        image_data = await file.read()
        image = Image.open(io.BytesIO(image_data)).convert('RGB')
        
        # Check for single person
        person_count = count_people_in_image(image)
        
        if person_count == 0:
            return {
                "error": "No person detected in image",
                "person_count": person_count,
                "prediction": None,
                "confidence": 0.0
            }
        elif person_count > 1:
            return {
                "error": f"Multiple people detected ({person_count} people). Please use single-person images.",
                "person_count": person_count,
                "prediction": None,
                "confidence": 0.0
            }
        
        # Make gender prediction
        inputs = processor(images=image, return_tensors="pt")
        
        with torch.no_grad():
            outputs = model(**inputs)
            predictions = torch.nn.functional.softmax(outputs.logits, dim=-1)
            predicted_class_id = predictions.argmax().item()
            confidence = predictions.max().item()
        
        predicted_label = model.config.id2label[predicted_class_id]
        
        return {
            "prediction": predicted_label,
            "confidence": float(confidence),
            "person_count": person_count,
            "probabilities": {
                "male": float(predictions[0][0]),
                "female": float(predictions[0][1])
            },
            "error": None
        }
        
    except Exception as e:
        logger.error(f"Error in prediction: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.post("/predict-batch")
async def predict_batch(files: list[UploadFile] = File(...)):
    """
    Predict gender for multiple images
    """
    if len(files) > 10:  # Limit batch size
        raise HTTPException(status_code=400, detail="Maximum 10 images per batch")
    
    results = []
    
    for i, file in enumerate(files):
        try:
            if not file.content_type.startswith('image/'):
                results.append({
                    "filename": file.filename,
                    "error": "File must be an image",
                    "prediction": None,
                    "confidence": 0.0
                })
                continue
            
            # Process single image
            image_data = await file.read()
            image = Image.open(io.BytesIO(image_data)).convert('RGB')
            
            person_count = count_people_in_image(image)
            
            if person_count != 1:
                results.append({
                    "filename": file.filename,
                    "error": f"Expected 1 person, found {person_count}",
                    "person_count": person_count,
                    "prediction": None,
                    "confidence": 0.0
                })
                continue
            
            # Make prediction
            inputs = processor(images=image, return_tensors="pt")
            
            with torch.no_grad():
                outputs = model(**inputs)
                predictions = torch.nn.functional.softmax(outputs.logits, dim=-1)
                predicted_class_id = predictions.argmax().item()
                confidence = predictions.max().item()
            
            predicted_label = model.config.id2label[predicted_class_id]
            
            results.append({
                "filename": file.filename,
                "prediction": predicted_label,
                "confidence": float(confidence),
                "person_count": person_count,
                "error": None
            })
            
        except Exception as e:
            results.append({
                "filename": file.filename,
                "error": str(e),
                "prediction": None,
                "confidence": 0.0
            })
    
    return {"results": results}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=API_HOST, port=API_PORT, reload=DEBUG)