PRODUCT_NAME = xppen-utility
BIN_PATH = .build/debug/$(PRODUCT_NAME)

.PHONY: all build run clean test install help

all: build

help:
	@echo "Available targets:"
	@echo "  build   - Build the project (default)"
	@echo "  run     - Build and run the utility"
	@echo "  test    - Run Swift tests"
	@echo "  clean   - Remove build artifacts"
	@echo "  install - Build and copy binary to /usr/local/bin"

build:
	swift build

run:
	swift run $(PRODUCT_NAME)

test:
	swift test

clean:
	swift package clean

install: build
	mkdir -p /usr/local/bin
	cp $(BIN_PATH) /usr/local/bin/$(PRODUCT_NAME)
