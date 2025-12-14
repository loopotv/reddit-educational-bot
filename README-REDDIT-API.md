# AI Tutorial Video Generator - Reddit Research Bot

Educational content creation system that monitors Reddit for trending AI image generation techniques and transforms them into short-form educational videos.

## Purpose

This bot helps bridge the gap between Reddit's detailed AI art communities and social media audiences by:
- Identifying trending AI prompting techniques from educational subreddits
- Creating accessible 30-60 second tutorial videos for TikTok/Instagram
- Providing proper attribution to original Reddit posts and authors
- Driving traffic back to Reddit communities

## Reddit API Usage

**Access Type:** Read-only
**API Calls:** ~16 requests per day (once daily)
**Subreddits Monitored:** r/StableDiffusion, r/midjourney, r/ChatGPT, r/OpenAI, r/PromptEngineering, and related AI communities

### What the Bot Does:
- ✅ Fetches hot posts from AI-related subreddits (public data only)
- ✅ Analyzes posts for educational prompting techniques
- ✅ Stores trending topics for content creation
- ✅ Attributes original authors in generated videos

### What the Bot Does NOT Do:
- ❌ Post comments or submissions
- ❌ Send direct messages
- ❌ Vote on posts
- ❌ Perform any write operations
- ❌ Scrape user data or personal information

## Architecture

**Platform:** n8n workflow automation
**Deployment:** Self-hosted on VPS
**Database:** PostgreSQL for trend tracking

### Workflow Pipeline:

```
Daily Schedule (9 AM)
    ↓
Fetch Hot Posts (Reddit API - read-only)
    ↓
AI Analysis (Extract techniques)
    ↓
Store in Database
    ↓
Human Approval (via Telegram)
    ↓
Generate Educational Video
    ↓
Publish to TikTok/Instagram with Reddit attribution
```

## Data Privacy

- **Data Collected:** Only public post titles, content, and URLs
- **Data Usage:** Educational content creation only
- **Data Retention:** 90 days for trend analysis
- **User Privacy:** No personal data, private messages, or user profiles collected
- **Attribution:** All videos link back to original Reddit posts

## Technology Stack

- **Workflow Engine:** n8n
- **AI Processing:** Groq (Llama 3.3 70B) for script generation
- **Video Production:** FFmpeg for assembly
- **Text-to-Speech:** Wavespeed AI (MiniMax Speech-02 HD)
- **Image Generation:** Wavespeed AI (FLUX-dev)
- **Database:** PostgreSQL
- **Approvals:** Telegram Bot API

## API Rate Limits Compliance

- Daily requests: 16 (well within Reddit's 60 req/min limit)
- Requests are distributed throughout the day
- No parallel/concurrent requests
- Respectful of Reddit's infrastructure
- User-Agent properly identifies the bot

## Educational Mission

The goal is to make advanced AI image generation techniques accessible to beginners by:
1. Curating high-quality educational content from Reddit
2. Transforming technical discussions into visual tutorials
3. Crediting original creators and communities
4. Encouraging viewers to join Reddit communities for deeper learning

## Example Output

**Input:** Reddit post about CTLT prompting method
**Output:** 45-second TikTok video explaining:
- What CTLT stands for (Camera, Tone, Light, Texture)
- Before/after prompt examples
- Link to original Reddit post
- Credit to original author

## Contact

**Developer:** Alessandro Brunello
**Email:** abrunello@gmail.com
**Platform:** VIVID.ai

## License

Educational use only. All Reddit content is used in accordance with Reddit's Terms of Service and API guidelines with proper attribution to original authors.

---

**Note:** This repository contains n8n workflow configurations. Sensitive credentials (API keys, passwords) are stored in environment variables and never committed to version control.
