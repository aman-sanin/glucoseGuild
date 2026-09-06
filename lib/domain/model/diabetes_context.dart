import 'dart:convert';

/// What physical action a completion represents in GLUCOSE_GUILD.
enum GlucoseLogType {
  scan,
  insulin,
  meal,
  water,
  site,
  mood,
  ketone;

  static GlucoseLogType fromKey(String? key) => values.firstWhere(
        (v) => v.name == key,
        orElse: () => GlucoseLogType.scan,
      );
}

/// Sensing modality for a glucose reading.
enum ScanType {
  cgm,
  fingerstick;

  static ScanType fromKey(String? key) => values.firstWhere(
        (v) => v.name == key,
        orElse: () => ScanType.cgm,
      );

  String get label => this == ScanType.cgm ? 'CGM' : 'Fingerstick';
}

/// Meal composition estimates for carb logging.
enum MealType {
  lowCarb,
  mediumCarb,
  highCarb,
  highFat;

  static MealType fromKey(String? key) => values.firstWhere(
        (v) => v.name == key,
        orElse: () => MealType.mediumCarb,
      );

  String get label {
    switch (this) {
      case MealType.lowCarb:
        return 'Low carb';
      case MealType.mediumCarb:
        return 'Medium carb';
      case MealType.highCarb:
        return 'High carb';
      case MealType.highFat:
        return 'High fat';
    }
  }
}

/// Injection / pump site locations for the rotation pinwheel.
enum InsulinSite {
  leftArm,
  rightArm,
  leftAbdomen,
  rightAbdomen,
  leftLeg,
  rightLeg,
  buttock;

  static InsulinSite fromKey(String? key) => values.firstWhere(
        (v) => v.name == key,
        orElse: () => InsulinSite.leftArm,
      );

  String get label {
    switch (this) {
      case InsulinSite.leftArm:
        return 'Left arm';
      case InsulinSite.rightArm:
        return 'Right arm';
      case InsulinSite.leftAbdomen:
        return 'Left abdomen';
      case InsulinSite.rightAbdomen:
        return 'Right abdomen';
      case InsulinSite.leftLeg:
        return 'Left leg';
      case InsulinSite.rightLeg:
        return 'Right leg';
      case InsulinSite.buttock:
        return 'Buttock';
    }
  }
}

/// Structured context attached to a [completion] for granular analytics.
class GlucoseContext {
  final GlucoseLogType type;
  final ScanType? scanType;
  final MealType? mealType;
  final InsulinSite? site;
  final bool? correction;
  final bool? extendedBolus;
  final String? device;
  final String? mood;

  const GlucoseContext({
    required this.type,
    this.scanType,
    this.mealType,
    this.site,
    this.correction,
    this.extendedBolus,
    this.device,
    this.mood,
  });

  static const GlucoseContext cgmScan = GlucoseContext(type: GlucoseLogType.scan, scanType: ScanType.cgm);
  static const GlucoseContext fingerstick = GlucoseContext(type: GlucoseLogType.scan, scanType: ScanType.fingerstick);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (scanType != null) 'scan_type': scanType!.name,
        if (mealType != null) 'meal_type': mealType!.name,
        if (site != null) 'site': site!.name,
        if (correction != null) 'correction': correction,
        if (extendedBolus != null) 'extended_bolus': extendedBolus,
        if (device != null) 'device': device,
        if (mood != null) 'mood': mood,
      };

  factory GlucoseContext.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GlucoseContext(type: GlucoseLogType.scan);
    return GlucoseContext(
      type: GlucoseLogType.fromKey(json['type'] as String?),
      scanType: json['scan_type'] != null ? ScanType.fromKey(json['scan_type'] as String?) : null,
      mealType: json['meal_type'] != null ? MealType.fromKey(json['meal_type'] as String?) : null,
      site: json['site'] != null ? InsulinSite.fromKey(json['site'] as String?) : null,
      correction: json['correction'] as bool?,
      extendedBolus: json['extended_bolus'] as bool?,
      device: json['device'] as String?,
      mood: json['mood'] as String?,
    );
  }

  /// Decode from the stored `contextJson` column (null-safe).
  factory GlucoseContext.fromDb(String? raw) {
    if (raw == null || raw.isEmpty) return const GlucoseContext(type: GlucoseLogType.scan);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const GlucoseContext(type: GlucoseLogType.scan);
      }
      return GlucoseContext.fromJson(decoded);
    } catch (_) {
      return const GlucoseContext(type: GlucoseLogType.scan);
    }
  }

  /// Serialize to the stored `contextJson` column (null-safe).
  String? toDb() {
    if (type == GlucoseLogType.scan && scanType == null) return null;
    return jsonEncode(toJson());
  }

  bool get isScan => type == GlucoseLogType.scan;
  bool get isInsulin => type == GlucoseLogType.insulin;
  bool get isMeal => type == GlucoseLogType.meal;
  bool get isWater => type == GlucoseLogType.water;
  bool get isSiteLog => type == GlucoseLogType.site;
  bool get isMood => type == GlucoseLogType.mood;
  bool get isKetone => type == GlucoseLogType.ketone;
}