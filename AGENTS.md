# AI Agent Guide for File Upload Validation Project

This document provides guidance for AI agents and assistants working on this Spring WebFlux CSV file upload validation project.

## Project Overview

**Purpose:** Proof-of-concept for validating and streaming CSV file uploads using Spring Boot WebFlux with memory-efficient reactive streaming.

**Key Features:**
- Validates first 100 bytes of uploaded CSV files
- Streams entire file back without loading into memory
- Handles large files (100MB+) without OutOfMemoryError
- Returns HTTP 400 for invalid files, HTTP 200 with streamed content for valid files

## Architecture

### Technology Stack
- **Framework:** Spring Boot 3.2.1 with WebFlux (reactive)
- **Language:** Java 17
- **Build Tool:** Maven
- **Server:** Netty (embedded via WebFlux)
- **Port:** 8080

### Project Structure
```
file-upload-validation/
├── src/main/java/com/example/fileupload/
│   ├── FileUploadApplication.java      # Main Spring Boot entry point
│   └── FileUploadController.java       # Single REST controller with /upload endpoint
├── src/main/resources/
│   └── application.yml                 # Configuration (port, max file size)
├── pom.xml                             # Maven dependencies
├── QUICKSTART.md                       # User quick start guide
├── AGENTS.md                           # This file - AI agent guide
├── start.sh                            # Application startup script
├── stop.sh                             # Application shutdown script
├── test-medium.sh                      # Test with 4.3MB file
├── test-large.sh                       # Test with 86MB file
├── test-invalid.sh                     # Test validation with binary file
└── test-*.csv, test-*.bin              # Test data files
```

## Core Implementation

### FileUploadController.java

**Endpoint:** `POST /upload`
- Consumes: `multipart/form-data`
- Produces: `text/plain`
- Parameter: `file` (FilePart)

**Key Implementation Pattern:**
```java
public Mono<ResponseEntity<Flux<String>>> uploadCsv(@RequestPart("file") FilePart filePart)
```

**Reactive Streaming Pattern:**
1. Use `filePart.content().share()` to create shared Flux
2. Take first buffer with `.next()`
3. Read first 100 bytes for validation
4. Reset buffer position with `readPosition(0)`
5. If valid: concat first buffer + remaining stream
6. Stream response as `Flux<String>`
7. Release buffers with `DataBufferUtils.release()`

**Critical:** Never use `DataBufferUtils.join()` on the entire stream - this loads the whole file into memory!

### Validation Logic

**Method:** `isValidCsv(String content)`
- Validates character-by-character
- Allows: alphanumeric, CSV delimiters (`,`, `;`, `\t`), quotes, spaces, newlines, basic punctuation
- Rejects: binary data, unexpected control characters (except `\n`, `\r`, `\t`)
- Rejects: non-printable ASCII (< 32 or > 126)

**Important:** Only validates first 100 bytes, not entire file.

## Development Guidelines

### When Making Changes

**DO:**
- Keep the implementation minimal (POC purpose)
- Maintain reactive streaming patterns
- Release DataBuffers after use
- Use `Flux<DataBuffer>.share()` for multiple subscriptions
- Reset buffer positions after reading for validation
- Test with large files (86MB+) to verify no OOM errors

**DON'T:**
- Use `DataBufferUtils.join()` on the entire stream
- Create byte arrays of the full file size
- Add unnecessary features or abstractions
- Break the streaming pattern
- Load entire files into memory

### Testing Requirements

**Test Files:**
- `test-small.csv` (25 bytes) - Minimal valid CSV
- `test-valid.csv` (4.3 MB) - Medium CSV with 50K rows
- `test-large.csv` (86 MB) - Large CSV with 500K rows
- `test-invalid.bin` (10 KB) - Binary file (should fail validation)

**Test Scripts:**
- `./start.sh` - Start application
- `./test-medium.sh` - Test with 4.3MB file
- `./test-large.sh` - Test with 86MB file
- `./test-invalid.sh` - Test validation (expect HTTP 400)
- `./stop.sh` - Stop application

**Success Criteria:**
- Valid CSV files return HTTP 200 with streamed content
- Invalid files return HTTP 400 with error message
- Large files (86MB+) process without OutOfMemoryError
- Memory usage stays low (not growing to file size)
- Response streaming starts immediately (before full upload)

### Build and Run

```bash
# Build
mvn clean package

# Run
mvn spring-boot:run

# Or use scripts
./start.sh
./stop.sh
```

## Common Modifications

### Adding New Validation Rules

**Location:** `FileUploadController.isValidCsv()`

1. Update character validation logic
2. Keep validation on first 100 bytes only
3. Test with both valid and invalid files

### Changing Validation Byte Count

**Location:** `FileUploadController.VALIDATION_BYTES` constant

1. Change the constant value
2. Consider impact on very small files
3. Test edge cases (files smaller than validation size)

### Adjusting Max File Size

**Location:** `src/main/resources/application.yml`

```yaml
spring:
  codec:
    max-in-memory-size: 10MB  # Adjust this
```

**Note:** This is per-buffer size, not total file size. Streaming allows files much larger than this limit.

## Memory Efficiency

### Why Streaming Matters

**Problem:** Loading entire file into memory
- 100MB file → 100MB RAM usage
- Multiple concurrent uploads → OOM errors
- Not scalable

**Solution:** Reactive streaming
- Process in chunks (buffers)
- Only first 100 bytes loaded for validation
- Rest of file streamed directly to response
- Memory usage stays constant regardless of file size

### Buffer Management

**Critical Pattern:**
```java
// Good: Release after use
DataBufferUtils.release(buffer);

// Bad: Memory leak
// (not releasing buffer)

// Good: Share for multiple subscriptions
Flux<DataBuffer> shared = flux.share();

// Bad: Multiple subscriptions to non-shared flux
// (duplicates data in memory)
```

## Troubleshooting

### OutOfMemoryError
- Check for `DataBufferUtils.join()` usage
- Verify buffers are released
- Ensure streaming pattern is maintained

### Files Not Uploading
- Check port 8080 availability
- Verify file size under max limit
- Test with curl directly

### Validation Always Fails
- Check first 100 bytes of file
- Verify character validation logic
- Test with known-good CSV

### Application Won't Stop
- Use `./stop.sh` (handles PID file + fallback)
- Manual: `pkill -f "mvn spring-boot:run"`
- Force: `lsof -ti:8080 | xargs kill -9`

## API Documentation

### POST /upload

**Request:**
```bash
curl -X POST http://localhost:8080/upload -F "file=@yourfile.csv"
```

**Response (Success):**
```
HTTP/1.1 200 OK
Content-Type: text/plain

id,name,email
1,User1,user1@example.com
2,User2,user2@example.com
...
```

**Response (Validation Failed):**
```
HTTP/1.1 400 Bad Request
Content-Type: text/plain

Invalid CSV format: first 100 bytes contain invalid characters
```

## Version Control

**.gitignore includes:**
- `.app.pid` (process ID file)
- `.claude/` (AI assistant config)
- `target/` (Maven build output)
- IDE files (.idea, .vscode, *.iml)
- OS files (.DS_Store, Thumbs.db)

**What to commit:**
- Source code (`src/`)
- Build config (`pom.xml`)
- Scripts (`*.sh`)
- Documentation (`*.md`)
- Test data files (`test-*.csv`, `test-*.bin`)

**What NOT to commit:**
- Build artifacts (`target/`)
- PID files (`.app.pid`)
- IDE config (`.idea/`, `.vscode/`)
- Temporary files

## Performance Characteristics

**Tested Configuration:**
- File Size: 86 MB (500,000 rows)
- Heap Size: Default JVM settings
- Upload Time: ~4 seconds
- Memory Usage: Constant (not growing to file size)
- Result: ✅ Success (no OOM, full file streamed)

**Limits:**
- Max buffer size: 10MB (configurable in application.yml)
- Total file size: Theoretically unlimited (streaming)
- Validation size: First 100 bytes only
- Concurrent uploads: Limited by available threads/connections

## Contributing Guidelines for AI Agents

1. **Read before modifying:** Understand the reactive streaming pattern
2. **Test with large files:** Always test with `test-large.csv` after changes
3. **Maintain simplicity:** This is a POC - keep it minimal
4. **Verify memory efficiency:** Ensure changes don't load full files into memory
5. **Update documentation:** Keep this file and QUICKSTART.md in sync
6. **Follow existing patterns:** Match the code style and reactive patterns
7. **Test all scenarios:** Valid CSV, invalid binary, large files, edge cases

## References

- [Spring WebFlux Documentation](https://docs.spring.io/spring-framework/reference/web/webflux.html)
- [Project Reactor Documentation](https://projectreactor.io/docs/core/release/reference/)
- [Reactive Streams Specification](https://www.reactive-streams.org/)

---

**Last Updated:** December 2025
**Project Status:** POC - Minimal implementation complete
**Maintainer:** File upload validation team
