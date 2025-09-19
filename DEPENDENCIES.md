# Dependencies Guide

## Overview

This document lists all dependencies required for the Day Planner app, including system requirements, external tools, Swift packages, and optional integrations.

## System Requirements

### macOS Platform
- **Minimum**: macOS 12.0 (Monterey)
- **Recommended**: macOS 13.0 (Ventura) or later
- **Architecture**: Universal app supporting both Intel and Apple Silicon

### Hardware Requirements
- **Memory**: 
  - Minimum: 16GB RAM (for AI model)
  - Recommended: 32GB RAM (for optimal AI performance)
- **Storage**: 
  - App: ~100MB
  - AI Model: ~12GB (oos20b model)
  - User Data: Variable (typically <1GB)
- **Processor**:
  - Apple Silicon (M1/M2/M3): Recommended for optimal AI performance
  - Intel x86-64: Supported but slower AI processing

## Development Tools

### Required Development Environment
```yaml
Development Tools:
  - Xcode: "14.0+"
  - Swift: "5.9+"
  - macOS SDK: "12.0+"
  - Command Line Tools: Latest

Package Managers:
  - Swift Package Manager: Built into Xcode
  - Homebrew: For development utilities
```

### Development Dependencies
```bash
# Install via Homebrew
brew install swiftlint
brew install swiftformat  
brew install xcbeautify

# Optional but recommended
brew install fastlane      # For CI/CD
brew install periphery     # For dead code analysis
```

## External Tools

### 1. LM Studio (AI Runtime)
```yaml
LM Studio:
  version: "0.2.0+"
  download: "https://lmstudio.ai"
  purpose: "Local AI model hosting"
  required: true
  
Models:
  development: "microsoft/DialoGPT-medium (1.4GB)"
  production: "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO (12GB)"
  alternative: "microsoft/DialoGPT-large (6GB)"
```

Installation:
```bash
# Download and install LM Studio from https://lmstudio.ai
# Launch LM Studio and download required model
# Start local server on http://localhost:1234
```

### 2. Database Tools (Optional)
```yaml
SQLite Browser:
  purpose: "Database inspection during development"
  install: "brew install --cask db-browser-for-sqlite"
  
Proxyman:
  purpose: "Network request monitoring"
  install: "brew install --cask proxyman"
```

## Swift Package Dependencies

### Core Dependencies

#### 1. SQLite.swift
```swift
// Package.swift
.package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
```

**Purpose**: Database operations  
**License**: MIT  
**Alternatives**: Core Data, Realm

#### 2. CryptoKit (System Framework)
```swift
import CryptoKit
```

**Purpose**: Encryption and security  
**Type**: Apple System Framework  
**Features**: AES encryption, key management

### Optional Dependencies

#### 3. SwiftUI Navigation (Optional)
```swift
.package(url: "https://github.com/pointfreeco/swiftui-navigation.git", from: "0.8.0")
```

**Purpose**: Advanced navigation patterns  
**License**: MIT  
**Use Case**: Complex navigation flows

#### 4. Composable Architecture (Optional)
```swift
.package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.2.0")
```

**Purpose**: State management architecture  
**License**: MIT  
**Alternative**: Custom MVVM implementation

### Development & Testing Dependencies

#### 5. ViewInspector (Testing)
```swift
.package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0")
```

**Purpose**: SwiftUI view testing  
**License**: MIT  
**Use Case**: Unit testing SwiftUI components

#### 6. SnapshotTesting (Testing)
```swift
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.12.0")
```

**Purpose**: UI snapshot testing  
**License**: MIT  
**Use Case**: Visual regression testing

## System Frameworks

### Required Frameworks
```swift
// Calendar integration
import EventKit

// Speech recognition and synthesis  
import Speech
import AVFoundation

// Security and encryption
import CryptoKit
import LocalAuthentication

// Networking (local only)
import Network
import Foundation

// UI and user interface
import SwiftUI
import AppKit

// System integration
import Combine
import os.log
```

### Framework Usage Matrix
| Framework | Purpose | Permission Required | Optional |
|-----------|---------|-------------------|----------|
| EventKit | Calendar access | Calendar | No |
| Speech | Voice recognition | Microphone + Speech | Yes |
| AVFoundation | Text-to-speech | None | Yes |
| CryptoKit | Data encryption | None | No |
| LocalAuthentication | Biometric auth | None | Yes |
| Network | Local AI connection | None | No |

## Configuration Files

### Package.swift Example
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DayPlanner",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.5.0"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.12.0"),
    ],
    targets: [
        .target(
            name: "DayPlanner",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "DayPlannerTests",
            dependencies: [
                "DayPlanner",
                "ViewInspector",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
```

### Xcode Project Configuration
```xml
<!-- Info.plist -->
<key>LSMinimumSystemVersion</key>
<string>12.0</string>

<key>NSCalendarsUsageDescription</key>
<string>Day Planner needs access to your calendar to manage and sync events.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Voice input allows hands-free interaction with the AI assistant.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for voice input functionality.</string>

<!-- Sandboxing entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.personal-information.calendars</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

## Version Compatibility

### Swift Compatibility
```yaml
Swift Versions:
  minimum: "5.9"
  tested: ["5.9", "5.10"]
  
Language Features Used:
  - async/await
  - Actors
  - SwiftUI 4.0+
  - Combine
  - Result builders
```

### macOS Version Support
```yaml
macOS Support:
  minimum: "12.0"  # Monterey
  recommended: "13.0"  # Ventura
  latest: "14.0"  # Sonoma
  
Features by Version:
  macOS 12: "Base functionality"
  macOS 13: "Enhanced performance"
  macOS 14: "Latest SwiftUI features"
```

## Installation Scripts

### Setup Script
```bash
#!/bin/bash
# Scripts/setup.sh

set -e

echo "🚀 Setting up Day Planner development environment..."

# Check system requirements
echo "Checking system requirements..."
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

# Check macOS version
OS_VERSION=$(sw_vers -productVersion)
if [[ "$(printf '%s\n' "12.0" "$OS_VERSION" | sort -V | head -n1)" != "12.0" ]]; then
    echo "❌ macOS 12.0 or later is required. Current version: $OS_VERSION"
    exit 1
fi

# Install development tools
echo "Installing development dependencies..."
if command -v brew &> /dev/null; then
    brew install swiftlint swiftformat
else
    echo "⚠️ Homebrew not found. Please install manually: https://brew.sh"
fi

# Check LM Studio
echo "Checking LM Studio installation..."
if [ ! -d "/Applications/LMStudio.app" ]; then
    echo "⚠️ LM Studio not found. Download from: https://lmstudio.ai"
    echo "   This is required for AI functionality."
fi

# Verify Swift Package Manager
echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Install LM Studio from https://lmstudio.ai"
echo "2. Download the required AI model (see AI_INTEGRATION.md)"
echo "3. Start LM Studio server"
echo "4. Build and run the project"
```

### Dependency Check Script
```bash
#!/bin/bash
# Scripts/check-dependencies.sh

echo "🔍 Checking dependencies..."

# Check LM Studio
if curl -s http://localhost:1234/v1/models > /dev/null 2>&1; then
    echo "✅ LM Studio: Running"
else
    echo "❌ LM Studio: Not running or not accessible"
fi

# Check disk space
AVAILABLE_SPACE=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -gt 20 ]; then
    echo "✅ Disk space: ${AVAILABLE_SPACE}GB available"
else
    echo "⚠️ Disk space: Only ${AVAILABLE_SPACE}GB available (20GB+ recommended)"
fi

# Check memory
MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
if [ "$MEMORY_GB" -ge 16 ]; then
    echo "✅ Memory: ${MEMORY_GB}GB (sufficient)"
else
    echo "❌ Memory: Only ${MEMORY_GB}GB (16GB minimum required)"
fi

echo "✅ Dependency check complete"
```

## Troubleshooting

### Common Dependency Issues

#### 1. LM Studio Connection
```bash
# Check if LM Studio is running
curl http://localhost:1234/v1/models

# Common solutions:
# - Ensure LM Studio app is open
# - Check that a model is loaded
# - Verify server is started (green dot in LM Studio)
# - Check firewall settings for port 1234
```

#### 2. SQLite Issues
```swift
// Common SQLite errors and solutions:

// Error: "database is locked"
// Solution: Ensure only one connection at a time
let db = try Connection(dbPath, readonly: false)

// Error: "no such table"
// Solution: Run migrations
try createTables()

// Error: "disk I/O error"  
// Solution: Check file permissions and disk space
```

#### 3. Calendar Permission Issues
```swift
// Check calendar authorization status
let status = EKEventStore.authorizationStatus(for: .event)
switch status {
case .notDetermined:
    // Request permission
    let granted = try await eventStore.requestAccess(to: .event)
case .denied:
    // Guide user to System Preferences > Security & Privacy > Calendars
    showCalendarPermissionAlert()
case .authorized:
    // Ready to use
    break
}
```

### Memory and Performance

#### Memory Management
```yaml
Memory Guidelines:
  - Minimum system RAM: 16GB
  - AI model memory usage: ~8GB
  - App memory usage: ~200MB
  - Available for system: ~7.8GB
  
Performance Expectations:
  Apple Silicon:
    - First AI token: <800ms
    - Full response: <3.5s
    - UI responsiveness: <100ms
    
  Intel Macs:
    - First AI token: <1.5s  
    - Full response: <8s
    - UI responsiveness: <100ms
```

## License Compatibility

### Dependency Licenses
| Dependency | License | Commercial Use | Notes |
|------------|---------|----------------|-------|
| SQLite.swift | MIT | ✅ Yes | Compatible |
| Apple Frameworks | Apple | ✅ Yes | System frameworks |
| LM Studio | Proprietary | ✅ Yes | Free for personal use |
| Swift Crypto | Apache 2.0 | ✅ Yes | Compatible |

### License Compliance
- All dependencies are compatible with commercial distribution
- No GPL or copyleft licenses that would affect proprietary code
- Attribution requirements satisfied in app credits

This dependencies guide ensures all required components are properly documented and can be reliably installed and maintained throughout the development lifecycle.
