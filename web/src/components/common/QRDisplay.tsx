import React from 'react';

interface QRDisplayProps {
  value: string;
  size?: number;
  includeMargin?: boolean;
}

/**
 * Simple QR code display component to show QR codes from text values
 */
const QRDisplay: React.FC<QRDisplayProps> = ({ 
  value, 
  size = 128,
  includeMargin = true 
}) => {
  // Generate a mock QR code SVG based on the value
  // In a real application, we would use a library like qrcode.react
  const generateMockQR = () => {
    // Use the string value to create a deterministic pattern
    const hash = value.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    
    // Create a pattern based on the hash
    const cells = [];
    for (let i = 0; i < 8; i++) {
      for (let j = 0; j < 8; j++) {
        const shouldFill = ((hash * (i + 1) * (j + 1)) % 100) > 50;
        if (shouldFill) {
          cells.push(`<rect x="${i * (size/8)}" y="${j * (size/8)}" width="${size/8}" height="${size/8}" />`);
        }
      }
    }

    const padding = includeMargin ? size * 0.1 : 0;
    const totalSize = size + (padding * 2);
    
    return `
      <svg width="${totalSize}" height="${totalSize}" viewBox="0 0 ${totalSize} ${totalSize}" xmlns="http://www.w3.org/2000/svg">
        <rect width="${totalSize}" height="${totalSize}" fill="white" />
        <g fill="#1C2541" transform="translate(${padding}, ${padding})">
          ${cells.join('')}
        </g>
        <rect x="${totalSize/2 - size/5}" y="${totalSize/2 - size/5}" width="${size/2.5}" height="${size/2.5}" fill="white" />
        <text x="${totalSize/2}" y="${totalSize/2}" text-anchor="middle" dominant-baseline="middle" font-size="${size/20}" fill="#6941C6">QR</text>
      </svg>
    `;
  };

  const qrSvg = generateMockQR();
  const qrDataUri = `data:image/svg+xml;base64,${btoa(qrSvg)}`;

  return (
    <img 
      src={qrDataUri} 
      alt={`QR Code: ${value}`} 
      width={size + (includeMargin ? size * 0.2 : 0)} 
      height={size + (includeMargin ? size * 0.2 : 0)} 
      className="bg-white"
    />
  );
};

export default QRDisplay; 