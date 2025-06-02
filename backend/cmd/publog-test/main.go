package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/publog"
)

func main() {
	// Command line flags
	dataDir := flag.String("data", "internal/publog", "Directory containing PUB LOG data files")
	verbose := flag.Bool("verbose", false, "Enable verbose logging")
	flag.Parse()

	// Setup logger
	logger := logrus.New()
	if *verbose {
		logger.SetLevel(logrus.DebugLevel)
	} else {
		logger.SetLevel(logrus.InfoLevel)
	}

	// Initialize publog service
	service := publog.NewServiceWithLogger(logger)

	// Load data
	fmt.Printf("Loading PUB LOG data from %s...\n", *dataDir)
	if err := service.LoadDataFromDirectory(*dataDir); err != nil {
		logger.WithError(err).Fatal("Failed to load PUB LOG data")
	}

	// Print statistics
	stats := service.GetStats()
	fmt.Println("\nData loaded successfully!")
	fmt.Printf("NSN Items: %d\n", stats["nsn_items"])
	fmt.Printf("Part Numbers: %d\n", stats["part_numbers"])
	fmt.Printf("CAGE Addresses: %d\n", stats["cage_addresses"])

	// Interactive search
	fmt.Println("\nEnter search queries (type 'quit' to exit):")
	fmt.Println("Examples:")
	fmt.Println("  - NSN: 5820-01-234-5678")
	fmt.Println("  - Part Number: 12345")
	fmt.Println("  - Item Name: radio")
	fmt.Println("  - CAGE Code: 12345")

	scanner := bufio.NewScanner(os.Stdin)
	for {
		fmt.Print("\nSearch> ")
		if !scanner.Scan() {
			break
		}

		query := strings.TrimSpace(scanner.Text())
		if query == "" {
			continue
		}
		if query == "quit" || query == "exit" {
			break
		}

		// Perform search
		results, err := service.Search(query)
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			continue
		}

		// Display results
		if len(results) == 0 {
			fmt.Println("No results found.")
			continue
		}

		fmt.Printf("\nFound %d result(s):\n", len(results))
		for i, result := range results {
			if i >= 10 {
				fmt.Printf("... and %d more results\n", len(results)-10)
				break
			}

			fmt.Printf("\n[%d] NSN: %s\n", i+1, result.NSNItem.NSN)
			fmt.Printf("    Name: %s\n", result.NSNItem.ItemName)
			if result.NSNItem.ItemDescription != "" {
				fmt.Printf("    Description: %s\n", result.NSNItem.ItemDescription)
			}
			if result.NSNItem.UnitOfIssue != "" {
				fmt.Printf("    Unit of Issue: %s\n", result.NSNItem.UnitOfIssue)
			}
			if result.NSNItem.UnitPrice > 0 {
				fmt.Printf("    Unit Price: $%.2f\n", result.NSNItem.UnitPrice)
			}

			// Show part numbers
			if len(result.PartNumbers) > 0 {
				fmt.Print("    Part Numbers: ")
				for j, part := range result.PartNumbers {
					if j > 3 {
						fmt.Printf("... and %d more", len(result.PartNumbers)-3)
						break
					}
					if j > 0 {
						fmt.Print(", ")
					}
					fmt.Printf("%s (CAGE: %s)", part.PartNumber, part.CAGECode)
				}
				fmt.Println()
			}

			// Show CAGE info
			if result.CAGEInfo != nil && result.CAGEInfo.Address != nil {
				fmt.Printf("    Manufacturer: %s\n", result.CAGEInfo.Address.CompanyName)
				if result.CAGEInfo.Address.City != "" && result.CAGEInfo.Address.State != "" {
					fmt.Printf("    Location: %s, %s\n", result.CAGEInfo.Address.City, result.CAGEInfo.Address.State)
				}
			}
		}
	}

	fmt.Println("\nGoodbye!")
}
