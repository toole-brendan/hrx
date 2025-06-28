// Script to generate favicon from Lissajous curve
const { createCanvas } = require('canvas');
const fs = require('fs');
const path = require('path');

function generateLissajousFavicon(size = 32) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  
  // Clear canvas with transparent background
  ctx.clearRect(0, 0, size, size);
  
  // Add a subtle background circle for better visibility
  ctx.fillStyle = '#f3f4f6'; // gray-100
  ctx.beginPath();
  ctx.arc(size/2, size/2, size/2 - 1, 0, Math.PI * 2);
  ctx.fill();
  
  // Curve parameters - adjusted for square favicon
  const centerX = size / 2;
  const centerY = size / 2;
  const A = size * 0.35;  // Amplitude (slightly smaller for padding)
  const B = size * 0.35;
  const a = 3;           // Horizontal frequency
  const b = 2;           // Vertical frequency  
  const delta = Math.PI / 2;  // Phase shift
  
  // Draw the Lissajous curve
  ctx.beginPath();
  ctx.strokeStyle = '#111827'; // gray-900
  ctx.lineWidth = Math.max(2, size / 16);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  
  // Draw curve with many points for smoothness
  const numPoints = 200;
  for (let i = 0; i <= numPoints; i++) {
    const t = (i / numPoints) * Math.PI * 2;
    const x = centerX + A * Math.sin(b * t);
    const y = centerY + B * Math.sin(a * t + delta);
    
    if (i === 0) {
      ctx.moveTo(x, y);
    } else {
      ctx.lineTo(x, y);
    }
  }
  
  ctx.closePath();
  ctx.stroke();
  
  return canvas;
}

// Generate multiple sizes for different devices
const sizes = [16, 32, 48, 64, 128, 256];
const outputDir = path.join(__dirname, '../public');

// Generate main favicon.png (32x32)
const favicon = generateLissajousFavicon(32);
const faviconBuffer = favicon.toBuffer('image/png');
fs.writeFileSync(path.join(outputDir, 'favicon.png'), faviconBuffer);
console.log('Generated favicon.png (32x32)');

// Generate various sizes
sizes.forEach(size => {
  const canvas = generateLissajousFavicon(size);
  const buffer = canvas.toBuffer('image/png');
  fs.writeFileSync(path.join(outputDir, `favicon-${size}x${size}.png`), buffer);
  console.log(`Generated favicon-${size}x${size}.png`);
});

// Also replace tab_logo.png
fs.writeFileSync(path.join(outputDir, 'tab_logo.png'), faviconBuffer);
console.log('Updated tab_logo.png');

console.log('Favicon generation complete!');