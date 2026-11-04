import 'scan_result.dart';

class SavedScan {
  const SavedScan({
    required this.id,
    required this.description,
    required this.createdAt,
    required this.result,
  });

  final String id;
  final String description;
  final DateTime? createdAt;
  final ScanResult result;

  factory SavedScan.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid scan ID');
    }

    final description = json['brief_description'];
    final rawDate = json['createdAt'];

    DateTime? createdAt;
    if (rawDate != null) {
      if (rawDate is! String) {
        throw const FormatException('Invalid scan date');
      }
      createdAt = DateTime.tryParse(rawDate);
      if (createdAt == null) {
        throw const FormatException('Invalid scan date');
      }
    }

    return SavedScan(
      id: id,
      description: description is String && description.trim().isNotEmpty
          ? description.trim()
          : 'Scanned message',
      createdAt: createdAt,
      result: ScanResult.fromJson(json),
    );
  }
}
