// Utility to generate favicon from Lissajous curve
export function generateLissajousFavicon(size: number = 32): string {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  
  if (!ctx) {
    throw new Error('Could not get canvas context');
  }
  
  // Clear canvas with transparent background
  ctx.clearRect(0, 0, size, size);
  
  // Add a white background circle for better visibility
  ctx.fillStyle = '#ffffff'; // white
  ctx.beginPath();
  ctx.arc(size/2, size/2, size/2 - 1, 0, Math.PI * 2);
  ctx.fill();
  
  // Curve parameters - adjusted for square favicon
  const centerX = size / 2;
  const centerY = size / 2;
  const A = size * 0.28;  // Amplitude (smaller to fit within circle)
  const B = size * 0.28;
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
  
  // Convert to data URL
  return canvas.toDataURL('image/png');
}

// Function to set the favicon dynamically
export function setLissajousFavicon() {
  // Generate favicon
  const faviconDataUrl = generateLissajousFavicon(32);
  
  // Remove existing favicon
  const existingFavicon = document.querySelector("link[rel*='icon']");
  if (existingFavicon) {
    existingFavicon.remove();
  }
  
  // Create new favicon link
  const link = document.createElement('link');
  link.type = 'image/png';
  link.rel = 'icon';
  link.href = faviconDataUrl;
  document.head.appendChild(link);
  
  // Also set for Apple devices
  const appleLink = document.createElement('link');
  appleLink.rel = 'apple-touch-icon';
  appleLink.href = generateLissajousFavicon(180);
  document.head.appendChild(appleLink);
}