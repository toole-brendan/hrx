package config

import (
	"fmt"
	"time"

	"github.com/spf13/viper"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	ImmuDB   ImmuDBConfig   `mapstructure:"immudb"`
	MinIO    MinIOConfig    `mapstructure:"minio"`
	NSN      NSNConfig      `mapstructure:"nsn"`
	Redis    RedisConfig    `mapstructure:"redis"`
	Logging  LoggingConfig  `mapstructure:"logging"`
	Security SecurityConfig `mapstructure:"security"`
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Port            string        `mapstructure:"port"`
	Host            string        `mapstructure:"host"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout"`
	ShutdownTimeout time.Duration `mapstructure:"shutdown_timeout"`
	Environment     string        `mapstructure:"environment"`
	TLSEnabled      bool          `mapstructure:"tls_enabled"`
	CertFile        string        `mapstructure:"cert_file"`
	KeyFile         string        `mapstructure:"key_file"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	User            string        `mapstructure:"user"`
	Password        string        `mapstructure:"password"`
	DBName          string        `mapstructure:"db_name"`
	SSLMode         string        `mapstructure:"ssl_mode"`
	MaxOpenConns    int           `mapstructure:"max_open_conns"`
	MaxIdleConns    int           `mapstructure:"max_idle_conns"`
	ConnMaxLifetime time.Duration `mapstructure:"conn_max_lifetime"`
	MigrationPath   string        `mapstructure:"migration_path"`
}

// GetDSN returns the database connection string
func (d DatabaseConfig) GetDSN() string {
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode)
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	SecretKey      string        `mapstructure:"secret_key"`
	AccessExpiry   time.Duration `mapstructure:"access_expiry"`
	RefreshExpiry  time.Duration `mapstructure:"refresh_expiry"`
	Issuer         string        `mapstructure:"issuer"`
	Audience       string        `mapstructure:"audience"`
	Algorithm      string        `mapstructure:"algorithm"`
	RefreshEnabled bool          `mapstructure:"refresh_enabled"`
}

// ImmuDBConfig holds ImmuDB configuration
type ImmuDBConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Username string `mapstructure:"username"`
	Password string `mapstructure:"password"`
	Database string `mapstructure:"database"`
	Enabled  bool   `mapstructure:"enabled"`
}

// MinIOConfig holds MinIO configuration
type MinIOConfig struct {
	Endpoint        string `mapstructure:"endpoint"`
	AccessKeyID     string `mapstructure:"access_key_id"`
	SecretAccessKey string `mapstructure:"secret_access_key"`
	UseSSL          bool   `mapstructure:"use_ssl"`
	BucketName      string `mapstructure:"bucket_name"`
	Region          string `mapstructure:"region"`
	Enabled         bool   `mapstructure:"enabled"`
}

// NSNConfig holds NSN service configuration
type NSNConfig struct {
	APIEndpoint    string        `mapstructure:"api_endpoint"`
	APIKey         string        `mapstructure:"api_key"`
	CacheEnabled   bool          `mapstructure:"cache_enabled"`
	CacheTTL       time.Duration `mapstructure:"cache_ttl"`
	RateLimitRPS   int           `mapstructure:"rate_limit_rps"`
	TimeoutSeconds int           `mapstructure:"timeout_seconds"`
	RetryAttempts  int           `mapstructure:"retry_attempts"`
	BulkBatchSize  int           `mapstructure:"bulk_batch_size"`
}

// RedisConfig holds Redis configuration
type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
	Enabled  bool   `mapstructure:"enabled"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level      string `mapstructure:"level"`
	Format     string `mapstructure:"format"`
	Output     string `mapstructure:"output"`
	Filename   string `mapstructure:"filename"`
	MaxSize    int    `mapstructure:"max_size"`
	MaxBackups int    `mapstructure:"max_backups"`
	MaxAge     int    `mapstructure:"max_age"`
	Compress   bool   `mapstructure:"compress"`
}

type SecurityConfig struct {
	PasswordMinLength     int           `mapstructure:"password_min_length"`
	PasswordRequireUpper  bool          `mapstructure:"password_require_upper"`
	PasswordRequireLower  bool          `mapstructure:"password_require_lower"`
	PasswordRequireDigit  bool          `mapstructure:"password_require_digit"`
	PasswordRequireSymbol bool          `mapstructure:"password_require_symbol"`
	SessionTimeout        time.Duration `mapstructure:"session_timeout"`
	MaxLoginAttempts      int           `mapstructure:"max_login_attempts"`
	LockoutDuration       time.Duration `mapstructure:"lockout_duration"`
	CORSAllowedOrigins    []string      `mapstructure:"cors_allowed_origins"`
	RateLimitEnabled      bool          `mapstructure:"rate_limit_enabled"`
	RateLimitRPS          int           `mapstructure:"rate_limit_rps"`
}

// LoadConfig loads configuration from file and environment variables
func LoadConfig(configPath string) (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(configPath)
	viper.AddConfigPath("./configs")
	viper.AddConfigPath(".")

	// Set default values
	setDefaults()

	// Enable environment variable support
	viper.AutomaticEnv()
	viper.SetEnvPrefix("HR")

	// Read config file
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// Config file not found, continue with defaults and env vars
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Validate configuration
	if err := validateConfig(&config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return &config, nil
}

func setDefaults() {
	// Server defaults
	viper.SetDefault("server.port", "8080")
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.read_timeout", "30s")
	viper.SetDefault("server.write_timeout", "30s")
	viper.SetDefault("server.shutdown_timeout", "10s")
	viper.SetDefault("server.environment", "development")
	viper.SetDefault("server.tls_enabled", false)

	// Database defaults
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.ssl_mode", "disable")
	viper.SetDefault("database.max_open_conns", 25)
	viper.SetDefault("database.max_idle_conns", 5)
	viper.SetDefault("database.conn_max_lifetime", "5m")
	viper.SetDefault("database.migration_path", "./migrations")

	// JWT defaults
	viper.SetDefault("jwt.access_expiry", "24h")
	viper.SetDefault("jwt.refresh_expiry", "168h") // 7 days
	viper.SetDefault("jwt.issuer", "handreceipt-go")
	viper.SetDefault("jwt.audience", "handreceipt-users")
	viper.SetDefault("jwt.algorithm", "HS256")
	viper.SetDefault("jwt.refresh_enabled", true)

	// ImmuDB defaults
	viper.SetDefault("immudb.host", "localhost")
	viper.SetDefault("immudb.port", 3322)
	viper.SetDefault("immudb.database", "defaultdb")
	viper.SetDefault("immudb.enabled", true)

	// MinIO defaults
	viper.SetDefault("minio.endpoint", "localhost:9000")
	viper.SetDefault("minio.use_ssl", false)
	viper.SetDefault("minio.bucket_name", "handreceipt")
	viper.SetDefault("minio.region", "us-east-1")
	viper.SetDefault("minio.enabled", true)

	// NSN defaults
	viper.SetDefault("nsn.cache_enabled", true)
	viper.SetDefault("nsn.cache_ttl", "24h")
	viper.SetDefault("nsn.rate_limit_rps", 10)
	viper.SetDefault("nsn.timeout_seconds", 30)
	viper.SetDefault("nsn.retry_attempts", 3)
	viper.SetDefault("nsn.bulk_batch_size", 50)

	// Redis defaults
	viper.SetDefault("redis.host", "localhost")
	viper.SetDefault("redis.port", 6379)
	viper.SetDefault("redis.db", 0)
	viper.SetDefault("redis.enabled", false)

	// Logging defaults
	viper.SetDefault("logging.level", "info")
	viper.SetDefault("logging.format", "json")
	viper.SetDefault("logging.output", "stdout")
	viper.SetDefault("logging.max_size", 100)
	viper.SetDefault("logging.max_backups", 3)
	viper.SetDefault("logging.max_age", 28)
	viper.SetDefault("logging.compress", true)

	// Security defaults
	viper.SetDefault("security.password_min_length", 8)
	viper.SetDefault("security.password_require_upper", true)
	viper.SetDefault("security.password_require_lower", true)
	viper.SetDefault("security.password_require_digit", true)
	viper.SetDefault("security.password_require_symbol", false)
	viper.SetDefault("security.session_timeout", "24h")
	viper.SetDefault("security.max_login_attempts", 5)
	viper.SetDefault("security.lockout_duration", "15m")
	viper.SetDefault("security.cors_allowed_origins", []string{"*"})
	viper.SetDefault("security.rate_limit_enabled", true)
	viper.SetDefault("security.rate_limit_rps", 100)
}

func validateConfig(config *Config) error {
	if config.JWT.SecretKey == "" {
		return fmt.Errorf("JWT secret key is required")
	}

	if config.Database.Host == "" {
		return fmt.Errorf("database host is required")
	}

	if config.Database.User == "" {
		return fmt.Errorf("database user is required")
	}

	if config.Database.DBName == "" {
		return fmt.Errorf("database name is required")
	}

	if config.ImmuDB.Enabled && config.ImmuDB.Host == "" {
		return fmt.Errorf("ImmuDB host is required when ImmuDB is enabled")
	}

	if config.MinIO.Enabled && config.MinIO.Endpoint == "" {
		return fmt.Errorf("MinIO endpoint is required when MinIO is enabled")
	}

	return nil
}

// IsProduction returns true if running in production environment
func (c *ServerConfig) IsProduction() bool {
	return c.Environment == "production"
}

// IsDevelopment returns true if running in development environment
func (c *ServerConfig) IsDevelopment() bool {
	return c.Environment == "development"
}
