import 'package:drift/drift.dart';
import '../../domain/model/models.dart';
import '../db/database.dart';
import '../db/tables.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Stream<ProfileData> watchProfile() {
    return (select(profiles)..where((tbl) => tbl.id.equals(1)))
        .watchSingleOrNull()
        .asyncMap((row) async {
      if (row != null) return row;
      return getProfile();
    });
  }

  Future<ProfileData> getProfile() async {
    final existing = await (select(profiles)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (existing != null) return existing;

    // Seed initial profile row if empty
    await into(profiles).insertOnConflictUpdate(
      const ProfilesCompanion(
        id: Value(1),
        weekStart: Value(1),
        resetMinute: Value(0),
        themeMode: Value(0),
        accent: Value('frost'),
        digestEnabled: Value(true),
        digestMinute: Value(540),
      ),
    );
    final row = await (select(profiles)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    return row ??
        const ProfileData(
          id: 1,
          weekStart: 1,
          resetMinute: 0,
          themeMode: 0,
          accent: 'frost',
          digestEnabled: true,
          digestMinute: 540,
          hasGraceToken: true,
          isSick: false,
        );
  }

  Future<int> updateName(String name) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(name: Value(name)));
  }

  Future<int> updateCalling(int calling, DateTime chosenAt) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(
          calling: Value(calling),
          callingChosenAt: Value(chosenAt),
        ));
  }

  Future<int> updateThemeMode(int themeMode) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(themeMode: Value(themeMode)));
  }

  Future<int> updateAccent(String accent) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(accent: Value(accent)));
  }

  Future<int> updateCadenceSettings(int resetMinute, int weekStart) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(
          resetMinute: Value(resetMinute),
          weekStart: Value(weekStart),
        ));
  }

  Future<int> updateNotifications(bool enabled, int minute) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(
          digestEnabled: Value(enabled),
          digestMinute: Value(minute),
        ));
  }

  Future<int> updateSettledThrough(String settledThrough) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(settledThrough: Value(settledThrough)));
  }

  Future<int> updateGlucoseSettledThrough(String? settledThrough) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(glucoseSettledThrough: Value(settledThrough)));
  }

  Future<int> setSick(bool isSick) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(isSick: Value(isSick)));
  }

  Future<int> consumeGraceToken(DateTime now) {
    return (update(profiles)..where((tbl) => tbl.id.equals(1)))
        .write(ProfilesCompanion(
          hasGraceToken: const Value(false),
          lastGraceTokenUsed: Value(now),
        ));
  }

  /// Refill a grace token if its 30-day cooldown has elapsed.
  Future<void> refillGraceToken({required LocalDate today}) async {
    final profile = await getProfile();
    if (profile.hasGraceToken) return;
    final lastUsed = profile.lastGraceTokenUsed;
    if (lastUsed == null) return;
    final lastLocal = LocalDate.fromDateTime(lastUsed);
    if (today.differenceInDays(lastLocal) >= 30) {
      await (update(profiles)..where((tbl) => tbl.id.equals(1)))
          .write(const ProfilesCompanion(hasGraceToken: Value(true)));
    }
  }
}
