import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backend_providers.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';

class BackendTestScreen extends ConsumerStatefulWidget {
  const BackendTestScreen({super.key});

  @override
  ConsumerState<BackendTestScreen> createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends ConsumerState<BackendTestScreen> {
  String _healthStatus = 'Unknown';
  String _connectionStatus = 'Disconnected';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _addLog('Backend Test Screen initialized');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toLocal().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testHealthCheck() async {
    _addLog('Testing backend health check...');
    
    try {
      final isHealthy = await BackendApiService.healthCheck();
      setState(() {
        _healthStatus = isHealthy ? 'Healthy ✅' : 'Unhealthy ❌';
      });
      _addLog('Health check result: ${isHealthy ? 'PASS' : 'FAIL'}');
    } catch (e) {
      setState(() {
        _healthStatus = 'Error ❌';
      });
      _addLog('Health check error: $e');
    }
  }

  Future<void> _testSocketConnection() async {
    _addLog('Testing Socket.IO connection...');
    
    try {
      final socketService = SocketService.instance;
      
      setState(() {
        _connectionStatus = 'Connecting...';
      });
      
      await socketService.connect(passengerId: 'test-passenger-123');
      
      // Wait a moment to see if connection establishes
      await Future.delayed(const Duration(seconds: 2));
      
      final isConnected = socketService.isConnected;
      setState(() {
        _connectionStatus = isConnected ? 'Connected ✅' : 'Failed ❌';
      });
      _addLog('Socket.IO connection: ${isConnected ? 'SUCCESS' : 'FAILED'}');
      
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error ❌';
      });
      _addLog('Socket.IO error: $e');
    }
  }

  Future<void> _testApiInfo() async {
    _addLog('Testing API info endpoint...');
    
    try {
      final apiInfo = await BackendApiService.getApiInfo();
      if (apiInfo != null) {
        _addLog('API Info received: $apiInfo');
      } else {
        _addLog('API Info: No data received');
      }
    } catch (e) {
      _addLog('API Info error: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('Logs cleared');
  }

  void _disconnectSocket() {
    _addLog('Disconnecting Socket.IO...');
    SocketService.instance.disconnect();
    setState(() {
      _connectionStatus = 'Disconnected';
    });
    _addLog('Socket.IO disconnected');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Connection Test'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Backend URL Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backend URL:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'https://tourtaxi-unified-backend.onrender.com',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Icon(Icons.health_and_safety, size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            'Health Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_healthStatus),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Icon(Icons.connect_without_contact, size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            'Socket.IO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_connectionStatus),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testHealthCheck,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Test Health'),
                ),
                ElevatedButton.icon(
                  onPressed: _testSocketConnection,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Connect Socket'),
                ),
                ElevatedButton.icon(
                  onPressed: _testApiInfo,
                  icon: const Icon(Icons.info),
                  label: const Text('API Info'),
                ),
                ElevatedButton.icon(
                  onPressed: _disconnectSocket,
                  icon: const Icon(Icons.wifi_off),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Logs Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Logs:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            
            // Logs Display
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          _logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Watchers
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final backendHealth = ref.watch(backendHealthProvider);
                final connectionStatus = ref.watch(backendConnectionStatusProvider);
                
                return Card(
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Provider Status:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Backend Health: ${backendHealth.when(
                          data: (healthy) => healthy ? 'Healthy' : 'Unhealthy',
                          loading: () => 'Checking...',
                          error: (e, _) => 'Error: $e',
                        )}'),
                        Text('Connection: $connectionStatus'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}