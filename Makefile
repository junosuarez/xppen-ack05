PRODUCT_NAME = xppen-utility
DAEMON_NAME = ack05-daemon
CONFIG_APP_NAME = xppen-config-app

BIN_DIR = .build/debug
RELEASE_DIR = .build/release

PLIST_NAME = com.juno.ack05-daemon.plist
LAUNCH_AGENTS_DIR = $(HOME)/Library/LaunchAgents

.PHONY: all build run clean test install help run-daemon run-config install-daemon uninstall-daemon

all: build

help:
	@echo "Available targets:"
	@echo "  build           - Build the project (debug)"
	@echo "  run             - Run the exploratory utility (TUI)"
	@echo "  run-daemon      - Run the remapping daemon (foreground)"
	@echo "  run-config      - Run the SwiftUI config app"
	@echo "  install-daemon  - Install daemon as a background service (LaunchAgent)"
	@echo "  uninstall-daemon- Remove the background service"
	@echo "  clean           - Remove build artifacts"

build:
	swift build

build-release:
	swift build -c release

run: build
	./$(BIN_DIR)/$(PRODUCT_NAME)

run-daemon: build
	./$(BIN_DIR)/$(DAEMON_NAME)

run-config: build
	./$(BIN_DIR)/$(CONFIG_APP_NAME)

install-daemon: build-release
	@echo "Installing binary to /usr/local/bin..."
	mkdir -p /usr/local/bin
	cp $(RELEASE_DIR)/$(DAEMON_NAME) /usr/local/bin/$(DAEMON_NAME)
	@echo "Installing LaunchAgent..."
	mkdir -p $(LAUNCH_AGENTS_DIR)
	cp $(PLIST_NAME) $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@echo "Loading service..."
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@echo "Daemon installed and running!"

uninstall-daemon:
	@echo "Stopping and unloading LaunchAgent..."
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@echo "Removing binary..."
	rm -f /usr/local/bin/$(DAEMON_NAME)
	@echo "Daemon uninstalled."

clean:
	swift package clean
