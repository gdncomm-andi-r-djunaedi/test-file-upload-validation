# Quick Start Guide

File Upload Validation POC - Spring WebFlux CSV Upload with Streaming

## Prerequisites

- Java 17 or higher
- Maven 3.6 or higher
- curl (for testing)

## Quick Start

### 1. Start the Application

```bash
./start.sh
```

The application will start on port 8080 and save its PID to `.app.pid`.

### 2. Test the Application

#### Test with Medium File (4.3 MB)
```bash
./test-medium.sh
```

#### Test with Large File (86 MB)
```bash
./test-large.sh
```

#### Test Validation with Invalid File
```bash
./test-invalid.sh
```

### 3. Stop the Application

```bash
./stop.sh
```

## API Endpoint

**Endpoint:** `POST http://localhost:8080/upload`

**Request:**
- Content-Type: `multipart/form-data`
- Parameter: `file` (the CSV file to upload)

**Response:**
- **200 OK**: Returns the CSV content as streaming text
- **400 Bad Request**: Returns error message if validation fails

**Validation:**
- Validates the first 100 bytes of the uploaded file
- Checks for valid CSV characters (letters, numbers, delimiters, quotes, punctuation)
- Rejects binary data and unexpected control characters

## Test Files

| File | Size | Description |
|------|------|-------------|
| `test-small.csv` | 25 bytes | Minimal CSV with header and 1 row |
| `test-valid.csv` | 4.3 MB | Medium CSV with 50,000 rows |
| `test-large.csv` | 86 MB | Large CSV with 500,000 rows |
| `test-invalid.bin` | 10 KB | Binary file (should fail validation) |

## Manual Testing

```bash
# Test with valid CSV file
curl -X POST http://localhost:8080/upload -F "file=@test-valid.csv"

# Test with invalid binary file (should return 400)
curl -X POST http://localhost:8080/upload -F "file=@test-invalid.bin"

# Test with custom file
curl -X POST http://localhost:8080/upload -F "file=@your-file.csv"
```

## Memory Efficiency

The application uses reactive streaming (Spring WebFlux) to handle large files efficiently:

- **Validates only first 100 bytes** - No need to buffer entire file for validation
- **Streams response** - Processes file in chunks, not loaded entirely into memory
- **Tested with 86MB files** - No OutOfMemoryError with default heap settings

## Build and Run Manually

If you prefer to run manually without scripts:

```bash
# Build the project
mvn clean package

# Run the application
mvn spring-boot:run

# Or run the JAR
java -jar target/file-upload-validation-1.0.0.jar
```

## Troubleshooting

**Port 8080 already in use:**
```bash
# Find and kill process using port 8080
lsof -ti:8080 | xargs kill -9
```

**Application won't stop:**
```bash
# Force kill all Java processes
pkill -9 java
```

**Scripts not executable:**
```bash
chmod +x start.sh stop.sh test-medium.sh test-large.sh test-invalid.sh
```

## Project Structure

```
file-upload-validation/
├── QUICKSTART.md                 # This file
├── start.sh                      # Start application script
├── stop.sh                       # Stop application script
├── test-medium.sh                # Test medium file (4.3MB)
├── test-large.sh                 # Test large file (86MB)
├── test-invalid.sh               # Test invalid file
├── pom.xml                       # Maven configuration
├── src/main/java/...             # Application source code
└── test-*.csv, test-*.bin        # Test files
```
