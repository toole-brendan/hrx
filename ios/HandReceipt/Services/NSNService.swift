import Foundation

// MARK: - NSN Service for National Stock Number lookups

class NSNService {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    enum NSNLookupResult {
        case found(NSNDetails)
        case notFound
        case networkError(Error)
    }
    
    func lookupNSN(_ nsn: String) async -> NSNLookupResult {
        guard !nsn.isEmpty, isValidNSNFormat(nsn) else {
            return .notFound
        }
        
        do {
            let response = try await apiService.lookupNSN(nsn: nsn)
            debugPrint("✅ NSN lookup successful for \(nsn): \(response.data.nomenclature)")
            return .found(response.data)
        } catch {
            // Check if it's a 404/not found error
            if let apiError = error as? APIService.APIError, case .itemNotFound = apiError {
                // 404 is expected for unknown NSNs - not an error
                debugPrint("ℹ️ NSN \(nsn) not found in database (this is normal for unlisted items)")
                return .notFound
            } else {
                // Only log actual network/API errors
                debugPrint("⚠️ NSN lookup failed for \(nsn): \(error.localizedDescription)")
                return .networkError(error)
            }
        }
    }
    
    private func isValidNSNFormat(_ nsn: String) -> Bool {
        // NSN format: XXXX-XX-XXX-XXXX
        let nsnPattern = "^\\d{4}-?\\d{2}-?\\d{3}-?\\d{4}$"
        return nsn.range(of: nsnPattern, options: .regularExpression) != nil
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
                        let lookupResult = await self.lookupNSN(nsn)
                        switch lookupResult {
                        case .found(let details):
                            return (nsn, details)
                        case .notFound, .networkError:
                            // If lookup fails, return nil for this NSN
                            print("Failed to lookup NSN \(nsn)")
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