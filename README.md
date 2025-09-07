# Gender Classification

This project is a complete end-to-end gender classification system consisting of four main components:

1. **Model Training** - Uses SageMaker with Jupyter notebook for training Vision Transformer models on gender classification data
2. **FastAPI Backend** - A REST API deployed on AWS ECS that connects to the trained model to predict male/female gender from images
3. **React Web UI** - A user-friendly web interface for uploading pictures and viewing gender classification results
4. **Infrastructure as Code** - Terraform deployment scripts for complete AWS infrastructure setup including ECS, ALB, S3, and CloudFront

Demo:
- Web UI: http://fanwu-ai-test.s3-website-us-east-1.amazonaws.com/ (TODO: I set up Cloudfront but didn't use it here, as I would have to setup a certificate to make https work between the React app and API)
- API: http://gender-classifier-alb-553295840.us-east-1.elb.amazonaws.com/docs

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

## 1. Model Training

### Training Your Own Gender Classification Model

The project includes a Jupyter notebook (`gender-classifier.ipynb`) for training custom gender classification models using Vision Transformer architecture on SageMaker. The training process uses S3 for data storage and model artifacts.

#### Training Overview

The training pipeline includes:
- **Data Loading**: Images loaded directly from S3 with automatic labeling based on folder structure or filename
- **Data Augmentation**: Random horizontal flip, rotation, color jitter, and resized crop for improved generalization.
- **Person Detection**: DETR model integration to filter multi-person images during training
- **Model Architecture**: Vision Transformer (ViT-base-patch16-224) fine-tuned for gender classification
- **Validation**: 80/20 train-validation split with accuracy metrics
- **Model Persistence**: Automatic upload of trained models to S3

#### During the training process

Initially the model was not accurate. I tried several approach to make it better.
- There were not enough pictures in the training data set. I tried Data Augmentation but it didn't help much. So Data Augmentation was not used.
- I downloaded pictures from CelebA Dataset and labeled them. They worked out very well.
- I tweaked model configurations to improve its quality
- I used Meta DETR model to detect and count people's faces, to filter out multi people pictures and pictures without people

#### Training Setup

1. **Prepare Training Data in S3**:
   ```
   s3://your-bucket/gender-data/
   ├── male/
   │   ├── image1.jpg
   │   └── image2.jpg
   └── female/
       ├── image1.jpg
       └── image2.jpg
   ```

   Or use filename-based labeling:
   ```
   s3://your-bucket/gender-data/
   ├── male_person1.jpg
   ├── male_person2.jpg
   ├── female_person1.jpg
   └── female_person2.jpg
   ```

2. **Open Training Notebook in SageMaker**:
   ```bash
   jupyter notebook gender-classifier.ipynb
   ```

3. **Configure Training Parameters**:
   ```python
   BUCKET_NAME = "your-s3-bucket"
   S3_PREFIX = "gender-data/"
   MODEL_NAME = "google/vit-base-patch16-224"
   ```

4. **Execute Training**:
   - The notebook automatically handles data loading, preprocessing, and training
   - Training includes person detection filtering to ensure single-person images
   - Models are automatically saved to S3 upon completion

#### Training Features

- **GPU Support**: Automatic CUDA detection and usage when available
- **Data Augmentation**: Comprehensive image augmentation for better generalization
- **Person Detection**: Automatic filtering of multi-person images using DETR model
- **S3 Integration**: Direct data loading from S3 with automatic model upload
- **Validation Pipeline**: Built-in prediction testing on sample images
- **Error Handling**: Robust error handling for corrupted or invalid images

#### Training Results

The training notebook processes:
- **Dataset Size**: 198 images (81 male, 117 female) in the example
- **Train/Validation Split**: 80/20 stratified split
- **Training Epochs**: 5 epochs with 2e-5 learning rate
- **Batch Size**: 2 (adjustable based on GPU memory)
- **Final Model**: Saved to `s3://bucket/models/gender-classification/`

#### Post-Training Validation

The notebook includes comprehensive testing:
```python
# Test on validation images
results = predict_all_images_in_folder('test/', BUCKET_NAME, model, processor, detector)

# Example results with person detection filtering
- Single person images: Accurate gender prediction with confidence scores
- Multi-person images: Automatic rejection with error message
- Non-person images: Automatic filtering out during prediction
```

### Model Requirements

#### S3 Model Structure
Your trained model should be stored in S3 with this structure:
```
s3://your-bucket-name/models/gender-classification-final/
├── config.json
├── model.safetensors
├── preprocessor_config.json
└── tokenizer.json (if applicable)
```

#### Upload Your Model
```bash
# From your training environment (automatically done by notebook)
aws s3 sync ./gender-classification-final/ s3://your-bucket-name/models/gender-classification-final/

# Or manually upload individual files
aws s3 cp config.json s3://your-bucket-name/models/gender-classification-final/
aws s3 cp model.safetensors s3://your-bucket-name/models/gender-classification-final/
aws s3 cp preprocessor_config.json s3://your-bucket-name/models/gender-classification-final/
```

## 2. FastAPI Backend

### Environment Configuration

#### 1. Environment Variables Setup

The API application requires environment variables for configuration. **Never commit your `.env` file to git** as it contains sensitive information.

```bash
# Copy the example file to create your environment config
cp .env.example .env

# Edit .env with your actual values
nano .env  # or use your preferred editor
```

#### 2. Required Environment Variables

Edit your `.env` file with the following required variables:

```bash
# S3 Model Configuration
MODEL_BUCKET=your-s3-bucket-name
MODEL_PREFIX=models/gender-classification-final/

# AWS Credentials (local development only)
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_access_key_here
AWS_DEFAULT_REGION=us-east-1

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=true

# CORS Configuration (restrict for production)
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
```

**⚠️ Security Notes**: 
- The `.env` file is already in `.gitignore` and should never be committed to version control
- Never commit AWS credentials to git repositories
- Use IAM roles instead of access keys in production environments
- Review and restrict CORS origins for production deployments

### API Development and Testing

#### 1. Clone and Setup

```bash
git clone <your-repo>
cd gender-classifier
```

#### 2. Environment Setup

Follow the [Environment Configuration](#2-fastapi-backend) section above to set up your `.env` file.

#### 3. Choose Your Development Method

### Option A: Direct Python (Fastest)

```bash
# Navigate to api directory
cd api

# Ensure .env file is configured (see Environment Configuration above)
cp .env.example .env  # Edit with your values

# Install dependencies
pip install -r requirements.txt

# Run the API
python app.py
# OR
uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# Test
curl http://localhost:8000/health
```

### Option B: Virtual Environment (Recommended)

```bash
# Navigate to api directory
cd api

# Ensure .env file is configured (see Environment Configuration above)
cp .env.example .env  # Edit with your values

# Create virtual environment (if not exists)
python -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # Mac/Linux
# OR
.venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Run the API
python app.py
# OR
uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# When done, deactivate
deactivate
```

### Option C: Docker (Production-like)

```bash
# Navigate to api directory
cd api

# Build image
docker build -t gender-classifier .

# IMPORTANT: Docker containers cannot access ~/.aws by default!
# Choose the appropriate option based on your AWS credential setup:

# Option C1: Use .env file (only if .env contains AWS credentials)
docker run -p 8000:8000 --env-file .env gender-classifier

# Option C2: Mount AWS credentials (recommended if using ~/.aws folder)
docker run -p 8000:8000 \
  -v ~/.aws:/root/.aws:ro \
  --env-file .env \
  gender-classifier

# Option C3: Pass individual environment variables
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


## 4. Infrastructure as Code

### Production Deployment with Terraform

#### Prerequisites
```bash
# Install Terraform
# macOS: brew install terraform
# Or download from: https://www.terraform.io/downloads

# Verify installation
terraform --version
```

#### Quick Deployment (Recommended)
```bash
# Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values (AWS account ID, bucket name, etc.)

# Return to project root and deploy everything
cd ..
./deploy.sh deploy
```

#### Step-by-Step Deployment
```bash
# Build and push Docker image only
./deploy.sh build

# Review infrastructure changes before applying
./deploy.sh plan

# Apply the planned changes
./deploy.sh apply

# View deployment information
./deploy.sh outputs
```

#### Available Commands
```bash
./deploy.sh deploy        # Full deployment (build + infrastructure)
./deploy.sh build         # Build and push Docker image only
./deploy.sh plan          # Create Terraform execution plan
./deploy.sh apply         # Apply existing Terraform plan
./deploy.sh infrastructure # Deploy infrastructure only (assumes image exists)
./deploy.sh outputs       # Show deployment outputs
./deploy.sh destroy       # Destroy all infrastructure
./deploy.sh help          # Show help message
```

## 3. React Web UI

### Quick Start

A React web application provides a user-friendly interface for the Gender Classification API.

```bash
# Navigate to UI directory
cd ui

# Install dependencies
npm install

# Start development server (make sure API is running on port 8000)
npm start

# Open http://localhost:3000 in your browser
```

### Features

- 🖼️ **Drag & Drop Upload** - Easy image upload with drag and drop support
- 🔍 **Real-time Analysis** - Instant gender classification with AI
- 📊 **Detailed Results** - Gender prediction with confidence scores and probability breakdown
- ⚠️ **Smart Error Handling** - Clear feedback for edge cases (multiple people, no people, etc.)
- 📱 **Responsive Design** - Works on desktop, tablet, and mobile devices
- 🎨 **Modern UI** - Clean, professional interface with smooth animations
- 🔄 **API Health Check** - Visual indicator of API connection status

### Usage

1. **Start the API server:**
   ```bash
   cd api
   source .venv/bin/activate  
   python app.py
   ```

2. **Start the UI (in another terminal):**
   ```bash
   cd ui
   npm start
   ```

3. **Upload and analyze images:**
   - Click upload area or drag & drop images
   - View real-time gender classification results
   - See confidence scores and probability breakdowns

### Configuration

Create `.env` file in `ui/` directory to customize API URL:
```bash
REACT_APP_API_URL=http://localhost:8000
```

### Production Build

```bash
cd ui
npm run build
# Serve the build/ directory with your web server
```

### Production Deployment to AWS S3

#### Simple One-Time Setup

1. **Configure deployment settings** (one-time setup):
   ```bash
   # Edit deploy-config.env in project root
   S3_BUCKET_UI=your-bucket-name
   S3_UI_PREFIX=ui/                    # Optional: deploy to folder
   CLOUDFRONT_ID=E123ABCDEFGHIJ        # Optional: CloudFront distribution
   ```

2. **Deploy anytime:**
   ```bash
   ./deploy.sh deploy-ui
   ```
   
   That's it! The configuration is automatically loaded.

#### Manual Override (if needed)

```bash
# Override config file settings
S3_BUCKET_UI=different-bucket ./deploy.sh deploy-ui
```

#### Complete Deployment Workflow

```bash
# 1. Deploy API infrastructure
./deploy.sh deploy

# 2. Get API load balancer URL
./deploy.sh outputs

# 3. Update ui/.env.production with the ALB URL
# REACT_APP_API_URL=https://your-alb-url.amazonaws.com

# 4. Configure UI deployment (one-time setup)
# Edit deploy-config.env:
# S3_BUCKET_UI=my-ui-bucket
# S3_UI_PREFIX=ui/

# 5. Deploy UI (repeatable)
./deploy.sh deploy-ui
```

#### Available UI Commands

```bash
./deploy.sh build-ui     # Build React app for production
./deploy.sh deploy-ui    # Build and deploy to S3 (uses deploy-config.env)
./deploy.sh serve-ui     # Serve production build locally for testing
```

## API Integration Examples

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
# Use IAM roles instead of access keys in production
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