import React, { useState, useEffect } from 'react';
import ImageUpload from './components/ImageUpload';
import ResultsDisplay from './components/ResultsDisplay';
import { genderClassificationAPI } from './services/api';
import './App.css';

function App() {
  const [selectedImage, setSelectedImage] = useState(null);
  const [result, setResult] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const [apiStatus, setApiStatus] = useState('checking');

  // Check API health on component mount
  useEffect(() => {
    checkApiHealth();
  }, []);

  const checkApiHealth = async () => {
    try {
      await genderClassificationAPI.healthCheck();
      setApiStatus('healthy');
    } catch (error) {
      setApiStatus('unhealthy');
      console.error('API health check failed:', error.message);
    }
  };

  const handleImageSelect = async (imageFile) => {
    setSelectedImage(imageFile);
    setResult(null);
    setError(null);

    if (imageFile) {
      await classifyImage(imageFile);
    }
  };

  const classifyImage = async (imageFile) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await genderClassificationAPI.classifyImage(imageFile);
      setResult(response);
    } catch (error) {
      setError(error.message);
      setResult(null);
    } finally {
      setIsLoading(false);
    }
  };

  const retryClassification = async () => {
    if (selectedImage) {
      await classifyImage(selectedImage);
    }
  };

  const resetApp = () => {
    setSelectedImage(null);
    setResult(null);
    setError(null);
    setIsLoading(false);
  };

  const renderApiStatus = () => {
    switch (apiStatus) {
      case 'checking':
        return (
          <div className="api-status checking">
            <span className="status-dot"></span>
            Checking API connection...
          </div>
        );
      case 'healthy':
        return (
          <div className="api-status healthy">
            <span className="status-dot"></span>
            API Connected
          </div>
        );
      case 'unhealthy':
        return (
          <div className="api-status unhealthy">
            <span className="status-dot"></span>
            API Disconnected
            <button onClick={checkApiHealth} className="retry-btn">
              Retry
            </button>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="App">
      <header className="app-header">
        <div className="header-content">
          <h1>🔍 Gender Classification AI</h1>
          <p>Upload a picture to classify gender using advanced AI technology</p>
          {renderApiStatus()}
        </div>
      </header>

      <main className="app-main">
        <div className="container">
          <div className="upload-section">
            <ImageUpload
              onImageSelect={handleImageSelect}
              selectedImage={selectedImage}
              isLoading={isLoading}
            />
          </div>

          <div className="results-section">
            <ResultsDisplay
              result={result}
              isLoading={isLoading}
              error={error}
            />
            
            {(error || (result && result.error)) && !isLoading && (
              <div className="action-buttons">
                <button onClick={retryClassification} className="btn-retry">
                  Try Again
                </button>
                <button onClick={resetApp} className="btn-reset">
                  Upload New Picture
                </button>
              </div>
            )}
          </div>
        </div>
      </main>

      <footer className="app-footer">
        <div className="footer-content">
          <div className="info-section">
            <h3>How it works</h3>
            <div className="info-grid">
              <div className="info-item">
                <div className="info-icon">📤</div>
                <h4>1. Upload</h4>
                <p>Select or drag & drop a picture with a person</p>
              </div>
              <div className="info-item">
                <div className="info-icon">🤖</div>
                <h4>2. AI Analysis</h4>
                <p>Our AI model analyzes facial features and characteristics</p>
              </div>
              <div className="info-item">
                <div className="info-icon">📊</div>
                <h4>3. Results</h4>
                <p>Get gender classification with confidence scores</p>
              </div>
            </div>
          </div>

          <div className="tips-section">
            <h3>Tips for best results</h3>
            <ul>
              <li>✅ Use clear, well-lit pictures</li>
              <li>✅ Include exactly one person per picture</li>
              <li>✅ Face should be visible and unobstructed</li>
              <li>❌ Avoid group pictures or multiple people</li>
              <li>❌ Avoid heavily filtered or edited pictures</li>
              <li>❌ Avoid pictures where the face is covered</li>
            </ul>
          </div>

          <div className="disclaimer">
            <p><strong>Disclaimer:</strong> This tool uses AI for educational and demonstration purposes. Results may not be 100% accurate and should not be used for any critical applications. The AI model makes predictions based on visual features and may have biases or limitations.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;