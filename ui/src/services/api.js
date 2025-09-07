import axios from 'axios';

// API configuration
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

console.log('API Configuration:', {
  url: API_BASE_URL,
  env: process.env.REACT_APP_ENV || 'development'
});

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000, // 30 seconds timeout for image processing
  headers: {
    'Accept': 'application/json',
  },
});

// Gender classification API service
export const genderClassificationAPI = {
  // Health check
  healthCheck: async () => {
    try {
      const response = await api.get('/health');
      return response.data;
    } catch (error) {
      throw new Error(`Health check failed: ${error.message}`);
    }
  },

  // Classify single image
  classifyImage: async (imageFile) => {
    try {
      const formData = new FormData();
      formData.append('file', imageFile);

      const response = await api.post('/predict', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        // Server responded with error status
        throw new Error(error.response.data.detail || `Server error: ${error.response.status}`);
      } else if (error.request) {
        // Request was made but no response
        throw new Error('No response from server. Please check if the API is running.');
      } else {
        // Something else happened
        throw new Error(`Request failed: ${error.message}`);
      }
    }
  },

  // Batch classify images (for future use)
  classifyImages: async (imageFiles) => {
    try {
      const formData = new FormData();
      
      imageFiles.forEach((file) => {
        formData.append('files', file);
      });

      const response = await api.post('/predict-batch', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(error.response.data.detail || `Server error: ${error.response.status}`);
      } else if (error.request) {
        throw new Error('No response from server. Please check if the API is running.');
      } else {
        throw new Error(`Request failed: ${error.message}`);
      }
    }
  },
};

export default genderClassificationAPI;