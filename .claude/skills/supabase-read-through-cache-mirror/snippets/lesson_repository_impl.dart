// Read-through: local fast path → remote on miss → backfill mirror.
class LessonRepositoryImpl implements LessonRepository {
  LessonRepositoryImpl(this._db, this._supabase);
  final AppDatabase _db;
  final SupabaseClient _supabase;

  @override
  Future<Result<List<Lesson>, Failure>> listLessonsForUnit(String unitId) async {
    try {
      final local = await _db.lessonsForUnit(unitId);
      if (local.isNotEmpty) return Success(local); // fast path

      // Cache miss → go remote (the line ADR-027 omitted).
      final rows = await _supabase
          .from('lessons')
          .select()
          .eq('unit_id', unitId)
          .order('idx');

      final lessons = rows.map(Lesson.fromJson).toList();
      await _db.upsertLessons(lessons); // backfill so next read is local
      return Success(lessons);
    } on PostgrestException catch (e) {
      return Err(BackendFailure(e.message));
    } catch (e) {
      // Offline + empty mirror is a real failure, not a silent empty list.
      return Err(const NetworkFailure('lessons unavailable offline'));
    }
  }
}
