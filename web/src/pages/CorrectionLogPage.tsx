import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';

// Updated interface to match Go backend domain.CorrectionEvent model
interface CorrectionEvent {
  eventId: string;            // Mapped from EventID
  originalEventId: string;    // Mapped from OriginalEventID
  originalEventType: string;  // Mapped from OriginalEventType
  reason: string;
  correctingUserId: number;   // Mapped from CorrectingUserID (uint64 -> number)
  correctionTimestamp: string; // Mapped from CorrectionTimestamp (time.Time -> string)
  // Optional ledger metadata - adjust based on actual API response inclusion
  ledgerTransactionId?: number;
  ledgerSequenceNumber?: number;
}

const CorrectionLogPage: React.FC = () => {
  const { user, authedFetch, isLoading: isAuthLoading } = useAuth();
  const [correctionEvents, setCorrectionEvents] = useState<CorrectionEvent[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCorrectionEvents = async () => {
      if (isAuthLoading) return;

      setIsLoading(true);
      setError(null);
      try {
        // Use the confirmed endpoint /api/corrections
        const { data } = await authedFetch<CorrectionEvent[]>('/api/corrections', { method: 'GET' });
        setCorrectionEvents(data || []);
      } catch (err: any) {
        console.error("Error fetching correction events:", err);
        setError(err.message || 'Failed to fetch correction log.');
      } finally {
        setIsLoading(false);
      }
    };

    fetchCorrectionEvents();
  }, [authedFetch, isAuthLoading]);

  if (isAuthLoading) {
    return (
      <div className="text-center p-4">
        <p>Initializing authentication...</p>
        {/* TODO: Add a spinner component */}
      </div>
    );
  }

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">Correction Log</h1>

      {isLoading && (
        <div className="text-center">
          <p>Loading correction events...</p>
          {/* TODO: Add a spinner component */}
        </div>
      )}

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-4" role="alert">
          <strong className="font-bold">Error:</strong>
          <span className="block sm:inline"> {error}</span>
        </div>
      )}

      {!isLoading && !error && correctionEvents.length === 0 && (
        <p>No correction events found.</p>
      )}

      {!isLoading && !error && correctionEvents.length > 0 && (
        <div className="overflow-x-auto shadow-md sm:rounded-lg">
          <table className="min-w-full bg-white border border-gray-200 text-sm">
            <thead className="bg-gray-50">
              <tr className="border-b">
                {/* Update headers to match the new interface fields */}
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Event ID</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Original Event ID</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Timestamp</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Corrected By User</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Reason</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Original Event Type</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Ledger Tx ID</th>
                <th className="text-left py-3 px-4 font-semibold text-gray-600 uppercase tracking-wider">Ledger Seq No</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {correctionEvents.map((event) => (
                <tr key={event.eventId} className="hover:bg-gray-50">
                  {/* Update data cells to match the new interface fields */}
                  <td className="py-3 px-4 whitespace-nowrap">{event.eventId}</td>
                  <td className="py-3 px-4 whitespace-nowrap">{event.originalEventId}</td>
                  <td className="py-3 px-4 whitespace-nowrap">{new Date(event.correctionTimestamp).toLocaleString()}</td>
                  <td className="py-3 px-4 whitespace-nowrap">{event.correctingUserId}</td>
                  <td className="py-3 px-4">{event.reason}</td>
                  <td className="py-3 px-4 whitespace-nowrap">{event.originalEventType}</td>
                  <td className="py-3 px-4 whitespace-nowrap">{event.ledgerTransactionId ?? 'N/A'}</td>
                  <td className="py-3 px-4 whitespace-nowrap">{event.ledgerSequenceNumber ?? 'N/A'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default CorrectionLogPage; 