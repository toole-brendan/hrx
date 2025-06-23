package ai

import (
	"fmt"
	"regexp"
	"strings"
)

// normalizeNSN normalizes NSN to standard format ####-##-###-####
func normalizeNSN(nsn string) string {
	// Remove all non-numeric characters
	cleaned := regexp.MustCompile(`[^0-9]`).ReplaceAllString(nsn, "")
	
	// Check if we have exactly 13 digits
	if len(cleaned) != 13 {
		return ""
	}
	
	// Format as ####-##-###-####
	return fmt.Sprintf("%s-%s-%s-%s", 
		cleaned[0:4], 
		cleaned[4:6], 
		cleaned[6:9], 
		cleaned[9:13])
}

// isValidNSN checks if NSN is in valid format
func isValidNSN(nsn string) bool {
	// Check ####-##-###-#### format
	if len(nsn) != 16 {
		return false
	}
	
	// Check hyphen positions
	if nsn[4] != '-' || nsn[7] != '-' || nsn[11] != '-' {
		return false
	}
	
	// Check that all other characters are digits
	for i, char := range nsn {
		if i == 4 || i == 7 || i == 11 {
			continue // Skip hyphens
		}
		if char < '0' || char > '9' {
			return false
		}
	}
	
	return true
}

// isWeapon checks if an NSN represents a weapon
func isWeapon(nsn string) bool {
	if len(nsn) < 4 {
		return false
	}
	
	// FSC 1005 is for weapons
	return nsn[0:4] == "1005"
}

// extractDA2062SerialNumber attempts to extract serial numbers from text
func extractDA2062SerialNumber(text string, itemType string) string {
	// Weapon-specific patterns
	weaponPatterns := []string{
		`(?i)s[\./\s]*n[\./\s]*:?\s*([A-Z0-9]{6,10})`,
		`(?i)serial[\s:]*([A-Z0-9]{6,10})`,
		`\b(FE[0-9]{6})\b`, // M4 pattern
		`\b(W[0-9]{6,7})\b`, // M16 pattern
		`\b(M4[0-9]{6})\b`, // M4 with prefix
		`\b(M9[0-9]{6})\b`, // M9 pattern
	}
	
	// Optics patterns
	opticsPatterns := []string{
		`\b(PVS14-[0-9]{5,6})\b`,
		`\b(PAS13-[0-9]{5,6})\b`,
		`\b(M68-[0-9]{6})\b`,
		`\b(AN/[A-Z]{3}-[0-9]{2,3})\b`, // Generic AN/ pattern
	}
	
	// Body armor patterns
	armorPatterns := []string{
		`\b(20[0-9]{2}-[0-9]{6})\b`, // Year-based pattern
		`\b(BA[0-9]{8})\b`,           // BA prefix pattern
		`\b(IOTV[0-9]{6})\b`,         // IOTV specific
	}
	
	// Try weapon patterns first
	if itemType == "weapon" {
		for _, pattern := range weaponPatterns {
			re := regexp.MustCompile(pattern)
			if matches := re.FindStringSubmatch(text); len(matches) > 1 {
				return strings.ToUpper(matches[1])
			}
		}
	}
	
	// Try optics patterns
	if itemType == "optics" {
		for _, pattern := range opticsPatterns {
			re := regexp.MustCompile(pattern)
			if matches := re.FindStringSubmatch(text); len(matches) > 1 {
				return strings.ToUpper(matches[1])
			}
		}
	}
	
	// Try armor patterns
	if itemType == "armor" {
		for _, pattern := range armorPatterns {
			re := regexp.MustCompile(pattern)
			if matches := re.FindStringSubmatch(text); len(matches) > 1 {
				return strings.ToUpper(matches[1])
			}
		}
	}
	
	// Try all patterns if type not specified
	allPatterns := append(append(weaponPatterns, opticsPatterns...), armorPatterns...)
	for _, pattern := range allPatterns {
		re := regexp.MustCompile(pattern)
		if matches := re.FindStringSubmatch(text); len(matches) > 1 {
			return strings.ToUpper(matches[1])
		}
	}
	
	// Generic alphanumeric pattern as fallback
	genericPattern := regexp.MustCompile(`\b([A-Z0-9]{6,12})\b`)
	if matches := genericPattern.FindStringSubmatch(strings.ToUpper(text)); len(matches) > 1 {
		return matches[1]
	}
	
	return ""
}

// identifyMilitaryEquipmentType attempts to identify equipment type from NSN or description
func identifyMilitaryEquipmentType(nsn string, description string) string {
	// NSN prefix to equipment type mapping
	nsnPrefixes := map[string]string{
		"1005": "weapon",
		"5855": "optics",
		"8470": "armor",
		"8465": "clothing",
		"5180": "tool",
		"5965": "communications",
		"6515": "medical",
		"8415": "clothing",
		"1095": "weapon", // Special weapons
		"1010": "weapon", // Launchers
	}
	
	if nsn != "" && len(nsn) >= 4 {
		prefix := nsn[0:4]
		if equipType, ok := nsnPrefixes[prefix]; ok {
			return equipType
		}
	}
	
	// Check description for keywords
	descUpper := strings.ToUpper(description)
	switch {
	case strings.Contains(descUpper, "RIFLE") || strings.Contains(descUpper, "PISTOL") || 
		 strings.Contains(descUpper, "MACHINE GUN") || strings.Contains(descUpper, "CARBINE"):
		return "weapon"
	case strings.Contains(descUpper, "NIGHT VISION") || strings.Contains(descUpper, "SCOPE") ||
		 strings.Contains(descUpper, "SIGHT") || strings.Contains(descUpper, "OPTIC"):
		return "optics"
	case strings.Contains(descUpper, "HELMET") || strings.Contains(descUpper, "VEST") ||
		 strings.Contains(descUpper, "BODY ARMOR") || strings.Contains(descUpper, "IOTV"):
		return "armor"
	case strings.Contains(descUpper, "RADIO") || strings.Contains(descUpper, "ANTENNA"):
		return "communications"
	case strings.Contains(descUpper, "UNIFORM") || strings.Contains(descUpper, "BOOT"):
		return "clothing"
	case strings.Contains(descUpper, "MEDICAL") || strings.Contains(descUpper, "FIRST AID"):
		return "medical"
	default:
		return "general"
	}
}

// requiresSerialNumber checks if an item type requires a serial number
func requiresSerialNumber(nsn string) bool {
	// Get equipment type
	equipType := identifyMilitaryEquipmentType(nsn, "")
	
	// These types always require serial numbers
	requiredTypes := []string{"weapon", "optics", "communications"}
	
	for _, reqType := range requiredTypes {
		if equipType == reqType {
			return true
		}
	}
	
	// Some armor requires serial numbers
	if equipType == "armor" && len(nsn) >= 4 {
		// IOTV and other high-value armor
		highValueArmor := []string{"8470-01-520", "8470-01-526"} // IOTV prefixes
		for _, prefix := range highValueArmor {
			if strings.HasPrefix(nsn, prefix) {
				return true
			}
		}
	}
	
	return false
}

// validateConditionCode validates military condition codes
func validateConditionCode(code string) (string, bool) {
	code = strings.ToUpper(strings.TrimSpace(code))
	
	validCodes := map[string]string{
		"A": "Serviceable",
		"B": "Serviceable with qualification", 
		"C": "Unserviceable",
		"D": "Unserviceable (condemned)",
		"E": "Unserviceable (limited restoration)",
		"F": "Unserviceable (reparable)",
	}
	
	if _, ok := validCodes[code]; ok {
		return code, true
	}
	
	// Common variations
	variations := map[string]string{
		"SERVICEABLE": "A",
		"GOOD": "A",
		"UNSERVICEABLE": "C",
		"BAD": "C",
		"DAMAGED": "C",
	}
	
	if mappedCode, ok := variations[strings.ToUpper(code)]; ok {
		return mappedCode, true
	}
	
	return "A", false // Default to A if invalid
}

// extractUnitOfIssue extracts and normalizes unit of issue
func extractUnitOfIssue(text string) string {
	// Common military units of issue
	units := map[string]string{
		"EA": "EA",     // Each
		"EACH": "EA",
		"BX": "BX",     // Box
		"BOX": "BX",
		"CS": "CS",     // Case
		"CASE": "CS",
		"DZ": "DZ",     // Dozen
		"DOZEN": "DZ",
		"PR": "PR",     // Pair
		"PAIR": "PR",
		"SE": "SE",     // Set
		"SET": "SE",
		"RL": "RL",     // Roll
		"ROLL": "RL",
		"PK": "PK",     // Pack
		"PACK": "PK",
		"HD": "HD",     // Hundred
		"HUNDRED": "HD",
		"TH": "TH",     // Thousand
		"THOUSAND": "TH",
	}
	
	textUpper := strings.ToUpper(text)
	
	// Look for unit patterns
	for long, short := range units {
		if strings.Contains(textUpper, long) {
			return short
		}
	}
	
	// Default to EA (Each) if not found
	return "EA"
}

// parseQuantity extracts quantity from text
func parseQuantity(text string) int {
	// Look for patterns like "QTY: 10" or "10 EA"
	patterns := []string{
		`(?i)qty[\s:]*(\d+)`,
		`(?i)quantity[\s:]*(\d+)`,
		`(\d+)\s*(?:ea|each|bx|box|cs|case|pr|pair)`,
		`^(\d+)\s`,
	}
	
	for _, pattern := range patterns {
		re := regexp.MustCompile(pattern)
		if matches := re.FindStringSubmatch(text); len(matches) > 1 {
			// Convert string to int
			var qty int
			fmt.Sscanf(matches[1], "%d", &qty)
			if qty > 0 {
				return qty
			}
		}
	}
	
	// Default to 1
	return 1
}