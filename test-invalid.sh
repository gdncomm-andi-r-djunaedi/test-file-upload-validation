#!/bin/bash

curl -X POST http://localhost:8080/upload -F "file=@test-invalid.bin"
