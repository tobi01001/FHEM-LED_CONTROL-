# FHEM-LED_CONTROL-

FHEM module to control LED_Stripe_Dynamic_web_conf with WebSocket support for real-time bidirectional communication.

## Features

### Core Functionality
- Control WS2812b LED stripes via ESP8266 devices
- Support for all LED_Stripe_Dynamic_web_conf effects and palettes
- HTTP REST API integration for reliable command execution
- Automatic parameter discovery and FHEM integration

### NEW: WebSocket Support
- **Real-time bidirectional communication** with LED stripe devices
- **Instant updates** when parameters change via web interface or knob control
- **Automatic reconnection** with configurable intervals
- **Graceful degradation** - falls back to HTTP if WebSocket unavailable
- **Connection health monitoring** with ping/pong mechanism

## Installation

1. Copy `98_LEDStripe2.pm` to your FHEM modules directory
2. Install optional WebSocket dependencies for enhanced functionality:
   ```bash
   # Debian/Ubuntu
   sudo apt-get install libprotocol-websocket-perl libio-socket-ssl-perl
   
   # Or via CPAN
   cpan Protocol::WebSocket::Client IO::Socket::INET
   ```
3. Restart FHEM
4. Define your LED devices

## Quick Start

### Basic HTTP-only Setup
```perl
define LED_Kitchen LEDStripe2 ip=192.168.1.100
```

### Enhanced Setup with WebSocket
```perl
define LED_Kitchen LEDStripe2 ip=192.168.1.100
attr LED_Kitchen useWebSocket 1
attr LED_Kitchen websocketReconnectInterval 30
```

## Documentation

- **[WebSocket Setup Guide](WEBSOCKET_SETUP.md)** - Detailed configuration and troubleshooting
- **Module Documentation** - Available in FHEM commandref after installation
- **LED Firmware** - https://github.com/tobi01001/LED_Stripe_Dynamic_web_conf

## Compatibility

### LED Firmware
- Works with https://github.com/tobi01001/LED_Stripe_Dynamic_web_conf
- WebSocket features require firmware with `/ws` endpoint support
- Backward compatible with older firmware versions

### FHEM Versions
- Compatible with FHEM 5.8 and later
- WebSocket support is optional and automatically detected

## Benefits of WebSocket Integration

| Feature | HTTP Only | HTTP + WebSocket |
|---------|-----------|------------------|
| Command execution | ✅ Reliable | ✅ Reliable |
| Status updates | ⏱️ Polling intervals | ⚡ Real-time |
| Web interface changes | ❌ Not reflected | ✅ Instant sync |
| Knob control changes | ❌ Not reflected | ✅ Instant sync |
| Network efficiency | 📈 Regular polling | 📉 Event-driven |
| Response time | ~2 minutes | ~1 second |

## Examples

See [WEBSOCKET_SETUP.md](WEBSOCKET_SETUP.md) for comprehensive configuration examples.

## Contributing

Contributions welcome! Please see the LED firmware repository for hardware/firmware contributions and this repository for FHEM module enhancements.
