# Grid

<div align="center">

**A Powerful iOS Network Discovery and Reconnaissance Tool**

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

</div>

## Overview

Grid is a sophisticated network scanning application for iOS that empowers users to discover, identify, and analyze devices on their local network. Built with SwiftUI and leveraging Apple's Network framework, Grid provides enterprise-grade network reconnaissance capabilities in an elegant, user-friendly interface.

Whether you're a network administrator managing infrastructure, a security professional conducting assessments, or a curious enthusiast exploring your home network, Grid delivers comprehensive insights into your network topology with intuitive visualizations and detailed device information.

## Key Features

### 🔍 Intelligent Network Discovery
- **Comprehensive IP Range Scanning**: Rapidly scans configurable IP ranges (default: 192.168.1.1-254) with efficient concurrent processing
- **Smart Host Detection**: Automatically identifies active devices by probing multiple common ports (80, 443, 22, 3389)
- **Parallel Processing**: Utilizes concurrent task groups with configurable concurrency limits (64 simultaneous connections) for optimal performance

### 🔌 Advanced Port Analysis
- **Multi-Port Scanning**: Examines 12 commonly used ports including FTP (21), SSH (22), DNS (53), HTTP (80/8080), HTTPS (443/8443), SMB (445), and more
- **Service Identification**: Automatically maps open ports to their corresponding services (e.g., SSH, HTTP, RDP, IPP)
- **Timeout Configuration**: Customizable connection timeouts (default: 500ms) for efficient scanning

### 🏷️ Automatic Device Classification
Grid employs intelligent heuristics to classify discovered devices:
- **Network Infrastructure**: Routers and gateways (identified by .1 addresses with web interfaces)
- **Printers**: Detected via IPP (631) and JetDirect (9100) ports
- **Servers/NAS**: Identified by combinations of SSH, SMB, and web service ports
- **Windows Hosts**: Recognized through RDP (3389) availability
- **Unix-like Systems**: Detected via SSH (22) service
- **Web Appliances**: Devices running HTTP/HTTPS services
- **Unknown Devices**: Fallback category for unclassified hosts

### 🌐 Reverse DNS Resolution
- **Hostname Discovery**: Automatically performs reverse DNS lookups for all discovered hosts
- **Asynchronous Processing**: Non-blocking DNS resolution that updates results in real-time
- **Native Implementation**: Uses POSIX `getnameinfo` for reliable hostname resolution

### 📊 Rich User Interface
- **Home Dashboard**: Clean, minimal entry point with animated network-themed background
- **Real-time Scan Progress**: Visual progress indicators with detailed scanning statistics
- **Advanced Filtering**: Search hosts by IP address, hostname, device name, or type
- **Multiple Sort Options**: Organize results by IP address, hostname, or port count
- **Detailed Host View**: Comprehensive information panel for each discovered device
- **Swipe Actions**: Quick refresh functionality via swipe gestures
- **Context Menus**: Easy copy operations for IP addresses and hostnames

### 🎨 Modern Design Elements
- **Dark Theme**: Professional dark mode interface with custom network grid background
- **Animated Gradients**: Dynamic visual effects with animated grid patterns
- **SF Symbols Integration**: Native iOS icons for device type visualization
- **Material Design**: Utilizes iOS blur effects and material design principles

### 🔒 Privacy & Permissions
- **Location Services Integration**: Optional location awareness through CoreLocation
- **Network Permission Handling**: Proper handling of iOS network access requirements
- **Local Network Privacy**: Operates within iOS local network privacy guidelines

## Technical Architecture

### Core Components

#### NetworkScanner
The heart of Grid's scanning engine, implementing:
- **Async/Await Concurrency**: Modern Swift concurrency for efficient parallel operations
- **Task Group Management**: Coordinated concurrent scanning with automatic task distribution
- **AsyncSemaphore**: Custom semaphore implementation for concurrency control
- **State Management**: Observable object pattern for reactive UI updates
- **TCP Connection Probing**: Low-level Network framework integration for port testing

#### Host Model
Data structure representing discovered network devices:
- Unique identification via UUID
- IP address and hostname storage
- Open ports collection
- Device type classification
- User-customizable labels and notes
- Online/offline status tracking

#### UI Components
- **ContentView**: Main navigation and home screen
- **ScanView**: Primary scanning interface with filtering and sorting
- **HostDetailView**: Detailed device information and port scanning
- **NetworkBackground**: Custom animated background with grid patterns

### Technology Stack

| Category | Technology |
|----------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI 4.0+ |
| Networking | Apple Network Framework |
| Concurrency | Swift Structured Concurrency (async/await) |
| Architecture | MVVM with ObservableObject |
| Location Services | CoreLocation, MapKit |
| Design Pattern | Reactive Programming with Combine |

### Performance Characteristics

- **Scanning Speed**: ~254 hosts in 30-60 seconds (network dependent)
- **Concurrency**: Up to 64 simultaneous connections
- **Memory Footprint**: Lightweight with minimal resource consumption
- **Connection Timeout**: 500ms per port probe (configurable)
- **Port Scan Coverage**: 12 common ports per detailed scan

## Requirements

- **iOS**: 15.0 or later
- **Xcode**: 14.0 or later (for building from source)
- **Device**: iPhone or iPad with local network access
- **Network**: Active Wi-Fi or Ethernet connection to a local network

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/brendantr/Grid.git
cd Grid
```

2. Open the project in Xcode:
```bash
open Grid.xcodeproj
```

3. Select your target device or simulator

4. Build and run the project (⌘R)

### Configuration

The default scan range is `192.168.1.1-254`. To modify:
- Edit `NetworkScanner.swift`
- Update the `scanDemoRange()` method
- Customize the IP range, ports, and timeout values

## Usage

1. **Launch the App**: Open Grid to see the home screen
2. **Start Scanning**: Tap "Scan Network" to begin discovery
3. **Monitor Progress**: Watch the real-time progress indicator as devices are found
4. **View Results**: Browse discovered devices with automatic classification
5. **Detailed Analysis**: Tap any host to view comprehensive details and scan ports
6. **Organize Results**: Use filters and sort options to organize your findings
7. **Refresh Hosts**: Swipe left on any host to refresh its information

## Use Cases

- **Network Administration**: Quickly inventory devices on managed networks
- **Security Auditing**: Identify unauthorized devices or open services
- **Troubleshooting**: Diagnose network connectivity and service availability issues
- **IoT Management**: Discover and track smart home devices
- **Documentation**: Map network topology for documentation purposes
- **Education**: Learn about network protocols and device discovery techniques

## Privacy & Security

Grid operates entirely within your local network and does not:
- Send data to external servers
- Store scanning results persistently
- Require internet connectivity
- Access data beyond network metadata (IP, ports, hostnames)

All scanning operations are performed locally on your device and results are temporary.

## Acknowledgments

Built with modern Swift and SwiftUI best practices, Grid demonstrates:
- Swift structured concurrency patterns
- Efficient network programming with Apple's Network framework
- Professional SwiftUI interface design
- MVVM architectural patterns

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright © 2026 brendantr

---

<div align="center">
Made with ❤️ for the iOS development community
</div>
