import React, { useState, useEffect, useRef } from 'react';
import { cn } from '@/lib/utils';

interface ProgressiveImageProps extends React.ImgHTMLAttributes<HTMLImageElement> {
  src: string;
  alt: string;
  placeholderSrc?: string;
  fallbackSrc?: string;
  loading?: 'lazy' | 'eager';
  sizes?: string;
  srcSet?: string;
  className?: string;
  containerClassName?: string;
  onLoad?: () => void;
  onError?: () => void;
}

export const ProgressiveImage: React.FC<ProgressiveImageProps> = ({
  src,
  alt,
  placeholderSrc,
  fallbackSrc = '/placeholder-image.png',
  loading = 'lazy',
  sizes,
  srcSet,
  className,
  containerClassName,
  onLoad,
  onError,
  ...props
}) => {
  const [imageSrc, setImageSrc] = useState(placeholderSrc || '');
  const [imageLoading, setImageLoading] = useState(true);
  const [error, setError] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);
  const observerRef = useRef<IntersectionObserver | null>(null);

  useEffect(() => {
    const img = imgRef.current;
    if (!img || loading === 'eager') {
      loadImage();
      return;
    }

    // Set up Intersection Observer for lazy loading
    observerRef.current = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            loadImage();
            observerRef.current?.disconnect();
          }
        });
      },
      {
        rootMargin: '50px',
        threshold: 0.01,
      }
    );

    observerRef.current.observe(img);

    return () => {
      observerRef.current?.disconnect();
    };
  }, [src]);

  const loadImage = () => {
    const img = new Image();
    img.src = src;
    
    if (srcSet) {
      img.srcset = srcSet;
    }
    
    if (sizes) {
      img.sizes = sizes;
    }

    img.onload = () => {
      setImageSrc(src);
      setImageLoading(false);
      setError(false);
      onLoad?.();
    };

    img.onerror = () => {
      setImageSrc(fallbackSrc);
      setImageLoading(false);
      setError(true);
      onError?.();
    };
  };

  return (
    <div className={cn('relative overflow-hidden', containerClassName)}>
      <img
        ref={imgRef}
        src={imageSrc || placeholderSrc || fallbackSrc}
        alt={alt}
        sizes={sizes}
        srcSet={!imageLoading && !error ? srcSet : undefined}
        className={cn(
          'transition-all duration-300',
          imageLoading && 'blur-sm scale-105',
          !imageLoading && 'blur-0 scale-100',
          className
        )}
        {...props}
      />
      {imageLoading && placeholderSrc && (
        <div className="absolute inset-0 bg-gray-200 animate-pulse" />
      )}
    </div>
  );
};

// Hook for generating responsive image props
export const useResponsiveImage = (
  baseSrc: string,
  options?: {
    widths?: number[];
    formats?: string[];
  }
) => {
  const widths = options?.widths || [320, 640, 1024, 1280, 1920];
  const formats = options?.formats || ['webp', 'jpg'];

  const generateSrcSet = (format: string) => {
    return widths
      .map((width) => {
        const src = baseSrc.replace(/\.[^.]+$/, `-${width}w.${format}`);
        return `${src} ${width}w`;
      })
      .join(', ');
  };

  const srcSet = formats.map(generateSrcSet).join(', ');
  
  const sizes = `
    (max-width: 640px) 100vw,
    (max-width: 1024px) 50vw,
    33vw
  `.trim();

  return { srcSet, sizes };
};

// Utility to generate blur data URL placeholder
export const generateBlurDataURL = (width: number = 10, height: number = 10): string => {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  
  if (ctx) {
    ctx.fillStyle = '#f3f4f6';
    ctx.fillRect(0, 0, width, height);
  }
  
  return canvas.toDataURL();
};