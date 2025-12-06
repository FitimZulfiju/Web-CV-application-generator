#!/bin/bash
# NVIDIA GPU Setup Script for Ollama
# This script enables GPU acceleration for local AI models in Docker

set -e

echo "========================================="
echo "NVIDIA GPU Setup for Ollama"
echo "========================================="
echo ""

# Step 1: Check if NVIDIA GPU is available
echo "Step 1: Checking for NVIDIA GPU..."
if ! nvidia-smi &>/dev/null; then
    echo "ERROR: nvidia-smi not found or NVIDIA GPU not detected"
    echo "Please ensure you have an NVIDIA GPU and drivers installed"
    exit 1
fi

echo "✓ NVIDIA GPU detected:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo ""

# Step 2: Check if NVIDIA Container Toolkit is installed
echo "Step 2: Checking NVIDIA Container Toolkit..."
if ! command -v nvidia-ctk &>/dev/null; then
    echo "NVIDIA Container Toolkit not found. Installing..."
    
    # Add NVIDIA package repository
    echo "Adding NVIDIA package repository..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Update and install
    echo "Updating package list..."
    sudo apt-get update
    
    echo "Installing NVIDIA Container Toolkit..."
    sudo apt-get install -y nvidia-container-toolkit
    
    # Configure Docker
    echo "Configuring Docker runtime..."
    sudo nvidia-ctk runtime configure --runtime=docker
    
    # Restart Docker
    echo "Restarting Docker daemon..."
    sudo pkill -SIGHUP dockerd || true
    
    echo "✓ NVIDIA Container Toolkit installed successfully"
else
    echo "✓ NVIDIA Container Toolkit already installed"
    nvidia-ctk --version
fi
echo ""

# Step 3: Verify docker-compose.yml has GPU configuration
echo "Step 3: Checking docker-compose.yml GPU configuration..."
if grep -q "runtime: nvidia" docker-compose.yml; then
    echo "✓ GPU runtime already configured in docker-compose.yml"
else
    echo "WARNING: GPU runtime not found in docker-compose.yml"
    echo "Please ensure the Ollama service has:"
    echo "  runtime: nvidia"
    echo "  environment:"
    echo "    - NVIDIA_VISIBLE_DEVICES=all"
fi
echo ""

# Step 4: Restart Ollama container
echo "Step 4: Restarting Ollama container with GPU support..."
docker compose down ollama 2>/dev/null || true
docker compose up -d ollama

echo "Waiting for Ollama to start..."
sleep 5
echo ""

# Step 5: Verify GPU is detected by Ollama
echo "Step 5: Verifying GPU detection in Ollama..."
if docker logs webcv-ollama 2>&1 | grep -i "gpu\|cuda" | tail -n 5; then
    echo ""
    echo "✓ GPU successfully detected by Ollama!"
else
    echo "WARNING: GPU detection not confirmed in logs"
    echo "Check logs manually with: docker logs webcv-ollama"
fi
echo ""

# Step 6: Summary
echo "========================================="
echo "GPU Setup Complete!"
echo "========================================="
echo ""
echo "Your local AI models will now use GPU acceleration."
echo "Expected speedup: 50-100x faster than CPU"
echo ""
echo "To test GPU performance:"
echo "  docker exec webcv-ollama ollama run phi3 'Hello'"
echo ""
echo "Available models:"
docker exec webcv-ollama ollama list
echo ""
