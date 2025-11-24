# Youtube Transcriptor

Extracts YouTube auto-captions and outputs them as a single blob of plain text - ideal for feeding into AI/LLMs for summarization, analysis, or Q&A.

## What It Does

1. Downloads English auto-captions from a YouTube video (via yt-dlp)
2. Strips all SRT formatting (line numbers, timestamps, blank lines)
3. Collapses everything into one continuous text blob
4. Saves to a timestamped .txt file

The output is intentionally unformatted - just raw text ready to paste into ChatGPT, Claude, Ollama, or whatever LLM you're working with.

## Dependencies

- **Perl 5.10+** (Term::ANSIColor included in core)
- **yt-dlp** - `brew install yt-dlp` or `apt install yt-dlp`

## Usage
```bash
./youtube-transcriptor "https://www.youtube.com/watch?v=VIDEO_ID"
```

Output: `1234567890.txt` (Unix timestamp as filename)

## License

WTFPL - Do What The F*** You Want To Public License
