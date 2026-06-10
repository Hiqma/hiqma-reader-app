import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

class DiscoveredHub {
  final String name;
  final String url;
  final String hubId;
  final int responseTime;

  DiscoveredHub({
    required this.name,
    required this.url,
    required this.hubId,
    required this.responseTime,
  });

  @override
  String toString() => '$name ($hubId) - $url';
}

class HubDiscoveryService extends ChangeNotifier {
  static const String _defaultHubUrl = 'https://edgehub.hiqma.org';
  static const int _hubPort = 3002;
  static const int _timeoutSeconds = 2;
  static const String _discoveryEndpoint = '/api/hub/info';

  /// Discovers edge hubs on the local network
  Future<List<DiscoveredHub>> discoverHubs({
    Function(String)? onProgress,
  }) async {
    final List<DiscoveredHub> discoveredHubs = [];
    
    try {
      // Get network info
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) {
        onProgress?.call('Not connected to Wi-Fi');
        return discoveredHubs;
      }

      onProgress?.call('Found device IP: $wifiIP');
      
      // Extract network prefix (e.g., "192.168.1" from "192.168.1.100")
      final ipParts = wifiIP.split('.');
      if (ipParts.length != 4) {
        onProgress?.call('Invalid network configuration');
        return discoveredHubs;
      }
      
      final networkPrefix = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';
      onProgress?.call('Scanning network: $networkPrefix.x');
      
      // First, try common addresses quickly
      final commonIPs = [
        '$networkPrefix.1',   // Router
        '$networkPrefix.100', // Common static IP
        '$networkPrefix.101',
        '$networkPrefix.102',
        '$networkPrefix.200',
        '$networkPrefix.254', // Common router IP
        wifiIP, // Try the device's own IP (in case it's running the hub)
      ];
      
      onProgress?.call('Checking common addresses...');
      
      for (final ip in commonIPs) {
        final hub = await _checkHub(ip);
        if (hub != null) {
          discoveredHubs.add(hub);
          onProgress?.call('Found hub at $ip');
        }
      }
      
      // If we found hubs, return them quickly
      if (discoveredHubs.isNotEmpty) {
        discoveredHubs.sort((a, b) => a.responseTime.compareTo(b.responseTime));
        onProgress?.call('Found ${discoveredHubs.length} hub(s)');
        return discoveredHubs;
      }
      
      // If no hubs found in common addresses, do a broader scan
      onProgress?.call('Scanning full network range...');
      
      final List<Future<DiscoveredHub?>> scanTasks = [];
      
      // Scan from .1 to .254, but skip the ones we already checked
      for (int i = 1; i <= 254; i++) {
        final ip = '$networkPrefix.$i';
        if (!commonIPs.contains(ip)) {
          scanTasks.add(_checkHub(ip));
        }
      }
      
      // Process in batches to avoid overwhelming the network
      const batchSize = 20;
      int completed = 0;
      
      for (int i = 0; i < scanTasks.length; i += batchSize) {
        final batch = scanTasks.skip(i).take(batchSize);
        final results = await Future.wait(batch);
        
        for (final hub in results) {
          if (hub != null) {
            discoveredHubs.add(hub);
          }
        }
        
        completed += batch.length;
        onProgress?.call('Scanning... ($completed/${scanTasks.length})');
        
        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Sort by response time (fastest first)
      discoveredHubs.sort((a, b) => a.responseTime.compareTo(b.responseTime));
      
      onProgress?.call('Found ${discoveredHubs.length} hub(s)');
      
    } catch (e) {
      onProgress?.call('Discovery failed: $e');
    }
    
    return discoveredHubs;
  }

  /// Check if a specific IP has an edge hub running
  Future<DiscoveredHub?> _checkHub(String ip) async {
    try {
      final url = 'http://$ip:$_hubPort$_discoveryEndpoint';
      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: _timeoutSeconds));
      
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        try {
          // Try to parse the actual hub info response
          final data = response.body;
          final hubUrl = 'http://$ip:$_hubPort';
          
          // Try to extract hub name and ID from response if it's JSON
          String hubName = 'Hiqma Story Hub';
          String hubId = 'HUB-${ip.replaceAll('.', '')}';
          
          if (data.contains('"hubName"') && data.contains('"hubId"')) {
            // Simple JSON parsing without importing dart:convert
            final nameMatch = RegExp(r'"hubName"\s*:\s*"([^"]*)"').firstMatch(data);
            final idMatch = RegExp(r'"hubId"\s*:\s*"([^"]*)"').firstMatch(data);
            
            if (nameMatch != null) hubName = nameMatch.group(1) ?? hubName;
            if (idMatch != null) hubId = idMatch.group(1) ?? hubId;
          }
          
          return DiscoveredHub(
            name: hubName,
            url: hubUrl,
            hubId: hubId,
            responseTime: stopwatch.elapsedMilliseconds,
          );
        } catch (e) {
          // If parsing fails, still consider it a valid hub
          return DiscoveredHub(
            name: 'Story Hub',
            url: 'http://$ip:$_hubPort',
            hubId: 'HUB-${ip.replaceAll('.', '')}',
            responseTime: stopwatch.elapsedMilliseconds,
          );
        }
      }
    } catch (e) {
      // Timeout or connection error - not a hub
      // Uncomment for debugging: print('Error checking $ip: $e');
    }
    
    return null;
  }

  /// Quick check if a specific URL is a valid hub
  Future<bool> validateHub(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$url$_discoveryEndpoint'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: _timeoutSeconds));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get current network info for display
  Future<String> getNetworkInfo() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      final wifiName = await networkInfo.getWifiName();
      
      if (wifiIP != null && wifiName != null) {
        return 'Connected to $wifiName ($wifiIP)';
      } else if (wifiIP != null) {
        return 'Connected to Wi-Fi ($wifiIP)';
      } else {
        return 'Not connected to Wi-Fi';
      }
    } catch (e) {
      return 'Network info unavailable: $e';
    }
  }

  /// Test a specific IP address for debugging
  Future<DiscoveredHub?> testSpecificIP(String ip) async {
    return await _checkHub(ip);
  }

  /// Get the current hub URL (for authentication service)
  /// This is a simple implementation that tries to find the first available hub
  Future<String?> getCurrentHubUrl() async {
    try {
      final hubs = await discoverHubs();
      if (hubs.isNotEmpty) {
        return hubs.first.url;
      }
      // Return production URL as fallback
      return _defaultHubUrl;
    } catch (e) {
      print('Error getting current hub URL: $e');
      // Return production URL as fallback
      return _defaultHubUrl;
    }
  }
}