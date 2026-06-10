class Device {
  final String id;
  final String deviceCode;
  final String? name;
  final String status;
  final DateTime? registeredAt;
  final DateTime? lastSeen;
  final DeviceInfo? deviceInfo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Device({
    required this.id,
    required this.deviceCode,
    this.name,
    required this.status,
    this.registeredAt,
    this.lastSeen,
    this.deviceInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String? ?? '',
      deviceCode: json['deviceCode'] as String? ?? '',
      name: json['name'] as String?,
      status: json['status'] as String? ?? 'pending',
      registeredAt: json['registeredAt'] != null 
          ? DateTime.parse(json['registeredAt'] as String)
          : null,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      deviceInfo: json['deviceInfo'] != null 
          ? DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceCode': deviceCode,
      'name': name,
      'status': status,
      'registeredAt': registeredAt?.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
      'deviceInfo': deviceInfo?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Device copyWith({
    String? id,
    String? deviceCode,
    String? name,
    String? status,
    DateTime? registeredAt,
    DateTime? lastSeen,
    DeviceInfo? deviceInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      deviceCode: deviceCode ?? this.deviceCode,
      name: name ?? this.name,
      status: status ?? this.status,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSeen: lastSeen ?? this.lastSeen,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Device(id: $id, deviceCode: $deviceCode, name: $name, status: $status)';
  }
}

class DeviceInfo {
  final String model;
  final String osVersion;
  final String appVersion;
  final Map<String, dynamic>? additionalInfo;

  DeviceInfo({
    required this.model,
    required this.osVersion,
    required this.appVersion,
    this.additionalInfo,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      model: json['model'] as String? ?? 'Unknown',
      osVersion: json['osVersion'] as String? ?? 'Unknown',
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'additionalInfo': additionalInfo,
    };
  }

  @override
  String toString() {
    return 'DeviceInfo(model: $model, osVersion: $osVersion, appVersion: $appVersion)';
  }
}