#!/usr/bin/env python3
"""
Prepares localized Google Play release notes (whatsnew/whatsnew-en-US)
guaranteeing <= 500 characters, filtering out internal CI/docs/chores,
and avoiding truncation in the middle of sentences or bullet points.
"""

import argparse
import os
import re
import subprocess
import sys


def clean_bullet(line: str) -> str:
    # Strip markdown list marker
    text = line.lstrip("-*• ").strip()
    # Strip trailing commit SHA like (`abcdef1`) or (abcdef1)
    text = re.sub(r' \(`[a-f0-9]+`\)$', '', text)
    text = re.sub(r' \([a-f0-9]+\)$', '', text)
    return text.strip()


def extract_bullets_from_release_body(body: str) -> list[str]:
    bullets = []
    for raw_line in body.splitlines():
        line = raw_line.strip()
        # Stop before download instructions or store asset descriptions
        if (
            line.startswith("### 📦")
            or line.startswith("### Download")
            or line.startswith("## Download")
            or "Download to your device" in line
            or "install via" in line
            or "Access the live" in line
        ):
            break

        if not line or line.startswith("#"):
            continue

        if raw_line.lstrip().startswith(("-", "*", "•")):
            clean = clean_bullet(line)
            # Skip internal commits
            if re.match(r'^(ci|chore|docs|test)(\([^)]+\))*:\s*', clean, re.I):
                continue
            m = re.match(r'^(feat|fix|perf)(?:\(([^)]+)\))?!?: (.+)', clean, re.I)
            if m:
                scope = m.group(2)
                if scope and scope.lower() in ("ci", "chore", "docs", "test", "deps"):
                    continue
                desc = m.group(3).strip()
                desc = desc[0].upper() + desc[1:] if desc else ""
                if scope:
                    scope_fmt = scope.replace('_', ' ').replace('-', ' ').title()
                    bullets.append(f"• {scope_fmt}: {desc}")
                else:
                    bullets.append(f"• {desc}")
            else:
                bullets.append(f"• {clean}")

    return bullets


def limit_to_500_chars(bullets: list[str]) -> str:
    if not bullets:
        return "• Performance improvements and bug fixes."

    selected = []
    cur_len = 0
    for b in bullets:
        additional = len(b) + (1 if selected else 0)
        if cur_len + additional <= 500:
            selected.append(b)
            cur_len += additional
        else:
            break

    if not selected:
        return "• Performance improvements and bug fixes."

    return "\n".join(selected)


def main():
    parser = argparse.ArgumentParser(description="Prepare Google Play release notes.")
    parser.add_argument("--tag", help="GitHub release tag to extract notes from", default="")
    parser.add_argument("--custom", help="Custom notes to use directly", default="")
    parser.add_argument(
        "--output",
        help="Target output file path",
        default="whatsnew/whatsnew-en-US",
    )
    args = parser.parse_args()

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)

    if args.custom and args.custom.strip():
        # Validate custom notes <= 500 chars
        content = args.custom.strip()
        if len(content) > 500:
            lines = content.splitlines()
            trimmed = []
            cur = 0
            for line in lines:
                add = len(line) + (1 if trimmed else 0)
                if cur + add <= 500:
                    trimmed.append(line)
                    cur += add
                else:
                    break
            content = "\n".join(trimmed) if trimmed else content[:500]
    else:
        body = ""
        if args.tag:
            try:
                body = subprocess.check_output(
                    ["gh", "release", "view", args.tag, "--json", "body", "-q", ".body"]
                ).decode("utf-8", errors="replace")
            except Exception as e:
                print(f"Warning: Failed to fetch release body for {args.tag}: {e}", file=sys.stderr)

        bullets = extract_bullets_from_release_body(body)
        content = limit_to_500_chars(bullets)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(content + "\n")

    print(f"==> Generated {len(content)} chars in {args.output}:")
    print(content)


if __name__ == "__main__":
    main()
