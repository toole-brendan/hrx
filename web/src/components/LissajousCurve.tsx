import React, { useEffect, useRef } from 'react';

const LissajousCurve = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d', { 
      alpha: false,
      desynchronized: true // Hint for better performance
    });
    if (!ctx) return;
    
    // Handle high DPI displays for smoother rendering
    const dpr = window.devicePixelRatio || 1;
    const displayWidth = 200;  // Smaller size
    const displayHeight = 133; // Maintaining aspect ratio
    
    canvas.style.width = displayWidth + 'px';
    canvas.style.height = displayHeight + 'px';
    canvas.width = displayWidth * dpr;
    canvas.height = displayHeight * dpr;
    ctx.scale(dpr, dpr);
    
    // Enable smoothing
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    
    let animationId: number;
    let startTime = performance.now();
    let lastTime = startTime;
    let pausedTime = 0; // Track total paused time
    let lastVisibleTime = startTime;
    
    // Increase segments for smoother curve
    const segmentCount = 500;
    const segmentColors = new Array(segmentCount).fill(0); // 0 = gray, 1 = black
    const targetColors = new Array(segmentCount).fill(0);
    const constantLineWidth = 4; // Thicker line weight
    const decayRate = 0.9995; // Much slower decay for extremely long black trail
    const colorSmoothness = 0.2; // Interpolation factor for color changes
    
    // Track recent t values (parametric positions) instead of spatial positions
    let recentTValues: number[] = [];
    const maxRecentT = 300; // Much longer trail by tracking many more positions
    const tStep = 0.001; // Even finer sampling for continuous trail
    let lastSampledT = -999;
    
    // Pre-calculate static values
    const centerX = displayWidth / 2;
    const centerY = displayHeight / 2;
    const A = 89;   // Scaled down proportionally
    const B = 49;   // Scaled down proportionally
    const a = 3;
    const b = 2;
    const delta = Math.PI / 2;
    const twoPi = Math.PI * 2;
    
    // Pre-calculate curve points
    const curvePoints = new Array(segmentCount);
    for (let i = 0; i < segmentCount; i++) {
      const t = (i / segmentCount) * twoPi;
      curvePoints[i] = {
        x: centerX + A * Math.sin(b * t),
        y: centerY + B * Math.sin(a * t + delta),
        t: t
      };
    }
    
    // Handle visibility changes to fix fragmented trail issue
    const handleVisibilityChange = () => {
      if (!document.hidden) {
        // Tab became visible again
        const now = performance.now();
        const timePaused = now - lastVisibleTime;
        pausedTime += timePaused;
        
        // Clear the trail history to prevent fragments
        recentTValues = [];
        lastSampledT = -999;
        
        // Reset segment colors to prevent stale trails
        segmentColors.fill(0);
        targetColors.fill(0);
      } else {
        // Tab became hidden
        lastVisibleTime = performance.now();
      }
    };
    
    // Add visibility change listener
    document.addEventListener('visibilitychange', handleVisibilityChange);
    
    const animate = (currentTime: number) => {
      const deltaTime = currentTime - lastTime;
      lastTime = currentTime;
      
      // Use actual elapsed time for perfectly smooth animation, accounting for paused time
      const elapsedSeconds = (currentTime - startTime - pausedTime) / 1000;
      const time = elapsedSeconds * 0.02; // Much slower, more meditative speed
      
      // Clear canvas with solid background matching login page
      ctx.fillStyle = '#FAFAFA';
      ctx.fillRect(0, 0, displayWidth, displayHeight);
      
      // Calculate ball position with sub-pixel precision
      const traceT = (time % 1) * twoPi;
      const traceX = centerX + A * Math.sin(b * traceT);
      const traceY = centerY + B * Math.sin(a * traceT + delta);
      
      // Sample t values at regular intervals
      if (Math.abs(traceT - lastSampledT) > tStep || traceT < lastSampledT) {
        recentTValues.unshift(traceT);
        if (recentTValues.length > maxRecentT) {
          recentTValues.pop();
        }
        lastSampledT = traceT;
      }
      
      // Update target colors based on parametric proximity
      for (let i = 0; i < segmentCount; i++) {
        const segmentT = curvePoints[i].t;
        
        // Check if this segment's t value is close to any recent t value
        let maxInfluence = 0;
        
        // Also check against current ball position
        const currentAndRecentT = [traceT, ...recentTValues];
        
        for (let j = 0; j < currentAndRecentT.length; j++) {
          const recentT = currentAndRecentT[j];
          
          // Calculate parametric distance with direction
          let tDiff = segmentT - recentT;
          
          // Handle wrap-around (since t goes from 0 to 2π)
          if (tDiff > Math.PI) {
            tDiff -= twoPi;
          } else if (tDiff < -Math.PI) {
            tDiff += twoPi;
          }
          
          // Color segments that are behind the ball only
          if (tDiff <= 0 && tDiff > -1.0) { // Wider range for longer trail
            const absDiff = Math.abs(tDiff);
            const recencyInfluence = 1 - (j / currentAndRecentT.length) * 0.1; // Much gentler falloff for extended trail
            const parametricInfluence = Math.exp(-(absDiff * absDiff) / 0.05); // Much wider influence area
            const influence = recencyInfluence * parametricInfluence;
            maxInfluence = Math.max(maxInfluence, influence);
          }
        }
        
        if (maxInfluence > 0) {
          targetColors[i] = maxInfluence; // 1 = full black, 0 = gray
        } else {
          targetColors[i] = targetColors[i] * decayRate; // Slowly fade back to gray
        }
        
        // Smooth interpolation of actual colors
        segmentColors[i] += (targetColors[i] - segmentColors[i]) * colorSmoothness;
      }
      
      // Draw the curve with constant line width
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.lineWidth = constantLineWidth;
      
      // First, draw the entire curve in gray as a base
      ctx.strokeStyle = 'rgba(128, 128, 128, 0.9)';
      ctx.beginPath();
      for (let i = 0; i < segmentCount; i++) {
        const point = curvePoints[i];
        if (i === 0) {
          ctx.moveTo(point.x, point.y);
        } else {
          ctx.lineTo(point.x, point.y);
        }
      }
      ctx.closePath();
      ctx.stroke();
      
      // Then, overdraw the colored sections with smooth gradient
      // Draw each segment with a color that smoothly transitions from black to gray
      for (let i = 0; i < segmentCount; i++) {
        const point = curvePoints[i];
        const nextPoint = curvePoints[(i + 1) % segmentCount];
        const colorValue = segmentColors[i];
        
        // Only draw if there's some coloring (optimization)
        if (colorValue > 0.01) {
          ctx.beginPath();
          ctx.moveTo(point.x, point.y);
          ctx.lineTo(nextPoint.x, nextPoint.y);
          
          // Smooth gradient from black (20) to gray (128)
          const grayValue = Math.floor(20 + (1 - colorValue) * 108);
          const opacity = 0.9 + colorValue * 0.05; // Slightly higher opacity for black
          
          ctx.strokeStyle = `rgba(${grayValue}, ${grayValue}, ${grayValue}, ${opacity})`;
          ctx.stroke();
        }
      }
      
      // Draw trace ball with smooth shadow
      ctx.save();
      ctx.shadowColor = 'rgba(0, 0, 0, 0.2)';
      ctx.shadowBlur = 5;
      ctx.shadowOffsetX = 1;
      ctx.shadowOffsetY = 1;
      
      // Main ball with gradient
      ctx.beginPath();
      ctx.arc(traceX, traceY, 6, 0, twoPi);
      const ballGradient = ctx.createRadialGradient(traceX - 1, traceY - 1, 0, traceX, traceY, 6);
      ballGradient.addColorStop(0, 'rgba(40, 40, 40, 0.95)');
      ballGradient.addColorStop(0.7, 'rgba(20, 20, 20, 0.9)');
      ballGradient.addColorStop(1, 'rgba(0, 0, 0, 0.7)');
      ctx.fillStyle = ballGradient;
      ctx.fill();
      ctx.restore();
      
      // REMOVED: The solid ribbon trail code that was here
      // This was causing the appearance of changing line weight
      
      animationId = requestAnimationFrame(animate);
    };
    
    animationId = requestAnimationFrame(animate);
    
    return () => {
      cancelAnimationFrame(animationId);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);
  
  return (
    <canvas 
      ref={canvasRef} 
      className="block mx-auto"
      style={{ 
        imageRendering: 'auto',
        transform: 'translateZ(0)', // Force GPU acceleration
      }} 
    />
  );
};

export default LissajousCurve;