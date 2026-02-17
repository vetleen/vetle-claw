#!/usr/bin/env python3
"""
Gemini Deep Research API client
Performs complex, long-running research tasks via Gemini's Deep Research Agent.

API docs: https://ai.google.dev/gemini-api/docs/deep-research
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
import requests

API_BASE = "https://generativelanguage.googleapis.com/v1beta"
AGENT_MODEL = "deep-research-pro-preview-12-2025"


def create_interaction(api_key, query, output_format=None, file_search_store=None):
    """Start a new deep research interaction"""
    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": api_key
    }
    
    payload = {
        "input": query,
        "agent": AGENT_MODEL,
        "background": True
    }
    
    if output_format:
        payload["input"] = f"{query}\n\nFormat the output as follows:\n{output_format}"
    
    if file_search_store:
        payload["tools"] = [{
            "type": "file_search",
            "file_search_store_names": [file_search_store]
        }]
    
    response = requests.post(
        f"{API_BASE}/interactions",
        headers=headers,
        json=payload
    )
    
    if response.status_code != 200:
        print(f"Error creating interaction: {response.status_code}", file=sys.stderr)
        print(response.text, file=sys.stderr)
        sys.exit(1)
    
    return response.json()


def _format_interaction_error(data):
    """Extract a readable error message from interaction data (status=failed)."""
    if not isinstance(data, dict):
        return str(data)
    # Common shapes: error (str), error.message, error.code, message
    err = data.get("error")
    if isinstance(err, str) and err.strip():
        return err
    if isinstance(err, dict):
        msg = err.get("message") or err.get("msg") or err.get("detail")
        if isinstance(msg, str) and msg.strip():
            code = err.get("code")
            return f"{msg}" if not code else f"[{code}] {msg}"
        if err:
            return json.dumps(err)
    msg = data.get("message")
    if isinstance(msg, str) and msg.strip():
        return msg
    return json.dumps(data) if data else "Unknown error"


def poll_interaction(api_key, interaction_id, stream=False):
    """Poll for interaction updates"""
    headers = {
        "x-goog-api-key": api_key
    }
    
    while True:
        response = requests.get(
            f"{API_BASE}/interactions/{interaction_id}",
            headers=headers
        )
        
        if response.status_code != 200:
            print(f"Error polling interaction: {response.status_code}", file=sys.stderr)
            print(response.text, file=sys.stderr)
            sys.exit(1)
        
        data = response.json()
        status = data.get("status", "UNKNOWN")
        
        if stream:
            # Show progress updates
            if "statusMessage" in data:
                print(f"[{status}] {data['statusMessage']}", file=sys.stderr)
        
        if status == "completed":
            return data
        elif status == "failed":
            err_msg = _format_interaction_error(data)
            print(f"Research failed: {err_msg}", file=sys.stderr)
            sys.exit(1)
        
        time.sleep(10)  # Poll every 10 seconds


def clean_report_text(text: str) -> str:
    """Normalize extracted report text for .md: escape sequences, unicode, BOM, line endings."""
    if not text or not isinstance(text, str):
        return text or ""
    if text.startswith("\ufeff"):
        text = text[1:]
    text = text.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    text = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), text)
    text = re.sub(r"\\U([0-9a-fA-F]{8})", lambda m: chr(int(m.group(1), 16)), text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return text


def _text_from(obj):
    """Get report text from an object: dict with 'text' or 'output', or string."""
    if obj is None:
        return None
    if isinstance(obj, str) and obj.strip():
        return obj
    if isinstance(obj, dict):
        if "text" in obj and isinstance(obj["text"], str) and obj["text"].strip():
            return obj["text"]
        if "output" in obj:
            return _text_from(obj["output"])
    return None


def extract_report(interaction_data):
    """Extract the final report from interaction data. Tries output, outputs[], top-level text, then messages."""
    if not isinstance(interaction_data, dict):
        return None

    # 1. Singular "output"
    if "output" in interaction_data:
        out = _text_from(interaction_data["output"])
        if out:
            return out

    # 2. Plural "outputs" (e.g. list; take last as usually the final report)
    if "outputs" in interaction_data:
        outputs = interaction_data["outputs"]
        if isinstance(outputs, list):
            for item in reversed(outputs):
                out = _text_from(item)
                if out:
                    return out

    # 3. Top-level "text"
    if "text" in interaction_data:
        t = interaction_data["text"]
        if isinstance(t, str) and t.strip():
            return t

    # 4. Messages fallback
    messages = interaction_data.get("messages", [])
    for msg in reversed(messages):
        if msg.get("role") == "model" and "parts" in msg:
            for part in msg["parts"]:
                if "text" in part and isinstance(part["text"], str) and part["text"].strip():
                    return part["text"]

    return None


def upload_to_drive(file_path: Path, folder_id: str) -> bool:
    """Upload a file to Google Drive via gog. Returns True on success."""
    try:
        result = subprocess.run(
            ["gog", "drive", "upload", str(file_path), "--parent", folder_id],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            print(f"Drive upload failed for {file_path.name}: {result.stderr or result.stdout}", file=sys.stderr)
            return False
        return True
    except FileNotFoundError:
        print("gog not found; install gog and authorize Drive to enable upload.", file=sys.stderr)
        return False
    except subprocess.TimeoutExpired:
        print(f"Drive upload timed out for {file_path.name}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Drive upload error for {file_path.name}: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Gemini Deep Research API Client")
    parser.add_argument("--query", required=True, help="Research query")
    parser.add_argument("--format", help="Custom output format instructions")
    parser.add_argument("--file-search-store", help="File search store name (optional)")
    parser.add_argument("--stream", action="store_true", help="Show streaming progress updates")
    parser.add_argument(
        "--output-dir",
        default=os.environ.get("GEMINI_DEEP_RESEARCH_OUTPUT_DIR", "deep-research"),
        help="Output directory for results (default: deep-research, or GEMINI_DEEP_RESEARCH_OUTPUT_DIR)",
    )
    parser.add_argument("--api-key", help="Gemini API key (overrides GEMINI_API_KEY env var)")
    parser.add_argument("--drive-upload", action="store_true", help="Upload .md and .json to Google Drive (default when GEMINI_DEEP_RESEARCH_DRIVE_FOLDER_ID is set)")
    parser.add_argument("--no-drive-upload", action="store_true", help="Skip Drive upload even if folder ID is set")
    parser.add_argument("--drive-folder-id", help="Drive folder ID (or set GEMINI_DEEP_RESEARCH_DRIVE_FOLDER_ID)")
    args = parser.parse_args()
    
    # Get API key
    api_key = args.api_key or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: No API key provided.", file=sys.stderr)
        print("Please either:", file=sys.stderr)
        print("  1. Provide --api-key argument", file=sys.stderr)
        print("  2. Set GEMINI_API_KEY environment variable", file=sys.stderr)
        sys.exit(1)
    
    # Start research
    print(f"Starting deep research: {args.query}", file=sys.stderr)
    interaction = create_interaction(
        api_key,
        args.query,
        output_format=args.format,
        file_search_store=args.file_search_store
    )
    
    interaction_id = interaction.get("id")
    if not interaction_id:
        print(f"Error: No interaction ID in response: {interaction}", file=sys.stderr)
        sys.exit(1)
    print(f"Interaction started: {interaction_id}", file=sys.stderr)
    
    # Poll for completion
    print("Polling for results (this may take several minutes)...", file=sys.stderr)
    result = poll_interaction(api_key, interaction_id, stream=args.stream)
    
    # Extract report
    report = extract_report(result)
    
    if not report:
        print("Warning: Could not extract report text from response", file=sys.stderr)
        report = json.dumps(result, indent=2)
    else:
        report = clean_report_text(report)
    
    # Save results
    timestamp = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    md_path = output_dir / f"deep-research-{timestamp}.md"
    json_path = output_dir / f"deep-research-{timestamp}.json"
    
    md_path.write_text(report)
    json_path.write_text(json.dumps(result, indent=2))
    
    print(f"\nResearch complete!", file=sys.stderr)
    print(f"Report saved: {md_path}", file=sys.stderr)
    print(f"Full data saved: {json_path}", file=sys.stderr)

    folder_id = args.drive_folder_id or os.environ.get("GEMINI_DEEP_RESEARCH_DRIVE_FOLDER_ID")
    do_upload = not args.no_drive_upload and (args.drive_upload or folder_id)
    if do_upload and folder_id:
        uploaded = 0
        for path in (md_path, json_path):
            if upload_to_drive(path, folder_id):
                print(f"Uploaded to Drive: {path.name}", file=sys.stderr)
                uploaded += 1
        if uploaded > 0:
            drive_url = f"https://drive.google.com/drive/folders/{folder_id}?usp=drive_link"
            print(f"Backed up to Google Drive: {drive_url}")
    elif do_upload and not folder_id:
        print("Drive upload skipped: set GEMINI_DEEP_RESEARCH_DRIVE_FOLDER_ID or --drive-folder-id", file=sys.stderr)

    # Do not print the full report to stdout by default.
    # The report is saved to disk; printing it can unnecessarily flood logs/contexts.
    return


if __name__ == "__main__":
    main()
