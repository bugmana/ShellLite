"""Enforce the core test budget from Flutter's JSON test report."""

import json
import sys
from pathlib import Path

MAX_CORE_TESTS = 48  # Two additional browser checks keep the total at 50.

events = [
    json.loads(line)
    for line in Path(sys.argv[1]).read_text().splitlines()
    if line.strip()
]
finished = {
    event["testID"]
    for event in events
    if event.get("type") == "testDone" and not event.get("hidden", False)
}
if not any(event.get("type") == "done" and event.get("success") for event in events):
    sys.exit("Test budget requires a successful, complete Flutter test report.")
if not finished or len(finished) > MAX_CORE_TESTS:
    sys.exit(f"Core test budget exceeded or empty: {len(finished)}/{MAX_CORE_TESTS}.")
print(
    f"Core test budget: {len(finished)}/{MAX_CORE_TESTS}; "
    "2 slots reserved for browser checks (50 maximum)."
)
