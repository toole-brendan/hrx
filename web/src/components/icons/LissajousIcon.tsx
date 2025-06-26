import React, { useEffect, useRef } from 'react';

interface LissajousIconProps {
  className?: string;
  width?: number;
  height?: number;
}

const LissajousIcon: React.FC<LissajousIconProps> = ({ className = '', width = 64, height = 32 }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d', { 
      alpha: true
    });
    
    if (!ctx) return;
    
    // Handle high DPI displays for smoother rendering
    const dpr = window.devicePixelRatio || 1;
    
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.scale(dpr, dpr);
    
    // Enable smoothing
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Curve parameters - scaled for icon size
    const centerX = width / 2;
    const centerY = height / 2;
    const A = width * 0.42;  // Horizontal amplitude
    const B = height * 0.42; // Vertical amplitude (increased for more vertical stretch)
    const a = 3;           // Horizontal frequency
    const b = 2;           // Vertical frequency
    const delta = Math.PI / 2;  // Phase shift
    
    // Draw the Lissajous curve
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(17, 24, 39, 0.9)'; // gray-900 with opacity
    ctx.lineWidth = Math.max(1.2, height / 20);
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
    
  }, [width, height]);
  
  return (
    <canvas 
      ref={canvasRef} 
      className={className}
      style={{ 
        imageRendering: 'auto',
        display: 'block'
      }} 
    />
  );
};

export default LissajousIcon;