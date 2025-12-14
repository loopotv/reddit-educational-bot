#!/usr/bin/env python3
"""
Populate music_library database table from filesystem
"""

import subprocess
import json

print("🎵 Populating Music Library Database...")
print("")

# Get list of music files from VPS
result = subprocess.run([
    'ssh', 'contabo',
    'find /var/www/music -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" \) -printf "%p|%f\\n"'
], capture_output=True, text=True)

files = result.stdout.strip().split('\n')

# Organize by mood
music_by_mood = {
    'energetic': [],
    'calm': [],
    'dramatic': [],
    'inspirational': []
}

for line in files:
    if '|' not in line:
        continue

    filepath, filename = line.split('|')

    for mood in music_by_mood.keys():
        if f'/{mood}/' in filepath:
            track_name = filename.rsplit('.', 1)[0]  # Remove extension
            music_by_mood[mood].append({
                'filename': filename,
                'track_name': track_name,
                'path': filepath
            })
            break

# Print summary
print("📊 Found tracks:")
for mood, tracks in music_by_mood.items():
    print(f"  {mood}: {len(tracks)} tracks")
print("")

# Generate SQL
sql_statements = ["-- Clear existing entries", "TRUNCATE TABLE music_library;", ""]

genre_map = {
    'energetic': 'electronic',
    'calm': 'ambient',
    'dramatic': 'cinematic',
    'inspirational': 'uplifting'
}

for mood, tracks in music_by_mood.items():
    for track in tracks:
        # Escape single quotes in track name
        safe_track_name = track['track_name'].replace("'", "''")
        safe_filename = track['filename'].replace("'", "''")

        sql = f"""INSERT INTO music_library (motion_array_id, track_name, genre, mood, local_path, last_synced)
VALUES (md5('{safe_filename}'), '{safe_track_name}', '{genre_map[mood]}', '{mood}', '{track['path']}', NOW());"""

        sql_statements.append(sql)

# Add summary query
sql_statements.extend([
    "",
    "-- Show summary",
    "SELECT mood, COUNT(*) as track_count FROM music_library GROUP BY mood ORDER BY mood;"
])

# Write SQL to file
sql_content = '\n'.join(sql_statements)

# Upload and execute SQL on VPS
print("💾 Generating SQL...")
with open('/tmp/populate_music.sql', 'w') as f:
    f.write(sql_content)

print("📤 Uploading to VPS...")
subprocess.run(['scp', '/tmp/populate_music.sql', 'contabo:/tmp/'], check=True)

print("🗄️ Executing SQL in database...")
result = subprocess.run([
    'ssh', 'contabo',
    'docker exec -i postgres psql -U n8n -d n8n < /tmp/populate_music.sql'
], capture_output=True, text=True)

print(result.stdout)

if result.returncode == 0:
    print("")
    print("✅ Music library database populated successfully!")
    print("")

    # Get total count
    count_result = subprocess.run([
        'ssh', 'contabo',
        'docker exec -i postgres psql -U n8n -d n8n -t -c "SELECT COUNT(*) FROM music_library;"'
    ], capture_output=True, text=True)

    total = count_result.stdout.strip()
    print(f"📊 Total tracks in database: {total}")
else:
    print("❌ Error executing SQL:")
    print(result.stderr)
