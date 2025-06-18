import React from 'react';
import { DocumentsInbox } from '@/components/documents/DocumentsInbox';

export default function Documents() {
  return (
    <div className="min-h-screen bg-app-background">
      <div className="max-w-7xl mx-auto px-6 py-8">
        <DocumentsInbox />
      </div>
    </div>
  );
} 