package com.example.fileupload;

import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.codec.multipart.FilePart;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;

@RestController
public class FileUploadController {

    private static final int VALIDATION_BYTES = 100;

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE, produces = MediaType.TEXT_PLAIN_VALUE)
    public Mono<ResponseEntity<Flux<String>>> uploadCsv(@RequestPart("file") FilePart filePart) {
        // Create a shared Flux that can be subscribed to multiple times
        Flux<DataBuffer> sharedBufferFlux = filePart.content().share();

        // Get first buffer for validation
        return sharedBufferFlux
            .next()  // Take only first DataBuffer
            .flatMap(firstBuffer -> {
                try {
                    // Read first 100 bytes for validation
                    int bufferSize = firstBuffer.readableByteCount();
                    int bytesToValidate = Math.min(VALIDATION_BYTES, bufferSize);

                    byte[] validationBytes = new byte[bytesToValidate];
                    firstBuffer.read(validationBytes);

                    // Reset read position so buffer can be re-read for response
                    firstBuffer.readPosition(0);

                    // Validate using existing isValidCsv() method
                    String preview = new String(validationBytes, StandardCharsets.UTF_8);

                    if (!isValidCsv(preview)) {
                        DataBufferUtils.release(firstBuffer);
                        return Mono.just(ResponseEntity
                            .status(HttpStatus.BAD_REQUEST)
                            .body(Flux.just("Invalid CSV format: first " + bytesToValidate + " bytes contain invalid characters")));
                    }

                    // If valid, create streaming response
                    // Prepend the first buffer back, then continue with rest of stream
                    Flux<DataBuffer> allBuffers = Flux.concat(
                        Flux.just(firstBuffer),
                        sharedBufferFlux
                    );

                    // Convert DataBuffer stream to String stream
                    Flux<String> csvStream = allBuffers
                        .map(buffer -> {
                            byte[] bytes = new byte[buffer.readableByteCount()];
                            buffer.read(bytes);
                            DataBufferUtils.release(buffer);
                            return new String(bytes, StandardCharsets.UTF_8);
                        });

                    return Mono.just(ResponseEntity.ok(csvStream));

                } catch (Exception e) {
                    DataBufferUtils.release(firstBuffer);
                    return Mono.just(ResponseEntity
                        .status(HttpStatus.BAD_REQUEST)
                        .body(Flux.just("Error processing file: " + e.getMessage())));
                }
            })
            .defaultIfEmpty(ResponseEntity.badRequest().body(Flux.just("Empty file")));
    }

    private boolean isValidCsv(String content) {
        for (char c : content.toCharArray()) {
            // Allow: letters, numbers, common CSV delimiters, quotes, whitespace, basic punctuation
            if (Character.isLetterOrDigit(c) ||
                c == ',' || c == ';' || c == '\t' ||
                c == '"' || c == '\'' ||
                c == ' ' || c == '\n' || c == '\r' ||
                c == '.' || c == '-' || c == '_' || c == '@' || c == '#' ||
                c == '(' || c == ')' || c == '[' || c == ']' ||
                c == '/' || c == '\\' || c == ':' || c == '+') {
                continue;
            }
            // Reject unexpected control characters or binary data
            if (Character.isISOControl(c) && c != '\n' && c != '\r' && c != '\t') {
                return false;
            }
            // Allow other printable characters
            if (!Character.isWhitespace(c) && c < 32 || c > 126) {
                return false;
            }
        }
        return true;
    }
}
