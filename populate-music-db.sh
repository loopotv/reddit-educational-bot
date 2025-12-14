#!/bin/bash

################################################################################
# Populate Music Library Database
# Simple script to add existing music files to the database
################################################################################

set -e

echo "🎵 Populating Music Library Database..."
echo ""

# Run on VPS
ssh contabo << 'ENDSSH'

# Get list of files and create SQL
cd /var/www/music

echo "📊 Found tracks:"
for mood in energetic calm dramatic inspirational; do
    count=$(ls -1 $mood/*.{mp3,wav,m4a} 2>/dev/null | wc -l)
    echo "  $mood: $count tracks"
done
echo ""

# Create SQL file
cat > /tmp/populate_music.sql << 'EOSQL'
-- Clear existing entries
TRUNCATE TABLE music_library;

-- Populate from filesystem
EOSQL

# Add energetic tracks
echo "Processing energetic tracks..."
for file in energetic/*.{mp3,wav,m4a} 2>/dev/null; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        trackname="${filename%.*}"
        echo "INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path, last_synced) VALUES (md5('$filename'), '$trackname', 'electronic', 'energetic', '/var/www/music/$file', NOW());" >> /tmp/populate_music.sql
    fi
done

# Add calm tracks
echo "Processing calm tracks..."
for file in calm/*.{mp3,wav,m4a} 2>/dev/null; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        trackname="${filename%.*}"
        echo "INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path, last_synced) VALUES (md5('$filename'), '$trackname', 'ambient', 'calm', '/var/www/music/$file', NOW());" >> /tmp/populate_music.sql
    fi
done

# Add dramatic tracks
echo "Processing dramatic tracks..."
for file in dramatic/*.{mp3,wav,m4a} 2>/dev/null; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        trackname="${filename%.*}"
        echo "INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path, last_synced) VALUES (md5('$filename'), '$trackname', 'cinematic', 'dramatic', '/var/www/music/$file', NOW());" >> /tmp/populate_music.sql
    fi
done

# Add inspirational tracks
echo "Processing inspirational tracks..."
for file in inspirational/*.{mp3,wav,m4a} 2>/dev/null; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        trackname="${filename%.*}"
        echo "INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path, last_synced) VALUES (md5('$filename'), '$trackname', 'uplifting', 'inspirational', '/var/www/music/$file', NOW());" >> /tmp/populate_music.sql
    fi
done

# Add summary query
cat >> /tmp/populate_music.sql << 'EOSQL'

-- Show summary
SELECT mood, COUNT(*) as track_count FROM music_library GROUP BY mood ORDER BY mood;
EOSQL

echo ""
echo "💾 Executing SQL..."

# Execute SQL
docker exec -i postgres psql -U n8n -d n8n < /tmp/populate_music.sql

echo ""
echo "✅ Music library database populated!"
echo ""

# Show final count
docker exec -i postgres psql -U n8n -d n8n -c "SELECT COUNT(*) as total_tracks FROM music_library;"

ENDSSH

echo ""
echo "🎉 Done!"
