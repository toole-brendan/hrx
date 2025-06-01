import Foundation

// Enhanced Pattern Recognition for DA-2062 parsing
struct DA2062Patterns {
    
    // MARK: - LIN (Line Item Number) Extraction
    
    func extractLIN(from text: String) -> String? {
        // Multiple patterns for LIN detection
        // LIN is typically 6 characters: 1 letter + 5 alphanumeric
        let linPatterns = [
            // Standard LIN format: Letter followed by 5 alphanumeric
            "\\b[A-Z][0-9A-Z]{5}\\b",
            // Sometimes preceded by "LIN:" or "LIN"
            "LIN[:\\s]+([A-Z][0-9A-Z]{5})\\b",
            // May appear in parentheses
            "\\(([A-Z][0-9A-Z]{5})\\)",
            // Common military equipment LINs start with specific letters
            "\\b[EFGHJKLMNPQRSTUVWXYZ][0-9]{5}\\b"
        ]
        
        for pattern in linPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                // Extract the captured group if it exists, otherwise the full match
                let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                
                if let range = Range(captureRange, in: text) {
                    let lin = String(text[range])
                    
                    // Validate common LIN prefixes
                    if isValidLINPrefix(lin) {
                        return lin
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isValidLINPrefix(_ lin: String) -> Bool {
        guard lin.count == 6 else { return false }
        
        let prefix = String(lin.prefix(1))
        // Common military equipment LIN prefixes
        let validPrefixes = ["E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        
        return validPrefixes.contains(prefix)
    }
    
    // MARK: - Unit of Issue Detection
    
    func extractUnitOfIssue(from text: String) -> String? {
        // Comprehensive list of military unit-of-issue abbreviations
        let unitPatterns = [
            // Common units with word boundaries
            "\\b(EA|PR|BX|DZ|GR|CS|HD|ST|SE|KT|PG|PK|RL|CN|BT|GL|DR|QT|PT|LB|OZ|FT|IN|YD|MI|M|CM|MM|KM)\\b",
            // Units that might appear with periods
            "\\b(EA\\.|PR\\.|BX\\.|DZ\\.|SET\\.|KIT\\.|PKG\\.|PACK\\.)\\b",
            // Full words that represent units
            "\\b(EACH|PAIR|BOX|DOZEN|GROSS|CASE|HUNDRED|SET|SPOOL|KIT|PACKAGE|PACK|ROLL|CAN|BOTTLE|GALLON|DRUM)\\b"
        ]
        
        // Try patterns in order of specificity
        for pattern in unitPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                
                var unit = String(text[range]).uppercased()
                
                // Normalize common variations
                unit = normalizeUnitOfIssue(unit)
                
                return unit
            }
        }
        
        return nil
    }
    
    private func normalizeUnitOfIssue(_ unit: String) -> String {
        // Remove periods and normalize to standard abbreviations
        let normalized = unit.replacingOccurrences(of: ".", with: "")
        
        let unitMap: [String: String] = [
            "EACH": "EA",
            "PAIR": "PR",
            "BOX": "BX",
            "DOZEN": "DZ",
            "SET": "SE",
            "SPOOL": "SP",
            "KIT": "KT",
            "PACKAGE": "PG",
            "PACK": "PK",
            "ROLL": "RL",
            "CAN": "CN",
            "BOTTLE": "BT",
            "GALLON": "GL",
            "DRUM": "DR",
            "HUNDRED": "HD"
        ]
        
        return unitMap[normalized] ?? normalized
    }
    
    // MARK: - NSN (National Stock Number) Extraction
    
    func extractNSN(from text: String) -> String? {
        // Enhanced NSN patterns
        let nsnPatterns = [
            // Standard format: 1234-12-123-1234
            "\\b\\d{4}-\\d{2}-\\d{3}-\\d{4}\\b",
            // Sometimes without hyphens
            "\\b\\d{13}\\b",
            // With spaces instead of hyphens
            "\\b\\d{4}\\s\\d{2}\\s\\d{3}\\s\\d{4}\\b",
            // Preceded by "NSN:" or similar
            "NSN[:\\s]+([\\d\\s-]{13,19})"
        ]
        
        for pattern in nsnPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                
                if let range = Range(captureRange, in: text) {
                    var nsn = String(text[range])
                    
                    // Normalize NSN format
                    nsn = normalizeNSN(nsn)
                    
                    if isValidNSN(nsn) {
                        return nsn
                    }
                }
            }
        }
        
        return nil
    }
    
    private func normalizeNSN(_ nsn: String) -> String {
        // Remove all non-digits
        let digitsOnly = nsn.filter { $0.isNumber }
        
        // Format as 1234-12-123-1234 if we have 13 digits
        if digitsOnly.count == 13 {
            let p1 = String(digitsOnly.prefix(4))
            let p2 = String(digitsOnly.dropFirst(4).prefix(2))
            let p3 = String(digitsOnly.dropFirst(6).prefix(3))
            let p4 = String(digitsOnly.dropFirst(9))
            return "\(p1)-\(p2)-\(p3)-\(p4)"
        }
        
        return nsn
    }
    
    private func isValidNSN(_ nsn: String) -> Bool {
        // Check if it matches the standard format
        let pattern = "^\\d{4}-\\d{2}-\\d{3}-\\d{4}$"
        return nsn.range(of: pattern, options: .regularExpression) != nil
    }
    
    // MARK: - Military Terms Recognition
    
    struct MilitaryTerms {
        // Common military equipment terms for better recognition
        static let weaponTerms = [
            "RIFLE", "CARBINE", "PISTOL", "MACHINE GUN", "MG",
            "M4", "M4A1", "M16", "M16A2", "M16A4", "M9", "M17", "M18",
            "M249", "M240", "M2", "MK19", "M320", "M203"
        ]
        
        static let opticTerms = [
            "SIGHT", "SCOPE", "OPTIC", "NVG", "NODS", "PVS",
            "ACOG", "EOTECH", "AIMPOINT", "ELCAN", "RCO", "CCO",
            "AN/PVS-14", "AN/PVS-7", "AN/PAS-13", "FLIR"
        ]
        
        static let commoTerms = [
            "RADIO", "ANTENNA", "HANDSET", "SINCGARS", "ASIP",
            "HARRIS", "AN/PRC", "MBITR", "SATCOM", "DAGR", "PLGR"
        ]
        
        static let protectiveTerms = [
            "VEST", "HELMET", "PLATE", "CARRIER", "ARMOR",
            "IOTV", "ACH", "ECH", "ESAPI", "SAPI", "IBA",
            "BODY ARMOR", "KEVLAR", "BALLISTIC"
        ]
        
        static let medicalTerms = [
            "IFAK", "TOURNIQUET", "MEDICAL", "AID BAG", "LITTER",
            "CAT", "BANDAGE", "GAUZE", "COMBAT GAUZE"
        ]
        
        static let vehicleTerms = [
            "HMMWV", "HUMVEE", "MRAP", "STRYKER", "BRADLEY",
            "ABRAMS", "TRUCK", "TRAILER", "M-ATV", "JLTV"
        ]
        
        // Create a dictionary for fuzzy matching
        static let allTerms: Set<String> = {
            var terms = Set<String>()
            terms.formUnion(weaponTerms)
            terms.formUnion(opticTerms)
            terms.formUnion(commoTerms)
            terms.formUnion(protectiveTerms)
            terms.formUnion(medicalTerms)
            terms.formUnion(vehicleTerms)
            return terms
        }()
    }
    
    // MARK: - Enhanced Item Parsing
    
    func parseItemLine(_ line: String, lineNumber: Int) -> DA2062Item? {
        // Clean the line
        let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines or headers
        if cleanedLine.isEmpty || isHeaderLine(cleanedLine) {
            return nil
        }
        
        var confidence: Double = 0.0
        var componentsFound = 0
        
        // Extract all components first
        let nsn = extractNSN(from: cleanedLine)
        if nsn != nil {
            componentsFound += 1
        }
        
        // Extract LIN
        var itemDescriptionParts: [String] = []
        if let lin = extractLIN(from: cleanedLine) {
            itemDescriptionParts.append("[LIN: \(lin)]")
            componentsFound += 1
        }
        
        // Extract Unit of Issue
        let unitOfIssue = extractUnitOfIssue(from: cleanedLine)
        if unitOfIssue != nil {
            componentsFound += 1
        }
        
        // Extract quantity (look for numbers near unit of issue)
        let quantity = extractQuantity(from: cleanedLine, nearUnit: unitOfIssue)
        if quantity != nil {
            componentsFound += 1
        }
        
        // Extract item description
        if let description = extractItemDescription(from: cleanedLine, nsn: nsn) {
            itemDescriptionParts.append(description)
            componentsFound += 1
            
            // Boost confidence if description contains known military terms
            if containsMilitaryTerms(description) {
                confidence += 0.2
            }
        }
        
        // Calculate confidence based on components found
        confidence += Double(componentsFound) * 0.15
        let finalConfidence = min(confidence, 1.0)
        
        // Build final item description
        let finalDescription = itemDescriptionParts.joined(separator: " ")
        
        // Only return if we have minimum required data
        if !finalDescription.isEmpty || nsn != nil {
            return DA2062Item(
                lineNumber: lineNumber,
                stockNumber: nsn,
                itemDescription: finalDescription,
                quantity: quantity ?? 1,
                unitOfIssue: unitOfIssue ?? "EA",
                serialNumber: nil,
                condition: "Serviceable",
                confidence: finalConfidence,
                quantityConfidence: 0.8,
                hasExplicitSerial: false
            )
        }
        
        return nil
    }
    
    private func extractQuantity(from text: String, nearUnit: String?) -> Int? {
        // Look for numbers that might represent quantity
        let pattern = "\\b(\\d{1,4})\\b"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let numberStr = String(text[range])
                    
                    if let number = Int(numberStr), number > 0 && number < 1000 {
                        // Check if this number is near the unit of issue
                        if let unit = nearUnit,
                           let unitRange = text.range(of: unit),
                           let numberRange = text.range(of: numberStr) {
                            
                            let distance = text.distance(from: numberRange.upperBound, to: unitRange.lowerBound)
                            if abs(distance) < 10 { // Within 10 characters
                                return number
                            }
                        }
                        
                        // If no unit or not near, still consider numbers 1-100 as likely quantities
                        if number <= 100 {
                            return number
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractItemDescription(from text: String, nsn: String?) -> String? {
        var workingText = text
        
        // Remove NSN if present
        if let nsn = nsn {
            workingText = workingText.replacingOccurrences(of: nsn, with: "")
        }
        
        // Remove common non-description elements
        let elementsToRemove = [
            "\\b\\d{1,3}\\b", // Line numbers
            "\\b[A-Z]{2,3}\\b", // Unit codes (but preserve longer acronyms)
            "\\$[\\d,]+\\.\\d{2}", // Prices
            "\\b\\d{4}-\\d{2}-\\d{2}\\b" // Dates
        ]
        
        for pattern in elementsToRemove {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                workingText = regex.stringByReplacingMatches(
                    in: workingText,
                    range: NSRange(workingText.startIndex..., in: workingText),
                    withTemplate: ""
                )
            }
        }
        
        // Clean up multiple spaces
        workingText = workingText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        workingText = workingText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return if we have meaningful content
        return workingText.count > 3 ? workingText : nil
    }
    
    private func containsMilitaryTerms(_ text: String) -> Bool {
        let upperText = text.uppercased()
        return MilitaryTerms.allTerms.contains { term in
            upperText.contains(term)
        }
    }
    
    private func isHeaderLine(_ line: String) -> Bool {
        let headerPatterns = [
            "HAND RECEIPT", "DA FORM", "STOCK NUMBER", "ITEM DESCRIPTION",
            "QTY", "UI", "SERIAL NUMBER", "NOMENCLATURE", "UNIT PRICE",
            "FROM:", "TO:", "DATE:", "PAGE", "SIGNATURE"
        ]
        
        let upperLine = line.uppercased()
        return headerPatterns.contains { pattern in
            upperLine.contains(pattern)
        }
    }
    
    // MARK: - Multi-line Item Detection
    
    func detectMultiLineItems(from lines: [String]) -> [[String]] {
        var itemGroups: [[String]] = []
        var currentGroup: [String] = []
        
        for (_, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and headers
            if trimmedLine.isEmpty || isHeaderLine(trimmedLine) {
                continue
            }
            
            // Check if this line starts a new item (has NSN or line number)
            if startsNewItem(trimmedLine) {
                if !currentGroup.isEmpty {
                    itemGroups.append(currentGroup)
                }
                currentGroup = [trimmedLine]
            } else if !currentGroup.isEmpty {
                // This might be continuation (serial number, notes, etc.)
                currentGroup.append(trimmedLine)
            }
        }
        
        // Don't forget the last group
        if !currentGroup.isEmpty {
            itemGroups.append(currentGroup)
        }
        
        return itemGroups
    }
    
    private func startsNewItem(_ line: String) -> Bool {
        // Line starts with a number (line item number) or contains NSN
        let startsWithNumber = line.first?.isNumber ?? false
        let hasNSN = extractNSN(from: line) != nil
        
        return startsWithNumber || hasNSN
    }
    
    // MARK: - Serial Number Extraction from Multi-line
    
    func extractSerialFromLines(_ lines: [String]) -> String? {
        for line in lines {
            // Common serial number patterns
            let serialPatterns = [
                "S/N[:\\s]+([A-Z0-9-]+)",
                "SN[:\\s]+([A-Z0-9-]+)",
                "SERIAL[:\\s]+([A-Z0-9-]+)",
                "\\b([A-Z0-9]{6,20})\\b" // Generic alphanumeric serial
            ]
            
            for pattern in serialPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: line) {
                    
                    let serial = String(line[range])
                    
                    // Validate serial looks reasonable
                    if serial.count >= 6 && serial.count <= 20 &&
                       !serial.allSatisfy({ $0.isNumber }) { // Not all numbers (avoid confusion with NSN)
                        return serial
                    }
                }
            }
        }
        
        return nil
    }
} 