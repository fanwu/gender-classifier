import React from 'react';

const ResultsDisplay = ({ result, isLoading, error }) => {
  if (isLoading) {
    return (
      <div className="results-display loading">
        <div className="loading-spinner"></div>
        <h3>Analyzing Picture...</h3>
        <p>Please wait while we classify the gender in your picture.</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="results-display error">
        <div className="error-icon">❌</div>
        <h3>Analysis Failed</h3>
        <p className="error-message">{error}</p>
        <div className="error-suggestions">
          <h4>Suggestions:</h4>
          <ul>
            <li>Make sure the API server is running</li>
            <li>Check that the image is a valid format</li>
            <li>Try with a different image</li>
            <li>Refresh the page and try again</li>
          </ul>
        </div>
      </div>
    );
  }

  if (!result) {
    return (
      <div className="results-display empty">
        <div className="empty-icon">🔍</div>
        <h3>Ready for Analysis</h3>
        <p>Upload a picture to see gender classification results</p>
      </div>
    );
  }

  // Handle different result scenarios
  const renderResult = () => {
    if (result.error) {
      // API returned an error (e.g., multiple people, no people)
      return (
        <div className="result-error">
          <div className="error-icon">⚠️</div>
          <h3>Unable to Classify</h3>
          <p className="error-message">{result.error}</p>
          
          {result.person_count !== undefined && (
            <div className="person-count">
              <p><strong>People detected:</strong> {result.person_count}</p>
            </div>
          )}

          <div className="error-help">
            <h4>For best results:</h4>
            <ul>
              <li>Use pictures with exactly one person</li>
              <li>Ensure the person is clearly visible</li>
              <li>Use good lighting and picture quality</li>
              <li>Avoid group pictures or crowded scenes</li>
            </ul>
          </div>
        </div>
      );
    }

    // Successful classification
    const { prediction, confidence, person_count, probabilities } = result;
    const confidencePercent = (confidence * 100).toFixed(1);
    
    const getConfidenceColor = (conf) => {
      if (conf >= 0.8) return '#4CAF50'; // Green
      if (conf >= 0.6) return '#FF9800'; // Orange
      return '#F44336'; // Red
    };

    const getGenderIcon = (gender) => {
      return gender === 'male' ? '👨' : '👩';
    };

    return (
      <div className="result-success">
        <div className="result-main">
          <div className="gender-icon">{getGenderIcon(prediction)}</div>
          <h3>Classification Result</h3>
          <div className="prediction">
            <span className="gender">{prediction.toUpperCase()}</span>
          </div>
          <div 
            className="confidence"
            style={{ color: getConfidenceColor(confidence) }}
          >
            {confidencePercent}% confident
          </div>
        </div>

        <div className="result-details">
          <div className="detail-item">
            <span className="label">People detected:</span>
            <span className="value">{person_count}</span>
          </div>
          
          {probabilities && (
            <div className="probabilities">
              <h4>Detailed Probabilities:</h4>
              <div className="probability-bars">
                <div className="probability-item">
                  <div className="probability-label">
                    <span>👨 Male</span>
                    <span>{(probabilities.male * 100).toFixed(1)}%</span>
                  </div>
                  <div className="probability-bar">
                    <div 
                      className="probability-fill male"
                      style={{ width: `${probabilities.male * 100}%` }}
                    ></div>
                  </div>
                </div>
                
                <div className="probability-item">
                  <div className="probability-label">
                    <span>👩 Female</span>
                    <span>{(probabilities.female * 100).toFixed(1)}%</span>
                  </div>
                  <div className="probability-bar">
                    <div 
                      className="probability-fill female"
                      style={{ width: `${probabilities.female * 100}%` }}
                    ></div>
                  </div>
                </div>
              </div>
            </div>
          )}

          <div className="confidence-indicator">
            <h4>Confidence Level:</h4>
            <div className="confidence-bar">
              <div 
                className="confidence-fill"
                style={{ 
                  width: `${confidence * 100}%`,
                  backgroundColor: getConfidenceColor(confidence)
                }}
              ></div>
            </div>
            <div className="confidence-labels">
              <span>Low</span>
              <span>Medium</span>
              <span>High</span>
            </div>
          </div>
        </div>

        {confidence < 0.6 && (
          <div className="low-confidence-warning">
            <p>⚠️ <strong>Low confidence result.</strong> The model is not very certain about this prediction. Consider using a different picture with better lighting or a clearer view of the person.</p>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="results-display">
      {renderResult()}
    </div>
  );
};

export default ResultsDisplay;