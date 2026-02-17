---
name: gemini-deep-research
description: Perform complex, long-running research tasks using Gemini Deep Research Agent. Use when asked to research topics requiring multi-source synthesis, competitive analysis, market research, or comprehensive technical investigations that benefit from systematic web search and analysis.
metadata: {"clawdbot":{"emoji":"🔬","requires":{"env":["GEMINI_API_KEY"]},"primaryEnv":"GEMINI_API_KEY"}}
---

# Gemini Deep Research

Use Gemini's Deep Research Agent to perform complex, long-running context gathering and synthesis tasks.

## Prerequisites

- `GEMINI_API_KEY` environment variable (from Google AI Studio)

## How It Works

Deep Research is an agent that:
1. Breaks down complex queries into sub-questions
2. Searches the web systematically
3. Synthesizes findings into comprehensive reports
4. Provides streaming progress updates

## Usage

### Basic Research

```bash
scripts/deep_research.py --query "Research the history of Google TPUs"
```

(When `GEMINI_DEEP_RESEARCH_DRIVE_FOLDER_ID` is set, results are backed up to that Drive folder automatically.)

### Custom Output Format

```bash
scripts/deep_research.py --query "Research the competitive landscape of EV batteries" \
  --format "1. Executive Summary\n2. Key Players (include data table)\n3. Supply Chain Risks"
```

### With File Search (optional)

```bash
scripts/deep_research.py --query "Compare our 2025 fiscal year report against current public web news" \
  --file-search-store "fileSearchStores/my-store-name"
```

### Stream Progress

```bash
scripts/deep_research.py --query "Your research topic" --stream
```

## Output

The script saves results in a dedicated directory (default: `deep-research/` relative to the current working directory, or set `GEMINI_DEEP_RESEARCH_OUTPUT_DIR` to override). Files are timestamped:
- `deep-research-YYYY-MM-DD-HH-MM-SS.md` - Final report in markdown
- `deep-research-YYYY-MM-DD-HH-MM-SS.json` - Full interaction metadata

## Google Drive backup

When `GEMINI_DEEP_RESEARCH_DRIVE_FOLDER_ID` is set, the script uploads both the .md and .json to that Drive folder after saving locally (via the gog CLI). The script prints the folder URL so you can tell the user where the backup is. To skip upload for a single run, pass `--no-drive-upload`.

## API Details

- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/interactions`
- **Agent**: `deep-research-pro-preview-12-2025`
- **Auth**: `x-goog-api-key` header (NOT OAuth Bearer token)

## Limitations

- Requires Gemini API key (get from [Google AI Studio](https://aistudio.google.com/apikey))
- Does NOT work with Antigravity OAuth authentication
- Long-running tasks (minutes to hours depending on complexity)
- May incur API costs depending on your quota
