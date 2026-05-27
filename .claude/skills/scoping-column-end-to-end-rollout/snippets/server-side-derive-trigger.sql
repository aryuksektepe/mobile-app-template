-- ============================================================================
-- server-side-derive-trigger.sql
-- ----------------------------------------------------------------------------
-- BEFORE INSERT trigger that derives a scoping/tenant FK column from an
-- existing FK chain. Use when:
--   * You added a new scope_id column to an event/progress/child table.
--   * The scope is unambiguously derivable from another FK (e.g.
--     progress_events.exercise_id → exercises.lesson_id → ... → modules.well_id).
--   * You do NOT want to modify every client write path (Path A — server
--     authoritative). This is the preferred approach.
--
-- Replaces:
--   <child>       — the table that holds scope_id (e.g. progress_events)
--   <parent>      — the table scope_id references (e.g. wells)
--   <link_table>  — the table that already links <child> to <parent> via a
--                   chain of FKs (e.g. modules, with modules.well_id)
--   <fk_col>      — the column on <child> used to look up the chain
--                   (e.g. module_id, or any FK that resolves to modules.id)
-- ============================================================================

CREATE OR REPLACE FUNCTION derive_scope_id_on_<child>()
RETURNS TRIGGER
SECURITY DEFINER       -- runs as the function owner (typically postgres role)
SET search_path = public
AS $$
BEGIN
  -- Idempotent: don't override if caller already set scope_id.
  IF NEW.scope_id IS NULL THEN
    NEW.scope_id := (
      SELECT lt.scope_id          -- the column on <link_table> we're chasing
      FROM <link_table> lt
      WHERE lt.id = NEW.<fk_col>
      LIMIT 1
    );

    -- Defensive: if the chain didn't resolve, fail loudly rather than write NULL.
    IF NEW.scope_id IS NULL THEN
      RAISE EXCEPTION
        'derive_scope_id_on_<child>: cannot derive scope_id (<fk_col>=%)',
        NEW.<fk_col>;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if any, then attach a new one.
DROP TRIGGER IF EXISTS trg_<child>_derive_scope_id ON <child>;
CREATE TRIGGER trg_<child>_derive_scope_id
  BEFORE INSERT ON <child>
  FOR EACH ROW
  EXECUTE FUNCTION derive_scope_id_on_<child>();

-- ============================================================================
-- VARIANT: deeper FK chain (e.g. progress_events → exercises → lessons → units → modules)
-- ============================================================================
--
-- For a chain of N joins, replace the SELECT subquery body with the joins:
--
--   NEW.scope_id := (
--     SELECT m.well_id
--     FROM exercises e
--     JOIN lessons l ON l.id = e.lesson_id
--     JOIN units   u ON u.id = l.unit_id
--     JOIN modules m ON m.id = u.module_id
--     WHERE e.id = NEW.exercise_id
--     LIMIT 1
--   );
--
-- ============================================================================
-- VARIANT: trigger BOTH inserts AND updates
-- ============================================================================
--
-- If your app allows UPDATE to repoint the parent FK (e.g. moving a row to a
-- different scope), add a BEFORE UPDATE trigger to keep scope_id in sync:
--
--   CREATE TRIGGER trg_<child>_derive_scope_id_upd
--     BEFORE UPDATE OF <fk_col> ON <child>
--     FOR EACH ROW
--     WHEN (OLD.<fk_col> IS DISTINCT FROM NEW.<fk_col>)
--     EXECUTE FUNCTION derive_scope_id_on_<child>();
--
-- ============================================================================
-- VERIFICATION (run after apply)
-- ============================================================================
--
--   -- 1. Function exists?
--   SELECT proname FROM pg_proc WHERE proname = 'derive_scope_id_on_<child>';
--
--   -- 2. Trigger attached?
--   SELECT tgname, tgrelid::regclass FROM pg_trigger
--   WHERE tgname = 'trg_<child>_derive_scope_id';
--
--   -- 3. End-to-end: INSERT with scope_id omitted should auto-populate
--   INSERT INTO <child> (id, <fk_col>, /*…*/) VALUES (gen_random_uuid(), 'some-fk', /*…*/);
--   SELECT scope_id FROM <child> ORDER BY created_at DESC LIMIT 1;  -- must be non-NULL
