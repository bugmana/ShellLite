"""Exercise saved server profiles through the deployed Flutter UI; never connect."""

import argparse
import os
import re
from pathlib import Path
from uuid import uuid4

from playwright.sync_api import expect, sync_playwright


def run(url, artifacts, mobile):
    artifacts.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=os.environ.get("CHROMIUM_EXECUTABLE") or None
        )
        context = browser.new_context(
            viewport={"width": 390 if mobile else 1280, "height": 844 if mobile else 900},
            is_mobile=mobile,
            has_touch=mobile,
            service_workers="block",
        )
        # Fail closed if any UI action unexpectedly attempts an SSH connection.
        sockets = []
        def block_socket(socket):
            sockets.append(socket.url)
            socket.close()

        context.route_web_socket("**/*", block_socket)
        context.tracing.start(screenshots=True, snapshots=True, sources=True)
        page = context.new_page()
        ui = page.locator("flt-semantics-host")
        page.set_default_timeout(20000)
        name = f"UI smoke {uuid4().hex[:8]}"
        card = page.get_by_role("button", name=re.compile("^" + re.escape(name) + r"\s"))

        def load():
            page.goto(url, wait_until="domcontentloaded")
            # Flutter's documented accessibility opt-in exposes semantic DOM controls.
            page.locator("flt-semantics-placeholder").evaluate("element => element.click()")

        def type_field(label, value):
            field = page.get_by_role(
                "textbox", name=re.compile(r"^" + re.escape(label) + r"(?:\s|$)")
            )
            field.click()
            page.keyboard.type(value, delay=40)
            page.keyboard.press("Tab")
            expect(field).to_have_value(value)

        try:
            load()
            expect(page.get_by_role("button", name=re.compile("^Add server"))).to_have_count(1)
            page.get_by_role("button", name="Add server", exact=True).click()
            page.get_by_role("button", name="Save", exact=True).click()
            expect(ui.get_by_text("Host is required", exact=True)).to_be_visible()
            type_field("Host", "192.0.2.1")
            type_field("Username", "smoke-test")
            type_field("Password", "dummy-test-only")
            expect(ui.get_by_text("Host is required", exact=True)).to_have_count(0)
            expect(ui.get_by_text("Username is required", exact=True)).to_have_count(0)
            expect(ui.get_by_text("Password is required", exact=True)).to_have_count(0)
            page.get_by_role("button", name="Clear password", exact=True).click()
            expect(ui.get_by_text("Password is required", exact=True)).to_be_visible()
            type_field("Password", "dummy-test-only")
            # Invalid submission already expands the advanced fields.
            type_field("Name (optional)", name)
            page.get_by_role("switch", name=re.compile("^Persistent Session")).click()
            type_field("Session Name", "smoke-session")
            type_field("Startup command", "pwd")
            page.get_by_role("button", name="Save", exact=True).click()
            expect(card).to_be_visible()

            load()
            expect(card).to_be_visible()
            page.get_by_role("button", name="Server options", exact=True).click()
            page.get_by_role("menuitem", name="Edit", exact=True).click()
            page.get_by_role("button", name="More options", exact=True).click()
            expect(page.get_by_role("switch", name=re.compile("^Persistent Session"))).to_be_checked()
            for label, value in [
                ("Name (optional)", name),
                ("Session Name", "smoke-session"),
                ("Startup command", "pwd"),
            ]:
                field = page.get_by_role(
                    "textbox", name=re.compile("^" + re.escape(label) + r"(?:\s|$)")
                )
                # Flutter synchronizes the DOM input value when the field gets focus.
                field.click()
                expect(field).to_have_value(value)
                page.keyboard.press("Tab")
            page.get_by_role("button", name="Save", exact=True).click()
            page.get_by_role("button", name="Server options", exact=True).click()
            page.get_by_role("menuitem", name="Delete", exact=True).click()
            page.get_by_role("button", name="Delete", exact=True).click()
            expect(card).to_have_count(0)
            load()
            expect(ui.get_by_text("No servers yet", exact=False)).to_be_visible()
            assert not sockets, f"Unexpected WebSocket attempts: {sockets}"
            print(f"PASS: {'mobile' if mobile else 'desktop'} create/reload/edit/delete; no connections")
        except Exception:
            page.screenshot(path=str(artifacts / "failure.png"), full_page=True)
            (artifacts / "semantics.txt").write_text(page.locator("body").aria_snapshot())
            raise
        finally:
            context.tracing.stop(path=str(artifacts / "trace.zip"))
            context.close()
            browser.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="https://shell.strandberg.dev")
    parser.add_argument("--artifacts", type=Path, default=Path("build/web-smoke"))
    parser.add_argument("--mobile", action="store_true")
    args = parser.parse_args()
    run(args.url, args.artifacts, args.mobile)
