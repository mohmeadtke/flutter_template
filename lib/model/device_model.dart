/// One device signed in to the account — a row of `GET Auth/Devices`.
/// Used by the home screen example.
class DeviceModel {
  final String id;
  final String? deviceSn;
  final String? deviceOs;
  final String? appType;
  final String? name;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  /// The device making the request.
  final bool current;

  const DeviceModel({
    required this.id,
    this.deviceSn,
    this.deviceOs,
    this.appType,
    this.name,
    this.firstSeenAt,
    this.lastSeenAt,
    this.current = false,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    id: json['id']?.toString() ?? '',
    deviceSn: json['deviceSn']?.toString(),
    deviceOs: json['deviceOs']?.toString(),
    appType: json['appType']?.toString(),
    name: json['name']?.toString(),
    firstSeenAt: DateTime.tryParse(json['firstSeenAt']?.toString() ?? ''),
    lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
    current: json['current'] == true,
  );

  /// Rows of an already-unwrapped body (see `ApiResponse.body`). The current
  /// device first, then the most recently used.
  static List<DeviceModel> listFrom(dynamic rows) {
    if (rows is! List) return [];
    final devices = rows
        .whereType<Map>()
        .map((row) => DeviceModel.fromJson(Map<String, dynamic>.from(row)))
        .where((device) => device.id.isNotEmpty)
        .toList();
    devices.sort((a, b) {
      if (a.current != b.current) return a.current ? -1 : 1;
      final aSeen = a.lastSeenAt ?? DateTime(0);
      final bSeen = b.lastSeenAt ?? DateTime(0);
      return bSeen.compareTo(aSeen);
    });
    return devices;
  }

  /// The server's name for the device, else its OS.
  String get displayName {
    final named = name?.trim() ?? '';
    if (named.isNotEmpty) return named;
    return deviceOs ?? deviceSn ?? id;
  }
}
