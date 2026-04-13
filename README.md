# XP-Pen ACK05-B macOS Utility Suite

A userspace driver and configuration suite for the XP-Pen ACK05-B Wireless Shortcut Remote on macOS. This project allows you to intercept the device's native keyboard shortcuts and remap them to custom shell commands or synthesized key chords.

## Features

- **Exclusive Interception**: Uses HID Seizure to block native device input (e.g., stopping K9 from typing "Space").
- **SwiftUI Config App**: Interactive geometric layout to click and remap keys visually.
- **Key Chords**: Support for multi-key sequences (e.g., `⌘K, ⌘S`).
- **Hot-Reloading**: Headless daemon instantly updates when you save your configuration.
- **No Sudo Required**: Runs entirely in userspace without special permissions.

## Components

1.  **XPPenCore**: Shared library containing the HID protocol logic and configuration management.
2.  **xppen-utility**: A TUI-based exploratory tool to view raw HID reports and verify device state.
3.  **ack05-daemon**: A headless background process that performs the actual remapping.
4.  **xppen-config-app**: A native SwiftUI application for managing your shortcuts.

## Getting Started

### Prerequisites
- macOS 13.0+
- Swift 6.0+

### Build
```bash
make build
```

### Usage

1.  **Configure Mappings**:
    Launch the SwiftUI app to set up your shortcuts.
    ```bash
    make run-config
    ```
    - Click a key on the layout.
    - Select "Key" or "Chord".
    - Click "Record" and press the desired shortcut on your keyboard.
    - Click **OK** to save and exit.

2.  **Run the Daemon**:
    Start the interceptor to enable your mappings globally.
    ```bash
    make run-daemon
    ```

3.  **Explore (Optional)**:
    Use the TUI utility to see raw reports from the device.
    ```bash
    make run
    ```

## Installation as a System Service

You can install the remapper as a persistent background service that starts automatically when you log in.

### Install
```bash
make install-daemon
```
*Note: macOS will likely prompt you to grant "Accessibility" or "Input Monitoring" permissions to `/usr/local/bin/ack05-daemon` the first time it tries to synthesize a keypress.*

### Uninstall
```bash
make uninstall-daemon
```

### Logs
When running as a service, output is logged to:
- `/tmp/ack05-daemon.stdout.log`
- `/tmp/ack05-daemon.stderr.log`

## Configuration
Mappings are stored in JSON format at:
`~/Library/Application Support/XPPenUtility/config.json`

## Protocol Details
For technical details on the reverse-engineered HID protocol, see [ACK05_PROTOCOL.md](./ACK05_PROTOCOL.md).

## License
MIT
