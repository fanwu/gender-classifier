# Gender Classification API

A FastAPI-based REST API for classifying gender from images using Vision Transformer (ViT) model. The API detects single-person images and predicts male/female classification with confidence scores.

## Features

- 🤖 Vision Transformer-based gender classification
- 👥 Automatic person detection (rejects multi-person images)
- 🔍 Single image and batch prediction endpoints
- 🏥 Health check endpoints
- 🐳 Docker containerized deployment
- ☁️ AWS ECS production deployment ready
- 📊 Confidence scores and probability distributions

## Prerequisites

- Python 3.9+
- AWS account (for model storage and deployment)
- Docker (for containerized deployment)
- AWS CLI configured with appropriate permissions

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo>
cd gender-classifier-api
```

### 2. Set Environment Variables

```bash
export MODEL_BUCKET=your-s3-bucket-name
export MODEL_PREFIX=models/gender-classification-final/
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
```

### 3. Choose Your Testing Method

## Local Development

### Option A: Direct Python (Fastest)

```bash
# Install dependencies
pip install -r requirements.txt

# Run the API
uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# Test
curl http://localhost:8000/health
```

### Option B: Virtual Environment (Recommended)

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
source venv/bin/activate  # Mac/Linux
# OR
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Run the API
uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# When done, deactivate
deactivate
```

### Option C: Docker (Production-like)

```bash
# Build image
docker build -t gender-classifier .

# Run container
docker run -p 8000:8000 \
  -e MODEL_BUCKET=fanwu-ml-test \
  -e MODEL_PREFIX=models/gender-classification-final/ \
  -e AWS_ACCESS_KEY_ID=your_access_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret_key \
  gender-classifier
```

### Option D: Docker Compose (Easiest)

```bash
# Update docker-compose.yml with your AWS credentials and bucket name
# Then run:
docker-compose up --build

# To stop:
docker-compose down
```

## API Endpoints

### Health Check
```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "processor_loaded": true,
  "detector_loaded": true
}
```

### Single Image Prediction
```bash
POST /predict
Content-Type: multipart/form-data
```

**Example:**
```bash
curl -X POST "http://localhost:8000/predict" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@path/to/image.jpg"
```

**Response:**
```json
{
  "prediction": "male",
  "confidence": 0.892,
  "person_count": 1,
  "probabilities": {
    "male": 0.892,
    "female": 0.108
  },
  "error": null
}
```

**Error Response (Multiple People):**
```json
{
  "error": "Multiple people detected (3 people). Please use single-person images.",
  "person_count": 3,
  "prediction": null,
  "confidence": 0.0
}
```

### Batch Prediction
```bash
POST /predict-batch
Content-Type: multipart/form-data
```

**Example:**
```bash
curl -X POST "http://localhost:8000/predict-batch" \
  -F "files=@image1.jpg" \
  -F "files=@image2.jpg"
```

## Testing the API

### Using the Test Script

```bash
python test_api.py
```

### Manual Testing

```bash
# Health check
curl http://localhost:8000/health

# Test single prediction
curl -X POST "http://localhost:8000/predict" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@test-image.jpg"

# Test batch prediction
curl -X POST "http://localhost:8000/predict-batch" \
  -F "files=@image1.jpg" \
  -F "files=@image2.jpg"
```

### Expected Responses

✅ **Successful prediction:**
- Single person detected
- Gender prediction with confidence score
- Probability distribution for both classes

❌ **Error cases:**
- No person detected in image
- Multiple people detected
- Invalid image format
- Processing errors

## Model Requirements

### S3 Model Structure
Your trained model should be stored in S3 with this structure:
```
s3://your-bucket-name/models/gender-classification-final/
├── config.json
├── pytorch_model.bin
├── preprocessor_config.json
└── tokenizer.json (if applicable)
```

### Upload Your Model
```bash
# From your SageMaker notebook or training environment
aws s3 sync ./gender-classification-final/ s3://your-bucket-name/models/gender-classification-final/
```

## Production Deployment

### AWS ECS Deployment

#### Step 1: Update Configuration
```bash
# Edit deploy.sh
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"
export ECR_REPOSITORY="gender-classifier"

# Update task-definition.json with your account ID
```

#### Step 2: Deploy
```bash
# Make script executable
chmod +x deploy.sh

# Deploy to AWS
./deploy.sh
```

#### Step 3: Create ECS Infrastructure
```bash
# Create cluster
aws ecs create-cluster --cluster-name gender-classifier-cluster

# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create service (update with your VPC/subnet IDs)
aws ecs create-service \
  --cluster gender-classifier-cluster \
  --service-name gender-classifier-service \
  --task-definition gender-classifier \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

### CloudFormation Deployment (Complete Infrastructure)

```bash
# Deploy full infrastructure
aws cloudformation create-stack \
  --stack-name gender-classifier-stack \
  --template-body file://cloudformation.yaml \
  --parameters ParameterKey=ImageURI,ParameterValue=YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/gender-classifier:latest \
  --capabilities CAPABILITY_IAM

# Wait for completion
aws cloudformation wait stack-create-complete --stack-name gender-classifier-stack

# Get load balancer URL
aws cloudformation describe-stacks \
  --stack-name gender-classifier-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text
```

## Web App Integration

### JavaScript Example
```javascript
async function classifyGender(imageFile) {
    const formData = new FormData();
    formData.append('file', imageFile);
    
    try {
        const response = await fetch('http://your-api-url/predict', {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.error) {
            console.error('Error:', result.error);
            return;
        }
        
        console.log(`Prediction: ${result.prediction}`);
        console.log(`Confidence: ${(result.confidence * 100).toFixed(1)}%`);
        
    } catch (error) {
        console.error('Network error:', error);
    }
}
```

### React Component
```jsx
import React, { useState } from 'react';

function GenderClassifier() {
    const [result, setResult] = useState(null);
    const [loading, setLoading] = useState(false);
    
    const handleFileUpload = async (event) => {
        const file = event.target.files[0];
        if (!file) return;
        
        setLoading(true);
        const formData = new FormData();
        formData.append('file', file);
        
        try {
            const response = await fetch('/predict', {
                method: 'POST',
                body: formData
            });
            const data = await response.json();
            setResult(data);
        } catch (error) {
            console.error('Error:', error);
        } finally {
            setLoading(false);
        }
    };
    
    return (
        <div>
            <input 
                type="file" 
                accept="image/*" 
                onChange={handleFileUpload}
                disabled={loading}
            />
            {loading && <p>Analyzing...</p>}
            {result && !result.error && (
                <div>
                    <p>Prediction: <strong>{result.prediction}</strong></p>
                    <p>Confidence: {(result.confidence * 100).toFixed(1)}%</p>
                </div>
            )}
            {result?.error && <p style={{color: 'red'}}>{result.error}</p>}
        </div>
    );
}
```

## Troubleshooting

### Common Issues

#### 1. Model Not Found
```bash
# Check if model exists in S3
aws s3 ls s3://your-bucket-name/models/gender-classification-final/

# Verify environment variables
echo $MODEL_BUCKET
echo $MODEL_PREFIX
```

#### 2. AWS Permissions Error
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify S3 permissions
aws s3 ls s3://your-bucket-name/
```

#### 3. Memory Issues
```bash
# For local testing, reduce batch size or use CPU-only mode
# For production, increase ECS task memory in task-definition.json
```

#### 4. Person Detection Issues
```bash
# The API automatically rejects multi-person images
# If detection is too sensitive, adjust thresholds in count_people_in_image()
```

### Logs and Monitoring

#### Local Logs
```bash
# API logs appear in terminal when running uvicorn
# For Docker: docker logs <container-id>
```

#### Production Logs
```bash
# CloudWatch logs
aws logs tail /ecs/gender-classifier --follow

# ECS service logs
aws ecs describe-services --cluster gender-classifier-cluster --services gender-classifier-service
```

## Performance Notes

- **First request**: ~30-60 seconds (model downloads and loads)
- **Subsequent requests**: ~2-5 seconds per image
- **Batch processing**: More efficient for multiple images
- **Memory usage**: ~2GB RAM recommended
- **Storage**: ~1.5GB for models

## Security Considerations

### Production Checklist
- [ ] Configure HTTPS/SSL certificates
- [ ] Restrict CORS origins
- [ ] Add API authentication if needed
- [ ] Use IAM roles instead of access keys
- [ ] Enable VPC security groups
- [ ] Set up monitoring and alerting
- [ ] Configure resource limits

### Environment Variables for Production
```bash
# Use AWS Systems Manager Parameter Store or Secrets Manager
MODEL_BUCKET=your-production-bucket
MODEL_PREFIX=models/gender-classification-final/
# Don't use AWS_ACCESS_KEY_ID in production - use IAM roles
```

## Cost Optimization

- **ECS Fargate**: ~$30-50/month for single task
- **Load Balancer**: ~$20/month
- **S3 storage**: ~$1/month for model files
- **Data transfer**: Variable based on usage

### Cost Reduction Tips
- Use Fargate Spot instances
- Configure auto-scaling based on usage
- Use CloudFront for caching if serving web apps
- Monitor and set up billing alerts

## Contributing

1. Fork the repository
2. Create feature branch
3. Test locally with all options (pip, Docker, etc.)
4. Update documentation if needed
5. Submit pull request

## License

[Your License Here]

## Support

For issues and questions:
- Check troubleshooting section above
- Review CloudWatch logs for errors
- Open GitHub issues for bugs
- Check AWS ECS service health in console