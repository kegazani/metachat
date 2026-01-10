# iOS App Setup Guide

## Backend Connection Configuration

The iOS app needs to connect to the GraphQL backend server. The connection URL is configurable based on your testing environment.

### For iOS Simulator

The simulator can access `localhost` directly. The default configuration should work:
- Default URL: `http://localhost:8080/graphql`

### For Physical iOS Device

Physical devices cannot access `localhost` (it refers to the device itself). You need to use your Mac's IP address:

1. **Find your Mac's IP address:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Or check System Preferences → Network

2. **Set environment variables in Xcode:**
   - Open your project in Xcode
   - Select your scheme → Edit Scheme
   - Go to "Run" → "Arguments"
   - Under "Environment Variables", add:
     - `GRAPHQL_HOST` = `YOUR_MAC_IP_ADDRESS` (e.g., `192.168.1.100`)
     - `GRAPHQL_PORT` = `8080` (optional, defaults to 8080)

### Alternative: Hardcode for Development

If you prefer, you can temporarily hardcode the IP in `Config/AppConfig.swift`:

```swift
static var graphQLURL: URL {
    let host = "192.168.1.100"  // Replace with your Mac's IP
    let port = "8080"
    let urlString = "http://\(host):\(port)/graphql"
    return URL(string: urlString)!
}
```

### Verify Backend is Running

Make sure the backend server is running:

```bash
# Check if backend is running
lsof -i :8080

# Or start it with Docker Compose
docker-compose up app
```

### Troubleshooting

- **Error -1004 (Could not connect to the server):**
  - Verify backend is running: `curl http://localhost:8080/graphql`
  - For physical devices, ensure you're using your Mac's IP, not `localhost`
  - Check that your Mac and iOS device are on the same Wi-Fi network
  - Verify firewall isn't blocking port 8080

- **Connection refused:**
  - Backend might not be running
  - Port 8080 might be in use by another service
  - Check Docker containers: `docker ps`

- **Error -1001 (The request timed out):**
  - Verify backend is accessible: `curl http://169.254.130.87:8080/graphql`
  - Check network connectivity between device and server
  - Ensure backend server is running and responding
  - Verify firewall settings allow connections on port 8080
  - Default timeout is set to 30 seconds - if backend is slow, consider increasing timeout in `ApolloClientService.swift`

