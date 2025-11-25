-- Migration: Remove unused markdown and plain_text columns from notes table
-- Date: 2025-11-25
-- Description: After switching from flutter_quill to plain text editor,
--              the markdown and plain_text columns are no longer needed.
--              The content column now stores plain text directly.

-- Drop the full-text search index on plain_text
DROP INDEX IF EXISTS idx_notes_plain_text;

-- Remove unused columns
ALTER TABLE notes DROP COLUMN IF EXISTS markdown;
ALTER TABLE notes DROP COLUMN IF EXISTS plain_text;

-- Create new full-text search index on content column
CREATE INDEX idx_notes_content ON notes USING gin(to_tsvector('english', content));

-- Update comment on content column to reflect it's now plain text
COMMENT ON COLUMN notes.content IS 'Plain text content of the note';

