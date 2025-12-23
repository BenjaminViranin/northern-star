-- Notes history snapshots are now client-driven; avoid logging every update.
DROP TRIGGER IF EXISTS notes_history_trigger ON notes;
CREATE TRIGGER notes_history_trigger
    AFTER INSERT OR DELETE ON notes
    FOR EACH ROW EXECUTE FUNCTION log_entity_history();
