-- Tutorial Bot - Advertutorial Content Queue Database Schema
-- This schema manages the entire content pipeline from research to publishing

-- Main content queue table
CREATE TABLE IF NOT EXISTS content_queue (
    id SERIAL PRIMARY KEY,

    -- Content metadata
    technique_name VARCHAR(255) NOT NULL,
    technique_category VARCHAR(100), -- 'CTLT', 'Lighting', 'Composition', 'Color Grading', etc.
    source_url TEXT,
    source_platform VARCHAR(50), -- 'reddit', 'twitter', 'discord', 'blog'
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- AI-generated script
    script_json JSONB, -- Full script structure (hook, segments, cta)
    script_summary TEXT, -- Short description
    estimated_duration INTEGER DEFAULT 30, -- seconds

    -- Viral potential scoring
    viral_score INTEGER CHECK (viral_score >= 0 AND viral_score <= 100),
    trending_keywords TEXT[], -- Array of trending terms
    target_audience VARCHAR(100), -- 'photographers', 'designers', 'marketers', etc.

    -- Approval workflow
    status VARCHAR(50) DEFAULT 'pending_review',
    -- Statuses: 'pending_review', 'script_approved', 'rendering', 'video_ready', 'final_approved', 'published', 'rejected'

    telegram_message_id VARCHAR(100), -- For tracking approval messages
    approved_by VARCHAR(100), -- Telegram username
    approved_at TIMESTAMP,
    rejection_reason TEXT,

    -- Video generation
    video_style VARCHAR(100), -- 'cinematic', 'minimalist', 'artistic', 'editorial'
    branding_variant VARCHAR(50), -- 'style_1', 'style_2', 'style_3' for different logo/CTA placements
    music_track_id VARCHAR(255), -- Motion Array track ID
    music_url TEXT,

    -- Generated assets
    images_json JSONB, -- Array of generated image paths
    audio_path TEXT,
    subtitle_path TEXT,
    video_path TEXT,
    video_url TEXT,

    -- Publishing
    published_platforms TEXT[], -- ['tiktok', 'instagram', 'youtube_shorts']
    tiktok_id VARCHAR(100),
    instagram_id VARCHAR(100),

    -- Performance tracking
    views_count INTEGER DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,

    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rendered_at TIMESTAMP,
    published_at TIMESTAMP
);

-- Index for fast querying
CREATE INDEX IF NOT EXISTS idx_status ON content_queue(status);
CREATE INDEX IF NOT EXISTS idx_discovered_at ON content_queue(discovered_at DESC);
CREATE INDEX IF NOT EXISTS idx_viral_score ON content_queue(viral_score DESC);
CREATE INDEX IF NOT EXISTS idx_technique_category ON content_queue(technique_category);

-- Trending techniques tracking
CREATE TABLE IF NOT EXISTS trending_techniques (
    id SERIAL PRIMARY KEY,
    technique_name VARCHAR(255) NOT NULL,
    mention_count INTEGER DEFAULT 1,
    platforms JSONB, -- {"reddit": 5, "twitter": 12, "discord": 3}
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    peak_popularity TIMESTAMP,
    related_keywords TEXT[],

    UNIQUE(technique_name)
);

-- Music library cache (from Motion Array)
CREATE TABLE IF NOT EXISTS music_library (
    id SERIAL PRIMARY KEY,
    motion_array_id VARCHAR(255) UNIQUE,
    track_name VARCHAR(255),
    artist VARCHAR(255),
    duration INTEGER, -- seconds
    genre VARCHAR(100),
    mood VARCHAR(100), -- 'energetic', 'calm', 'dramatic', 'inspirational'
    bpm INTEGER,
    download_url TEXT,
    local_path TEXT,
    last_synced TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Branding variations
CREATE TABLE IF NOT EXISTS branding_variants (
    id SERIAL PRIMARY KEY,
    variant_name VARCHAR(50) UNIQUE,
    logo_position VARCHAR(50), -- 'top-left', 'top-right', 'bottom-left', 'bottom-right'
    logo_size VARCHAR(20), -- 'small', 'medium', 'large'
    cta_style VARCHAR(50), -- 'minimal', 'bold', 'animated', 'gradient'
    cta_text TEXT,
    cta_position VARCHAR(50),
    color_scheme JSONB, -- {"primary": "#FFD700", "secondary": "#000000"}
    font_primary VARCHAR(100),
    font_secondary VARCHAR(100),
    animation_style VARCHAR(50), -- 'fade', 'slide', 'zoom', 'none'
    is_active BOOLEAN DEFAULT true,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default branding variations
INSERT INTO branding_variants (variant_name, logo_position, logo_size, cta_style, cta_text, cta_position, color_scheme, font_primary, font_secondary, animation_style) VALUES
('minimal_clean', 'top-right', 'small', 'minimal', 'Learn more at vivid.ai', 'bottom-center', '{"primary": "#FFFFFF", "secondary": "#000000"}', 'Inter', 'Inter', 'fade'),
('bold_impact', 'top-left', 'medium', 'bold', 'Create with VIVID', 'bottom-right', '{"primary": "#FFD700", "secondary": "#1a1a1a"}', 'Montserrat', 'Inter', 'slide'),
('artistic_editorial', 'bottom-left', 'small', 'gradient', 'vivid.ai - AI for Creators', 'top-center', '{"primary": "#FF6B6B", "secondary": "#4ECDC4"}', 'Playfair Display', 'Inter', 'zoom'),
('modern_tech', 'top-center', 'medium', 'animated', 'Powered by VIVID AI', 'bottom-left', '{"primary": "#00D9FF", "secondary": "#0A0E27"}', 'Space Grotesk', 'Inter', 'fade')
ON CONFLICT (variant_name) DO NOTHING;

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for auto-updating timestamps
CREATE TRIGGER update_content_queue_updated_at BEFORE UPDATE ON content_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- View for pending approvals
CREATE OR REPLACE VIEW pending_script_approvals AS
SELECT
    id,
    technique_name,
    technique_category,
    script_summary,
    viral_score,
    source_platform,
    discovered_at,
    estimated_duration
FROM content_queue
WHERE status = 'pending_review'
ORDER BY viral_score DESC, discovered_at DESC;

-- View for ready to render
CREATE OR REPLACE VIEW ready_to_render AS
SELECT
    id,
    technique_name,
    script_json,
    video_style,
    branding_variant,
    music_track_id
FROM content_queue
WHERE status = 'script_approved'
ORDER BY viral_score DESC;

-- View for final video approvals
CREATE OR REPLACE VIEW pending_video_approvals AS
SELECT
    id,
    technique_name,
    video_path,
    video_url,
    estimated_duration,
    rendered_at
FROM content_queue
WHERE status = 'video_ready'
ORDER BY rendered_at DESC;

COMMENT ON TABLE content_queue IS 'Main content pipeline queue from research to publishing';
COMMENT ON TABLE trending_techniques IS 'Tracks trending AI prompting techniques across platforms';
COMMENT ON TABLE music_library IS 'Cached Motion Array music tracks for quick access';
COMMENT ON TABLE branding_variants IS 'Different VIVID branding styles for variety';
