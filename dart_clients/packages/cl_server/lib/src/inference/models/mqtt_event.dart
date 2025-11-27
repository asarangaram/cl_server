/// MQTT event received from broker for job completion notifications
class MqttEvent {
  final String jobId;
  final String event;
  final Map<String, dynamic> data;
  final int timestamp;

  MqttEvent({
    required this.jobId,
    required this.event,
    required this.data,
    required this.timestamp,
  });

  /// Create MqttEvent from JSON response
  factory MqttEvent.fromJson(Map<String, dynamic> json) {
    return MqttEvent(
      jobId: json['job_id'] as String,
      event: json['event'] as String,
      data: json['data'] as Map<String, dynamic>,
      timestamp: json['timestamp'] as int,
    );
  }

  /// Convert MqttEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'event': event,
      'data': data,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() => 'MqttEvent(jobId: $jobId, event: $event, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MqttEvent &&
          runtimeType == other.runtimeType &&
          jobId == other.jobId &&
          event == other.event &&
          data == other.data &&
          timestamp == other.timestamp;

  @override
  int get hashCode => jobId.hashCode ^ event.hashCode ^ data.hashCode ^ timestamp.hashCode;
}
