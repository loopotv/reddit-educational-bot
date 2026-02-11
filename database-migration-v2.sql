-- ========================================
-- VIVID Editorial Calendar - DB Migration v2
-- Run: ssh contabo 'docker exec -i postgres psql -U n8n -d n8n' < database-migration-v2.sql
-- ========================================

-- 1. New columns on content_queue for editorial calendar support
ALTER TABLE content_queue
  ADD COLUMN IF NOT EXISTS pillar VARCHAR(20) DEFAULT 'tutorial',
  ADD COLUMN IF NOT EXISTS content_source VARCHAR(20) DEFAULT 'discovery',
  ADD COLUMN IF NOT EXISTS calendar_date DATE,
  ADD COLUMN IF NOT EXISTS hook_type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS industry VARCHAR(100),
  ADD COLUMN IF NOT EXISTS hook_phrase TEXT,
  ADD COLUMN IF NOT EXISTS phases_json JSONB,
  ADD COLUMN IF NOT EXISTS cta_overlay_text TEXT,
  ADD COLUMN IF NOT EXISTS cta_secondary_text TEXT,
  ADD COLUMN IF NOT EXISTS music_mood VARCHAR(50),
  ADD COLUMN IF NOT EXISTS google_sheet_row INTEGER,
  ADD COLUMN IF NOT EXISTS manual_upload BOOLEAN DEFAULT FALSE;

-- 2. Indexes for calendar queries
CREATE INDEX IF NOT EXISTS idx_content_queue_calendar_date ON content_queue(calendar_date);
CREATE INDEX IF NOT EXISTS idx_content_queue_pillar ON content_queue(pillar);
CREATE INDEX IF NOT EXISTS idx_content_queue_content_source ON content_queue(content_source);

-- 3. Add cinematic_asmr music entries (placeholders - replace with real files)
INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path, last_synced)
VALUES
  (md5('cinematic_asmr_ambient_01'), 'Cinematic ASMR Ambient 1', 'ambient', 'cinematic_asmr', '/var/www/music/cinematic_asmr/track_01.wav', NOW()),
  (md5('cinematic_asmr_ambient_02'), 'Cinematic ASMR Ambient 2', 'ambient', 'cinematic_asmr', '/var/www/music/cinematic_asmr/track_02.wav', NOW()),
  (md5('cinematic_asmr_bass_drop_01'), 'Cinematic ASMR Bass Drop', 'cinematic', 'cinematic_asmr', '/var/www/music/cinematic_asmr/track_03.wav', NOW())
ON CONFLICT (motion_array_id) DO NOTHING;

-- 4. Update existing rows to have default values
UPDATE content_queue SET pillar = 'tutorial' WHERE pillar IS NULL;
UPDATE content_queue SET content_source = 'discovery' WHERE content_source IS NULL;

-- 5. View for today's calendar items
CREATE OR REPLACE VIEW todays_calendar_items AS
SELECT *
FROM content_queue
WHERE content_source = 'calendar'
  AND calendar_date = CURRENT_DATE
  AND status NOT IN ('published', 'script_rejected', 'video_rejected')
ORDER BY created_at ASC;

-- 6. Column comments
COMMENT ON COLUMN content_queue.pillar IS 'Content pillar: wow, educa, viaggio, tutorial';
COMMENT ON COLUMN content_queue.content_source IS 'Where content originated: calendar or discovery';
COMMENT ON COLUMN content_queue.phases_json IS 'WOW video 4-phase structure (TRIGGER, IMMERSION, REVEAL, CTA)';
COMMENT ON COLUMN content_queue.calendar_date IS 'Scheduled publish date from editorial calendar';
COMMENT ON COLUMN content_queue.hook_type IS 'Industry hook: beer, food, hotel, cocktail, beauty, product, pizzeria, airbnb';
COMMENT ON COLUMN content_queue.google_sheet_row IS 'Row number in Google Sheets calendar for writeback';

-- Verify migration
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'content_queue'
  AND column_name IN ('pillar', 'content_source', 'calendar_date', 'phases_json', 'hook_type', 'manual_upload')
ORDER BY ordinal_position;
