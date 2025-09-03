-- Function to clean up soft-deleted records after 30 days
CREATE OR REPLACE FUNCTION cleanup_soft_deleted_records()
RETURNS void AS $$
BEGIN
    -- Delete notes that have been soft-deleted for more than 30 days
    DELETE FROM notes 
    WHERE is_deleted = true 
    AND updated_at < NOW() - INTERVAL '30 days';
    
    -- Delete groups that have been soft-deleted for more than 30 days
    -- First, migrate any remaining notes to 'Uncategorized'
    UPDATE notes 
    SET group_id = (
        SELECT id FROM groups 
        WHERE name = 'Uncategorized' 
        AND user_id = notes.user_id 
        LIMIT 1
    )
    WHERE group_id IN (
        SELECT id FROM groups 
        WHERE is_deleted = true 
        AND updated_at < NOW() - INTERVAL '30 days'
    );
    
    -- Then delete the groups
    DELETE FROM groups 
    WHERE is_deleted = true 
    AND updated_at < NOW() - INTERVAL '30 days'
    AND name != 'Uncategorized'; -- Never delete Uncategorized group
    
    RAISE NOTICE 'Cleanup completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run cleanup daily (requires pg_cron extension)
-- This would typically be set up in the Supabase dashboard or via SQL editor
-- SELECT cron.schedule('cleanup-soft-deleted', '0 2 * * *', 'SELECT cleanup_soft_deleted_records();');
