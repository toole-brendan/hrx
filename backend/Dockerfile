FROM golang:1.23-alpine AS builder

# Set necessary environment variables
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# Create app directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN go build -o /app/handreceipt ./cmd/server

# Create directory for PUB LOG data
RUN mkdir -p /app/internal/publog/data

# Use a small alpine image for the final stage
FROM alpine:latest

# Install CA certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/handreceipt .

# Copy the configuration files
COPY configs/config.yaml /app/configs/
COPY configs/config.azure.yaml /app/configs/

# Copy PUB LOG data directory from builder (including any data files)
COPY --from=builder --chown=appuser:appgroup /app/internal/publog/data /app/internal/publog/data

# Use the non-root user
USER appuser

# Expose the port
EXPOSE 8080

# Set environment variable to use Azure config when deployed to Azure
ENV HANDRECEIPT_CONFIG_NAME=config.azure

# Run the application
CMD ["./handreceipt"] 