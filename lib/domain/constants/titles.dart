import '../model/models.dart';

class CallingTitles {
  static const List<String> _genericTitles = [
    'New Sensor',      // L1
    'Sugarsmith',      // L2-3
    'Glucoguard',      // L4-6
    'Line-Keeper',     // L7-10
    'Range Marshal',   // L11-15
    'Guild Knight',    // L16-20
    'Savant',          // L21-29
    'Grandmaster',     // L30+
  ];

  static const Map<CallingDomain, List<String>> _titles = {
    CallingDomain.warrior: [
      'Sensor',        // L1
      'Glucoguard',    // L2-3
      'Line-Defender', // L4-6
      'Shieldbearer',  // L7-10
      'Steady Hand',   // L11-15
      'Basal Smith',   // L16-20
      'Warden of Range', // L21-29
      'Paragon of the Line', // L30+
    ],
    CallingDomain.sage: [
      'Carb Scout',    // L1
      'Unit Counter',  // L2-3
      'Ratio Keeper',  // L4-6
      'Carbologist',   // L7-10
      'Correction Calculator', // L11-15
      'Master Balancer',   // L16-20
      'Oracle of Glycemia',  // L21-29
      'Herald of the Ratio', // L30+
    ],
    CallingDomain.monk: [
      'Sip',           // L1
      'Spring Tender', // L2-3
      'Drinkwright',   // L4-6
      'Creek Watcher', // L7-10
      'Brook Keeper',  // L11-15
      'River Guide',   // L16-20
      'Warden of the Waters', // L21-29
      'Ocean',         // L30+
    ],
    CallingDomain.bard: [
      'Pinwheel',      // L1
      'Site Swapper',  // L2-3
      'Turner',        // L4-6
      'Rotor',         // L7-10
      'Gearwright',    // L11-15
      'Six-Point Master', // L16-20
      'Engine of Rotation', // L21-29
      'Living Compass',    // L30+
    ],
    CallingDomain.ranger: [
      'Night Watcher', // L1
      'Brighteye',     // L2-3
      'Pattern Hound', // L4-6
      'Dawn Watcher',  // L7-10
      'Trend Reader',  // L11-15
      'Slope Warden',  // L16-20
      'Oracle of the Arrow', // L21-29
      'All-Seeing Glyph',    // L30+
    ],
    CallingDomain.artificer: [
      'Dose Tender',   // L1
      'Vial Keeper',   // L2-3
      'Ratio Forger',  // L4-6
      'Bolus Refiner', // L7-10
      'Correction Crafter', // L11-15
      'Carb Alchemist',     // L16-20
      'Keeper of the Flask', // L21-29
      'Grand Alchemist of Insulin', // L30+
    ],
  };

  static String titleFor({CallingDomain? calling, required int level}) {
    final list = calling != null ? _titles[calling]! : _genericTitles;
    
    int index;
    if (level <= 1) {
      index = 0;
    } else if (level <= 3) {
      index = 1;
    } else if (level <= 6) {
      index = 2;
    } else if (level <= 10) {
      index = 3;
    } else if (level <= 15) {
      index = 4;
    } else if (level <= 20) {
      index = 5;
    } else if (level <= 29) {
      index = 6;
    } else {
      index = 7;
    }

    final baseTitle = list[index];
    if (level > 30) {
      return '$baseTitle ★${level - 30}';
    }
    return baseTitle;
  }
}
