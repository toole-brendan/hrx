import React from 'react';
import { DocumentsInbox } from '@/components/documents/DocumentsInbox';

export default function Documents() {
  return (
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      <div className="max-w-4xl mx-auto px-6 py-8">
        {/* Header - iOS style */}
        <div className="mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div></div>
            <div></div>
          </div>
          
          {/* Divider */}
          <div className="border-b border-ios-divider mb-6" />
          
          {/* Title section */}
          <div className="mb-8">
            <h1 className="text-5xl font-bold text-primary-text leading-tight" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
              Documents
            </h1>
          </div>
        </div>

        {/* DocumentsInbox component */}
        <DocumentsInbox />

        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>
    </div>
  );
} 