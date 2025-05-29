package main

import (
	"context"
	"encoding/csv"
	"flag"
	"log"
	"os"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
)

func main() {
	var (
		csvFile    = flag.String("file", "", "Path to PUBLOG CSV file")
		configFile = flag.String("config", "configs/config.yaml", "Path to config file")
		dryRun     = flag.Bool("dry-run", false, "Preview import without saving to database")
	)
	flag.Parse()

	if *csvFile == "" {
		log.Fatal("CSV file path is required. Use -file flag")
	}

	// Load configuration
	viper.SetConfigFile(*configFile)
	if err := viper.ReadInConfig(); err != nil {
		log.Fatalf("Failed to read config: %v", err)
	}

	// Setup logger
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)

	// Connect to database
	db, err := database.Connect()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Run migrations
	if err := database.Migrate(db); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize NSN service
	nsnConfig := &config.NSNConfig{
		CacheEnabled:  false, // Disable cache for import
		BulkBatchSize: 1000,
	}
	nsnService := nsn.NewNSNService(nsnConfig, db, logger)

	// Open CSV file
	file, err := os.Open(*csvFile)
	if err != nil {
		log.Fatalf("Failed to open CSV file: %v", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)

	// Read header
	header, err := reader.Read()
	if err != nil {
		log.Fatalf("Failed to read CSV header: %v", err)
	}

	logger.WithField("columns", header).Info("CSV header detected")

	// Map columns - adjust these based on your actual PUBLOG format
	columnMap := make(map[string]int)
	for i, col := range header {
		switch strings.ToLower(strings.TrimSpace(col)) {
		case "nsn", "national_stock_number":
			columnMap["nsn"] = i
		case "niin", "national_item_identification_number":
			columnMap["niin"] = i
		case "fsc", "federal_supply_class":
			columnMap["fsc"] = i
		case "lin", "line_item_number":
			columnMap["lin"] = i
		case "item_name", "nomenclature", "name":
			columnMap["item_name"] = i
		case "inc", "inc_code", "item_name_code":
			columnMap["inc_code"] = i
		case "ui", "unit_issue", "unit_of_issue":
			columnMap["unit_of_issue"] = i
		case "price", "unit_price":
			columnMap["unit_price"] = i
		case "cage", "cage_code":
			columnMap["cage_code"] = i
		case "part_number", "part_no":
			columnMap["part_number"] = i
		case "manufacturer", "mfg":
			columnMap["manufacturer"] = i
		}
	}

	logger.WithField("mapping", columnMap).Info("Column mapping established")

	if *dryRun {
		logger.Info("DRY RUN MODE - No data will be saved")
		// Preview first 10 records
		for i := 0; i < 10; i++ {
			record, err := reader.Read()
			if err != nil {
				break
			}
			logger.WithFields(logrus.Fields{
				"row":   i + 1,
				"nsn":   getColumn(record, columnMap, "nsn"),
				"item":  getColumn(record, columnMap, "item_name"),
				"lin":   getColumn(record, columnMap, "lin"),
				"price": getColumn(record, columnMap, "unit_price"),
			}).Info("Sample record")
		}
		return
	}

	// Import data
	ctx := context.Background()
	startTime := time.Now()

	logger.Info("Starting PUBLOG import...")

	// Rewind file to beginning
	file.Seek(0, 0)
	reader = csv.NewReader(file)

	if err := nsnService.ImportFromCSV(ctx, file); err != nil {
		log.Fatalf("Import failed: %v", err)
	}

	duration := time.Since(startTime)
	logger.WithField("duration", duration).Info("Import completed successfully")

	// Get statistics
	stats, err := nsnService.GetStatistics(ctx)
	if err == nil {
		logger.WithField("stats", stats).Info("Database statistics after import")
	}
}

func getColumn(record []string, columnMap map[string]int, key string) string {
	if idx, ok := columnMap[key]; ok && idx < len(record) {
		return strings.TrimSpace(record[idx])
	}
	return ""
}

// Sample CSV format (adjust based on actual PUBLOG format):
// NSN,NIIN,FSC,FSC_NAME,ITEM_NAME,INC_CODE,LIN,UI,UNIT_PRICE,CAGE_CODE,PART_NUMBER,MANUFACTURER
// 5120001234567,001234567,5120,Hand Tools,HAMMER BALL PEEN,12345,H12345,EA,25.50,12345,PN12345,ACME TOOLS
// 6850009876543,009876543,6850,Chemicals,CLEANER GENERAL PURPOSE,54321,C54321,GL,12.75,54321,CL9876,CLEAN CO
