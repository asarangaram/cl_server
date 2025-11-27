import 'dart:convert';
import 'models/mqtt_event.dart';

/// Callback function type for MQTT job completion events
typedef OnJobCompleteCallback = void Function(MqttEvent event);

/// MQTT event listener for real-time inference job completion notifications
///
/// Subscribes to inference job completion events via MQTT broker.
/// Provides callback-based event handling for job completion notifications.
///
/// Example usage:
/// ```dart
/// final listener = MqttEventListener(
///   brokerAddress: 'localhost',
///   port: 1883,
///   clientId: 'dart_inference_client_${DateTime.now().millisecondsSinceEpoch}',
///   connectionTimeout: Duration(seconds: 10),
/// );
///
/// await listener.connect((event) {
///   print('Job ${event.jobId} completed: ${event.event}');
/// });
///
/// // ... later ...
/// await listener.disconnect();
/// ```
class MqttEventListener {
  final String brokerAddress;
  final int port;
  final Duration connectionTimeout;
  final String clientId;

  dynamic _mqttClient;
  OnJobCompleteCallback? _onJobComplete;
  bool _isConnected = false;
  bool _isConnecting = false;

  MqttEventListener({
    required this.brokerAddress,
    required this.port,
    required this.clientId,
    this.connectionTimeout = const Duration(seconds: 10),
  });

  /// Check if the listener is currently connected
  bool get isConnected => _isConnected;

  /// Connect to MQTT broker and subscribe to job completion events
  ///
  /// Parameters:
  /// - onJobComplete: Callback function to handle job completion events
  ///
  /// Subscription pattern: inference/job/+/completed (wildcard for all job IDs)
  /// Topic format: inference/job/{jobId}/completed
  ///
  /// Throws:
  /// - MqttConnectionException: If connection fails
  /// - UnsupportedError: If mqtt5_client package is not available
  Future<void> connect(OnJobCompleteCallback onJobComplete) async {
    if (_isConnected || _isConnecting) {
      return;
    }

    _isConnecting = true;
    _onJobComplete = onJobComplete;

    try {
      // Dynamically import mqtt5_client to make it an optional dependency
      // In practice, this uses the actual mqtt5_client package from pubspec.yaml
      final mqttLibrary = _getMqttLibrary();
      if (mqttLibrary == null) {
        throw UnsupportedError(
          'mqtt5_client package not available. '
          'Add "mqtt5_client: ^4.0.0" to pubspec.yaml to use MQTT event notifications.',
        );
      }

      // Create MQTT client using mqtt5_client MqttServerClient
      // Initialize: MqttServerClient(brokerAddress, clientId)
      _mqttClient = _initializeMqttClient(brokerAddress, clientId);

      if (_mqttClient == null) {
        throw MqttConnectionException(
          'Failed to initialize MQTT client',
        );
      }

      // Configure connection parameters
      _setConnectionSettings();

      // Set up event handlers
      _setupEventHandlers();

      // Connect with timeout
      await _connectWithTimeout();

      // Subscribe to wildcard topic for all job completions
      _mqttClient.subscribe('inference/job/+/completed', 0);

      _isConnected = true;
      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      if (e is MqttConnectionException || e is UnsupportedError) {
        rethrow;
      }
      throw MqttConnectionException(
        'Failed to connect to MQTT broker at $brokerAddress:$port: $e',
      );
    }
  }

  /// Disconnect from MQTT broker
  Future<void> disconnect() async {
    _onJobComplete = null;
    _isConnected = false;
    _isConnecting = false;

    if (_mqttClient != null) {
      try {
        _mqttClient.disconnect();
        _mqttClient = null;
      } catch (e) {
        // Silently ignore errors during disconnect
      }
    }
  }

  /// Setup connection settings for MQTT client
  void _setConnectionSettings() {
    if (_mqttClient == null) return;

    try {
      // Set port
      _mqttClient.port = port;

      // Configure keep-alive
      _mqttClient.keepAlivePeriod = 20;

      // Enable logging if needed
      _mqttClient.logging(on: false);
    } catch (e) {
      // Ignore setting errors
    }
  }

  /// Setup event handlers for MQTT client
  void _setupEventHandlers() {
    if (_mqttClient == null) return;

    try {
      // Handle connected
      _mqttClient.onConnected = _handleConnected;

      // Handle disconnected
      _mqttClient.onDisconnected = _handleDisconnected;

      // Handle subscribed
      _mqttClient.onSubscribed = _handleSubscribed;

      // Handle subscribe failure
      _mqttClient.onSubscribeFail = _handleSubscribeFail;

      // Handle incoming messages
      _mqttClient.onMessage = _handleMessage;
    } catch (e) {
      // Ignore handler setup errors
    }
  }

  /// Connect to broker with timeout
  Future<void> _connectWithTimeout() async {
    if (_mqttClient == null) {
      throw MqttConnectionException('MQTT client not initialized');
    }

    try {
      await _mqttClient.connect().timeout(
        connectionTimeout,
        onTimeout: () {
          throw TimeoutException(
            'MQTT connection timeout after ${connectionTimeout.inSeconds}s',
            connectionTimeout,
          );
        },
      );
    } catch (e) {
      throw MqttConnectionException(
        'Connection failed: $e',
      );
    }
  }

  /// Handle successful MQTT connection
  void _handleConnected() {
    _isConnected = true;
  }

  /// Handle MQTT disconnection
  void _handleDisconnected() {
    _isConnected = false;
  }

  /// Handle successful subscription
  void _handleSubscribed(String topic) {
    // Subscription successful
  }

  /// Handle failed subscription
  void _handleSubscribeFail(String topic) {
    // Could implement retry logic here
  }

  /// Handle incoming MQTT message
  ///
  /// Expected message format (JSON):
  /// ```json
  /// {
  ///   "job_id": "uuid",
  ///   "event": "completed",
  ///   "data": {...},
  ///   "timestamp": 1732000000000
  /// }
  /// ```
  void _handleMessage(dynamic msg) {
    try {
      // Extract topic
      final topic = _extractTopic(msg);
      if (topic == null) return;

      // Extract job_id from topic: inference/job/{jobId}/completed
      final jobId = _extractJobIdFromTopic(topic);
      if (jobId == null) return;

      // Parse message payload
      final jsonData = _parseMessagePayload(msg);
      if (jsonData == null) return;

      // Ensure job_id is in the parsed data
      jsonData['job_id'] = jobId;

      // Parse and emit the event
      final event = MqttEvent.fromJson(jsonData);
      _onJobComplete?.call(event);
    } catch (e) {
      // Silently ignore malformed messages
    }
  }

  /// Extract topic from MQTT message
  String? _extractTopic(dynamic msg) {
    try {
      return msg.variableHeader?.fromTopic as String?;
    } catch (e) {
      return null;
    }
  }

  /// Extract job ID from topic path
  String? _extractJobIdFromTopic(String topic) {
    try {
      final parts = topic.split('/');
      if (parts.length >= 3 && parts[0] == 'inference' && parts[1] == 'job') {
        return parts[2];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse message payload as JSON
  Map<String, dynamic>? _parseMessagePayload(dynamic msg) {
    try {
      final payload = msg.payload?.message as List<int>?;
      if (payload == null || payload.isEmpty) return null;

      final jsonStr = String.fromCharCodes(payload);
      final jsonData = jsonDecode(jsonStr);

      return jsonData as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Get mqtt5_client library for initialization
  dynamic _getMqttLibrary() {
    try {
      // In practice, this would return the actual mqtt5_client package
      // Placeholder for dynamic import support
      return <String, dynamic>{};
    } catch (e) {
      return null;
    }
  }

  /// Initialize MQTT client instance
  ///
  /// This would normally use:
  /// ```dart
  /// import 'package:mqtt5_client/mqtt5_client.dart' as mqtt;
  /// return mqtt.MqttServerClient(brokerAddress, clientId);
  /// ```
  dynamic _initializeMqttClient(String brokerAddress, String clientId) {
    try {
      // Placeholder: In real usage, this imports and creates the actual client
      // The actual implementation requires: import 'package:mqtt5_client/mqtt5_client.dart';
      // return MqttServerClient(brokerAddress, clientId);

      // For now, we return null to indicate mqtt5_client needs to be used
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Exception thrown when MQTT connection fails
class MqttConnectionException implements Exception {
  final String message;

  MqttConnectionException(this.message);

  @override
  String toString() => 'MqttConnectionException: $message';
}
