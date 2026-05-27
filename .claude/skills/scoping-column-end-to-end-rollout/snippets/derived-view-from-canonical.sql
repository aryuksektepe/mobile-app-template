-- ============================================================================
-- derived-view-from-canonical.sql
-- ----------------------------------------------------------------------------
-- Correct shape for a derived "% of X completed in scope Y" VIEW.
-- The denominator (`total`) MUST come from the canonical content table, NOT
-- from the event log — otherwise the percentage saturates as soon as the
-- user touches any item (1 attempted / 1 attempted = 100%).
--
-- Real-world bug this prevents (Phase-28 BUG-28-03 / CR-28-02):
--   * A "well_mastery" VIEW was `FROM progress_events GROUP BY user_id, well_id`.
--   * `modules_total` was COUNT(DISTINCT module_id) over progress_events.
--   * User completes 1 of 24 lessons → mastery_pct = 1.0 (instead of 0.04).
--
-- Replaces:
--   <view_name>          — output VIEW name (e.g. well_mastery, course_progress)
--   <canonical_table>    — table that defines the universe (e.g. modules, lessons)
--   <events_table>       — table that records user actions (e.g. progress_events)
--   <scope_col>          — the scope column (e.g. well_id, tenant_id, course_id)
--   <child_id_col>       — FK from events back to canonical (e.g. module_id)
--   <pass_predicate>     — boolean expression on events row that means "passed"
--                          (e.g. `is_correct = TRUE`, `result = 'pass'`, `score >= 70`)
-- ============================================================================

DROP VIEW IF EXISTS <view_name>;

CREATE VIEW <view_name>
WITH (security_invoker = on)   -- base-table RLS applies; cross-tenant leaks prevented
AS
WITH active_users AS (
  -- Constrain the cartesian to users that actually have activity.
  SELECT DISTINCT user_id FROM <events_table>
)
SELECT
  u.user_id,
  c.<scope_col>,

  -- Denominator: HOW MANY ITEMS EXIST IN THIS SCOPE (canonical)
  COUNT(DISTINCT c.id)                                      AS total,

  -- Numerator: HOW MANY DID THE USER PASS
  COUNT(DISTINCT e.<child_id_col>) FILTER (
    WHERE <pass_predicate>
  )                                                          AS passed,

  -- Ratio: zero-divide guarded
  CASE
    WHEN COUNT(DISTINCT c.id) = 0 THEN 0.0
    ELSE COUNT(DISTINCT e.<child_id_col>) FILTER (
           WHERE <pass_predicate>
         )::numeric / COUNT(DISTINCT c.id)
  END                                                        AS pct

FROM <canonical_table> c
CROSS JOIN active_users u
LEFT JOIN <events_table> e
  ON e.<child_id_col> = c.id
 AND e.user_id        = u.user_id    -- critical: prevents accidental cross-user join
WHERE c.<scope_col> IS NOT NULL
GROUP BY u.user_id, c.<scope_col>;

-- ============================================================================
-- WHY THIS SHAPE
-- ============================================================================
--
-- 1. `FROM canonical_table` makes the denominator authoritative:
--    "of the N modules in this well, how many did the user pass?"
--    It does NOT ask "of the N modules the user has attempted, ...".
--
-- 2. `LEFT JOIN events` (not INNER JOIN) keeps zero-activity scopes in the
--    result set with `passed = 0`, `pct = 0.0`. This is the positive empty
--    state — NOT an error.
--
-- 3. `CROSS JOIN active_users` is the bridge — it expands canonical rows
--    across the set of users who have ANY events. Without it, a VIEW joined
--    only on canonical would have no user dimension. (If you have a Users
--    table you can JOIN against, prefer that — but most apps don't want
--    per-zero-activity-user rows.)
--
-- 4. The `FILTER (WHERE <pass_predicate>)` clause is the correct way to
--    count conditionally inside an aggregate — DO NOT use a separate WHERE
--    in the outer query (that would filter out items where the user
--    failed/skipped, breaking the denominator).
--
-- 5. `WITH (security_invoker = on)` means VIEW reads execute under the
--    caller's identity, so base-table RLS policies (per-user row guards) on
--    canonical and events apply to the VIEW. Without this, the VIEW runs as
--    the VIEW owner (postgres) and bypasses RLS — usually NOT what you want.
--
-- ============================================================================
-- VERIFICATION
-- ============================================================================
--
-- -- 1. Empty user → 0, not NULL, not missing.
-- INSERT INTO auth.users (id, email) VALUES ('test-user', 'test@x.com');
-- SELECT * FROM <view_name> WHERE user_id = 'test-user';
-- -- Expected: 0 rows OR rows with total = N, passed = 0, pct = 0.0.
--
-- -- 2. Single pass in a 10-item scope → pct = 0.1, not 1.0.
-- INSERT INTO <events_table> (user_id, <child_id_col>, <pass_predicate field>)
-- VALUES ('test-user', 'some-canonical-id', TRUE);
-- SELECT * FROM <view_name> WHERE user_id = 'test-user';
-- -- Expected: total = 10, passed = 1, pct = 0.1.
--
-- -- 3. Cross-tenant leak test (RLS should block).
-- SET LOCAL ROLE authenticated;
-- SET LOCAL request.jwt.claim.sub TO 'other-user';
-- SELECT * FROM <view_name> WHERE user_id = 'test-user';
-- -- Expected: 0 rows (RLS blocks reading another user's scope).
