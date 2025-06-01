import Foundation

// MARK: - NSN Service for National Stock Number lookups

class NSNService {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func lookupNSN(_ nsn: String) async throws -> NSNDetails {
        // Call the backend NSN lookup endpoint
        let response = try await apiService.lookupNSN(nsn: nsn)
        return response.data
    }
    
    // Batch lookup for multiple NSNs
    func lookupNSNs(_ nsns: [String]) async throws -> [String: NSNDetails] {
        var results: [String: NSNDetails] = [:]
        
        // Process in batches to avoid overwhelming the API
        let batchSize = 10
        for batch in nsns.chunked(into: batchSize) {
            let batchResults = try await withThrowingTaskGroup(of: (String, NSNDetails?).self) { group in
                for nsn in batch {
                    group.addTask {
                        do {
                            let details = try await self.lookupNSN(nsn)
                            return (nsn, details)
                        } catch {
                            // If lookup fails, return nil for this NSN
                            print("Failed to lookup NSN \(nsn): \(error)")
                            return (nsn, nil)
                        }
                    }
                }
                
                var batchResults: [(String, NSNDetails?)] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            
            // Add successful lookups to results
            for (nsn, details) in batchResults {
                if let details = details {
                    results[nsn] = details
                }
            }
        }
        
        return results
    }
}

// Helper extension to chunk arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
} 