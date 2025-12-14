#!/bin/bash

################################################################################
# Upload Music Library to Contabo VPS
# Uploads Motion Array music files organized by mood
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         Upload Music Library to Contabo VPS                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

VPS_HOST="contabo"
LOCAL_MUSIC_DIR="/Users/alessandro/projects/tutorial-bot/music"
REMOTE_MUSIC_DIR="/var/www/music"

# Count files
echo -e "${BLUE}📊 Music Library Summary:${NC}"
echo ""
echo "🎵 Energetic: $(find $LOCAL_MUSIC_DIR/energetic -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ') tracks"
echo "🎵 Calm: $(find $LOCAL_MUSIC_DIR/calm -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ') tracks"
echo "🎵 Dramatic: $(find $LOCAL_MUSIC_DIR/dramatic -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ') tracks"
echo "🎵 Inspirational: $(find $LOCAL_MUSIC_DIR/inspirational -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ') tracks"
echo ""

TOTAL=$(find $LOCAL_MUSIC_DIR -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" \) | wc -l | tr -d ' ')
echo -e "${GREEN}Total: $TOTAL tracks${NC}"
echo ""

# Calculate total size
TOTAL_SIZE=$(du -sh $LOCAL_MUSIC_DIR | awk '{print $1}')
echo -e "${YELLOW}Total size: $TOTAL_SIZE${NC}"
echo ""

read -p "Continue with upload? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Upload cancelled"
    exit 0
fi

echo ""
echo -e "${BLUE}Step 1: Creating directory structure on VPS...${NC}"
ssh $VPS_HOST "sudo mkdir -p $REMOTE_MUSIC_DIR/{energetic,calm,dramatic,inspirational}"
ssh $VPS_HOST "sudo chown -R 1000:1000 $REMOTE_MUSIC_DIR"
ssh $VPS_HOST "sudo chmod -R 755 $REMOTE_MUSIC_DIR"
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

echo -e "${BLUE}Step 2: Uploading music files...${NC}"
echo ""

# Upload each category
for MOOD in energetic calm dramatic inspirational; do
    echo -e "${YELLOW}Uploading $MOOD tracks...${NC}"

    # Use rsync for efficient transfer
    rsync -avz --progress \
        --include="*.mp3" \
        --include="*.wav" \
        --include="*.m4a" \
        --exclude="*" \
        $LOCAL_MUSIC_DIR/$MOOD/ \
        $VPS_HOST:$REMOTE_MUSIC_DIR/$MOOD/

    echo -e "${GREEN}✓ $MOOD uploaded${NC}"
    echo ""
done

echo -e "${BLUE}Step 3: Setting permissions...${NC}"
ssh $VPS_HOST "sudo chown -R 1000:1000 $REMOTE_MUSIC_DIR"
ssh $VPS_HOST "sudo chmod -R 755 $REMOTE_MUSIC_DIR"
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

echo -e "${BLUE}Step 4: Verifying upload...${NC}"
echo ""
ssh $VPS_HOST "for mood in energetic calm dramatic inspirational; do \
    count=\$(find $REMOTE_MUSIC_DIR/\$mood -type f | wc -l); \
    echo \"🎵 \$mood: \$count tracks\"; \
done"
echo ""

echo -e "${BLUE}Step 5: Populating music_library database table...${NC}"
ssh $VPS_HOST << 'ENDSSH'
docker exec -i postgres psql -U n8n -d n8n << 'ENDSQL'
-- Clear existing entries
TRUNCATE TABLE music_library;

-- Insert energetic tracks
INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path)
SELECT
    md5(filename) as motion_array_id,
    regexp_replace(filename, '\.(mp3|wav|m4a)$', '', 'i') as track_name,
    'electronic' as genre,
    'energetic' as mood,
    '/var/www/music/energetic/' || filename as local_path
FROM (
    SELECT unnest(ARRAY[
        $(ssh contabo "ls /var/www/music/energetic/ | grep -E '\.(mp3|wav|m4a)$' | sed \"s/^/'/;s/$/'/\" | tr '\n' ',' | sed 's/,$//'")
    ]) as filename
) files;

-- Insert calm tracks
INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path)
SELECT
    md5(filename) as motion_array_id,
    regexp_replace(filename, '\.(mp3|wav|m4a)$', '', 'i') as track_name,
    'ambient' as genre,
    'calm' as mood,
    '/var/www/music/calm/' || filename as local_path
FROM (
    SELECT unnest(ARRAY[
        $(ssh contabo "ls /var/www/music/calm/ | grep -E '\.(mp3|wav|m4a)$' | sed \"s/^/'/;s/$/'/\" | tr '\n' ',' | sed 's/,$//'")
    ]) as filename
) files;

-- Insert dramatic tracks
INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path)
SELECT
    md5(filename) as motion_array_id,
    regexp_replace(filename, '\.(mp3|wav|m4a)$', '', 'i') as track_name,
    'cinematic' as genre,
    'dramatic' as mood,
    '/var/www/music/dramatic/' || filename as local_path
FROM (
    SELECT unnest(ARRAY[
        $(ssh contabo "ls /var/www/music/dramatic/ | grep -E '\.(mp3|wav|m4a)$' | sed \"s/^/'/;s/$/'/\" | tr '\n' ',' | sed 's/,$//'")
    ]) as filename
) files;

-- Insert inspirational tracks
INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path)
SELECT
    md5(filename) as motion_array_id,
    regexp_replace(filename, '\.(mp3|wav|m4a)$', '', 'i') as track_name,
    'uplifting' as genre,
    'inspirational' as mood,
    '/var/www/music/inspirational/' || filename as local_path
FROM (
    SELECT unnest(ARRAY[
        $(ssh contabo "ls /var/www/music/inspirational/ | grep -E '\.(mp3|wav|m4a)$' | sed \"s/^/'/;s/$/'/\" | tr '\n' ',' | sed 's/,$//'")
    ]) as filename
) files;

-- Show summary
SELECT mood, COUNT(*) as track_count FROM music_library GROUP BY mood ORDER BY mood;

ENDSQL
ENDSSH

echo -e "${GREEN}✓ Database populated${NC}"
echo ""

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              ✓ UPLOAD COMPLETED SUCCESSFULLY                 ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BLUE}📝 Summary:${NC}"
echo "  - Music files uploaded to: $REMOTE_MUSIC_DIR"
echo "  - Database table populated: music_library"
echo "  - Total tracks: $TOTAL"
echo "  - Total size: $TOTAL_SIZE"
echo ""

echo -e "${BLUE}🎵 Music is ready for video rendering!${NC}"
echo ""
echo "Next steps:"
echo "1. Test music selection in n8n"
echo "2. Import remaining workflows"
echo "3. Start generating advertutorials!"
echo ""
