#!/usr/bin/env python3
"""
Tutorial Bot - Advanced Testing Script
Genera video e monitora il processo di rendering
"""

import requests
import json
import time
import sys
from datetime import datetime

# Configurazione
N8N_URL = "http://localhost:5678"  # Modifica con il tuo URL
WEBHOOK_PATH = "/webhook/generate-tutorial"
SHOTSTACK_API_KEY = "your-shotstack-key"  # Dalla tua .env
SHOTSTACK_ENV = "sandbox"  # o "production"

def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")

def print_step(step, text):
    print(f"[{step}] {text}")

def trigger_generation(topic, style="cinematic editorial", duration=45):
    """Triggera la generazione del video"""
    print_step("1/5", "Triggering video generation...")
    
    payload = {
        "topic": topic,
        "style": style,
        "duration": duration
    }
    
    print(f"  Topic: {topic}")
    print(f"  Style: {style}")
    print(f"  Duration: {duration}s\n")
    
    try:
        response = requests.post(
            f"{N8N_URL}{WEBHOOK_PATH}",
            json=payload,
            timeout=300  # 5 min timeout
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")
        return None

def check_render_status(render_id):
    """Controlla lo status del rendering su Shotstack"""
    if not SHOTSTACK_API_KEY or SHOTSTACK_API_KEY == "your-shotstack-key":
        print("⚠️  Shotstack API key not configured, skipping status check")
        return None
    
    print_step("2/5", "Checking render status...")
    
    url = f"https://api.shotstack.io/{SHOTSTACK_ENV}/render/{render_id}"
    headers = {
        "x-api-key": SHOTSTACK_API_KEY,
        "Content-Type": "application/json"
    }
    
    max_attempts = 60  # 5 min max
    attempt = 0
    
    while attempt < max_attempts:
        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            status = data.get("response", {}).get("status")
            
            if status == "done":
                print(f"✅ Rendering complete!")
                return data
            elif status == "failed":
                print(f"❌ Rendering failed!")
                print(f"   Error: {data.get('response', {}).get('error')}")
                return data
            elif status in ["queued", "rendering"]:
                progress = data.get("response", {}).get("progress", 0)
                print(f"  ⏳ Status: {status} - Progress: {progress}%", end='\r')
                time.sleep(5)
                attempt += 1
            else:
                print(f"  Status: {status}")
                time.sleep(5)
                attempt += 1
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Error checking status: {e}")
            return None
    
    print("\n⚠️  Timeout waiting for render")
    return None

def download_video(url, filename):
    """Download del video finale"""
    print_step("3/5", "Downloading video...")
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        with open(filename, 'wb') as f:
            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        progress = (downloaded / total_size) * 100
                        print(f"  Progress: {progress:.1f}%", end='\r')
        
        print(f"\n✅ Video saved: {filename}")
        return True
    except Exception as e:
        print(f"❌ Download error: {e}")
        return False

def analyze_output(result):
    """Analizza il risultato e mostra statistiche"""
    print_step("4/5", "Analyzing output...")
    
    if not result:
        print("❌ No result to analyze")
        return
    
    print(f"  Status: {result.get('status', 'unknown')}")
    print(f"  Render ID: {result.get('render_id', 'N/A')}")
    print(f"  Video URL: {result.get('video_url', 'N/A')}")
    
    if 'response' in result:
        response = result['response']
        print(f"  Duration: {response.get('duration', 'N/A')}s")
        print(f"  Size: {response.get('size', 'N/A')} bytes")

def main():
    print_header("AI Tutorial Video Generator - Test Suite")
    
    # Esempi di test
    test_cases = [
        {
            "name": "Portrait Photography",
            "topic": "professional portrait photography techniques",
            "style": "cinematic editorial",
            "duration": 45
        },
        {
            "name": "Product Photography",
            "topic": "luxury watch photography with reflections",
            "style": "commercial advertising",
            "duration": 50
        },
        {
            "name": "Fashion Editorial",
            "topic": "high fashion editorial with motion",
            "style": "vogue magazine style",
            "duration": 60
        }
    ]
    
    print("Available test cases:")
    for i, test in enumerate(test_cases, 1):
        print(f"  {i}. {test['name']} ({test['duration']}s)")
    
    print(f"  0. Custom input")
    
    choice = input("\nSelect test case (0-3): ").strip()
    
    if choice == "0":
        topic = input("Topic: ").strip()
        style = input("Style (default: cinematic editorial): ").strip() or "cinematic editorial"
        duration = int(input("Duration in seconds (default: 45): ").strip() or "45")
        test_name = "Custom"
    elif choice in ["1", "2", "3"]:
        test = test_cases[int(choice) - 1]
        topic = test["topic"]
        style = test["style"]
        duration = test["duration"]
        test_name = test["name"]
    else:
        print("Invalid choice")
        return
    
    print_header(f"Generating: {test_name}")
    
    # Step 1: Trigger generation
    start_time = datetime.now()
    result = trigger_generation(topic, style, duration)
    
    if not result:
        print("❌ Generation failed")
        return
    
    print(f"\n✅ Generation triggered successfully")
    render_id = result.get("render_id")
    video_url = result.get("video_url")
    
    # Step 2: Monitor rendering (if Shotstack key is configured)
    if render_id:
        status_data = check_render_status(render_id)
        if status_data:
            video_url = status_data.get("response", {}).get("url", video_url)
    
    # Step 3: Download video (optional)
    if video_url and video_url != "N/A":
        download_choice = input("\nDownload video? (y/n): ").strip().lower()
        if download_choice == 'y':
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"tutorial_{test_name.replace(' ', '_')}_{timestamp}.mp4"
            download_video(video_url, filename)
    
    # Step 4: Summary
    end_time = datetime.now()
    duration_total = (end_time - start_time).total_seconds()
    
    print_header("Summary")
    print(f"  Test: {test_name}")
    print(f"  Total time: {duration_total:.1f}s")
    print(f"  Video URL: {video_url}")
    print(f"  Render ID: {render_id}")
    
    print_step("5/5", "Test completed! ✅")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
