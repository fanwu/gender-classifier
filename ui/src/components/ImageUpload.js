import React, { useState, useRef } from 'react';

const ImageUpload = ({ onImageSelect, selectedImage, isLoading }) => {
  const [dragActive, setDragActive] = useState(false);
  const inputRef = useRef(null);

  // Handle drag events
  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  // Handle drop events
  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  // Handle file selection
  const handleChange = (e) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0]);
    }
  };

  // Validate and process file
  const handleFile = (file) => {
    // Check if file is an image
    if (!file.type.startsWith('image/')) {
      alert('Please select a picture file (JPEG, PNG, etc.)');
      return;
    }

    // Check file size (limit to 10MB)
    if (file.size > 10 * 1024 * 1024) {
      alert('File size must be less than 10MB');
      return;
    }

    onImageSelect(file);
  };

  // Open file dialog
  const onButtonClick = () => {
    inputRef.current?.click();
  };

  // Remove selected image
  const removeImage = () => {
    onImageSelect(null);
    if (inputRef.current) {
      inputRef.current.value = '';
    }
  };

  return (
    <div className="image-upload">
      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        onChange={handleChange}
        style={{ display: 'none' }}
        disabled={isLoading}
      />
      
      {!selectedImage ? (
        <div
          className={`upload-zone ${dragActive ? 'drag-active' : ''}`}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
          onClick={onButtonClick}
        >
          <div className="upload-content">
            <div className="upload-icon">📸</div>
            <h3>Upload a Picture</h3>
            <p>Click here or drag and drop a picture to classify gender</p>
            <p className="upload-requirements">
              <strong>⚠️ Important:</strong> Use pictures with exactly <strong>ONE person</strong><br/>
              Multiple people will not work
            </p>
            <p className="upload-note">
              Supports: JPEG, PNG, GIF, WebP<br/>
              Max size: 10MB
            </p>
          </div>
        </div>
      ) : (
        <div 
          className={`image-preview ${dragActive ? 'drag-active' : ''}`}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
        >
          <div className="preview-overlay">
            {dragActive && (
              <div className="drag-overlay">
                <div className="drag-overlay-content">
                  <div className="drag-icon">🔄</div>
                  <h3>Drop to Replace</h3>
                  <p>Release to replace current picture</p>
                </div>
              </div>
            )}
            <img 
              src={URL.createObjectURL(selectedImage)} 
              alt="Selected" 
              className="preview-image"
            />
          </div>
          <div className="image-info">
            <p><strong>File:</strong> {selectedImage.name}</p>
            <p><strong>Size:</strong> {(selectedImage.size / 1024 / 1024).toFixed(2)} MB</p>
            <p className="drag-hint">💡 You can drag & drop a new picture to replace this one</p>
          </div>
          {!isLoading && (
            <div className="image-actions">
              <button onClick={removeImage} className="btn-remove">
                Remove Picture
              </button>
              <button onClick={onButtonClick} className="btn-change">
                Change Picture
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ImageUpload;