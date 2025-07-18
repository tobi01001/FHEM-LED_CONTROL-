# WebSocket Setup Guide for FHEM LEDStripe2 Module

This guide explains how to set up and use the new WebSocket functionality in the LEDStripe2 FHEM module for real-time communication with LED_Stripe_Dynamic_web_conf devices.

## Requirements

### Software Prerequisites
- FHEM installation
- LED stripe device running LED_Stripe_Dynamic_web_conf firmware (https://github.com/tobi01001/LED_Stripe_Dynamic_web_conf)
- Perl modules (install if not available):
  ```bash
  # On Debian/Ubuntu:
  sudo apt-get install libprotocol-websocket-perl libio-socket-ssl-perl
  
  # Or via CPAN:
  cpan Protocol::WebSocket::Client IO::Socket::INET
  ```

### Hardware Prerequisites
- ESP8266-based LED controller (NodeMCU, Wemos D1 Mini, etc.)
- WS2812b LED stripe
- Network connectivity between FHEM and LED controller

## Configuration

### 1. Basic Device Setup
First, define your LED stripe device as usual:
```perl
define LED_Kitchen LEDStripe2 ip=192.168.1.100 port=80 interval=120
```

### 2. Enable WebSocket Support
Add the WebSocket attributes to enable real-time communication:
```perl
attr LED_Kitchen useWebSocket 1
attr LED_Kitchen websocketReconnectInterval 30
```

### 3. Optional Attributes
```perl
# Keep HTTP polling as backup (recommended)
attr LED_Kitchen interval 300

# Standard attributes still work
attr LED_Kitchen power_switch MyRelay_Kitchen
attr LED_Kitchen backwardCompatibility 0
```

## Features and Benefits

### Real-time Updates
- **Instant Response**: Changes made via the LED stripe's web interface or knob control are immediately reflected in FHEM
- **Bidirectional Sync**: FHEM commands are sent via HTTP, status updates come via WebSocket
- **Reduced Latency**: No more waiting for the next polling interval

### Connection Management
- **Automatic Reconnection**: Lost connections are automatically restored
- **Health Monitoring**: Built-in ping/pong mechanism ensures connection health
- **Graceful Degradation**: Falls back to HTTP-only if WebSocket modules unavailable

### Status Monitoring
Monitor the WebSocket connection status via the `_WEBSOCKET_STATE` reading:
- `connected` - WebSocket active and healthy
- `disconnected` - Connection closed, will attempt reconnection
- `not_available` - Required Perl modules not installed
- `error: <message>` - Connection error with details

## Example Configurations

### Basic Setup
```perl
define LED_LivingRoom LEDStripe2 ip=192.168.1.101
attr LED_LivingRoom useWebSocket 1
```

### Advanced Setup with Power Control
```perl
define LED_Bedroom LEDStripe2 ip=192.168.1.102 interval=180
attr LED_Bedroom useWebSocket 1
attr LED_Bedroom websocketReconnectInterval 60
attr LED_Bedroom power_switch Relay_Bedroom_LED
attr LED_Bedroom webCmd power:brightness:effect:colorPalette
```

### Multiple LED Stripes
```perl
# Kitchen under-cabinet lighting
define LED_Kitchen_Under LEDStripe2 ip=192.168.1.103
attr LED_Kitchen_Under useWebSocket 1
attr LED_Kitchen_Under room Kitchen

# Kitchen island lighting  
define LED_Kitchen_Island LEDStripe2 ip=192.168.1.104
attr LED_Kitchen_Island useWebSocket 1
attr LED_Kitchen_Island room Kitchen
```

## Troubleshooting

### WebSocket Not Connecting
1. Check if required Perl modules are installed:
   ```bash
   perl -MProtocol::WebSocket::Client -e "print 'OK'"
   ```

2. Verify LED stripe firmware supports WebSocket (check for `/ws` endpoint)

3. Check network connectivity:
   ```bash
   telnet 192.168.1.100 80
   ```

4. Monitor FHEM logs:
   ```perl
   attr global verbose 4
   ```

### Connection Keeps Dropping
1. Check network stability
2. Increase reconnect interval:
   ```perl
   attr LED_Device websocketReconnectInterval 60
   ```
3. Verify LED stripe device isn't overloaded

### Readings Not Updating
1. Check `_WEBSOCKET_STATE` reading
2. Verify the LED stripe is sending WebSocket messages
3. Enable debug logging:
   ```perl
   attr LED_Device verbose 5
   ```

## Migration from HTTP-Only

### Gradual Migration
You can enable WebSocket while keeping HTTP polling as backup:
```perl
# Keep existing HTTP polling but reduce frequency
attr LED_Device interval 300

# Enable WebSocket for real-time updates
attr LED_Device useWebSocket 1
```

### Full WebSocket Migration
For optimal performance, rely primarily on WebSocket:
```perl
# Reduce HTTP polling to minimum for command discovery only
attr LED_Device interval 600

# Enable WebSocket for all real-time communication
attr LED_Device useWebSocket 1
attr LED_Device websocketReconnectInterval 30
```

## Performance Considerations

### Network Traffic
- WebSocket connections use minimal bandwidth for status updates
- HTTP requests still used for sending commands (ensures reliability)
- Reduced overall network traffic compared to frequent HTTP polling

### FHEM Performance
- Real-time updates don't block FHEM's main thread
- Connection management runs asynchronously
- Minimal CPU overhead for established connections

## Compatibility

### LED Firmware Versions
- Requires LED_Stripe_Dynamic_web_conf firmware with WebSocket support
- Backward compatible with older firmware (will use HTTP-only)
- Check device at `http://device-ip/` for WebSocket support

### FHEM Versions
- Compatible with FHEM 5.8 and later
- Uses standard FHEM timer and reading mechanisms
- No FHEM core modifications required

## Support and Contributing

For issues, questions, or contributions:
- LED firmware: https://github.com/tobi01001/LED_Stripe_Dynamic_web_conf
- FHEM module: https://github.com/tobi01001/FHEM-LED_CONTROL-

Please include log snippets and configuration when reporting issues.