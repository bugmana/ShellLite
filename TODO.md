# ShellLite — Development & Roadmap TODO

## 🎯 Current Milestone: VM Setup & UI Flow Testing

- [ ] **VM Environment Setup**:
  - [ ] Clone repo onto development VM: `git clone https://github.com/bugmana/ShellLite.git`
  - [ ] Run live web development server:
    ```bash
    flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
    ```
- [ ] **UI / UX Flow Validation**:
  - [ ] Server creation & form validation (Host, Port, User, Password vs SSH Key).
  - [ ] OpenSSH private key parser validation on live input.
  - [ ] Search filtering and empty state transitions.
  - [ ] Keyboard accessory bar touch actions and hotkeys.
  - [ ] Dark theme contrast and layout responsiveness.

---

## 🔮 Next Milestones

- [ ] **Native Linux Desktop Testing**:
  - [ ] Install native GTK build tools (`sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev`).
  - [ ] Run `flutter run -d linux` for end-to-end SSH socket connection tests.
- [ ] **SSH Terminal Enhancements**:
  - [ ] Test interactive sessions with `htop`, `tmux`, and `vim`.
  - [ ] Verify dynamic window resize events (`SIGWINCH`).
- [ ] **iOS Production Packaging**:
  - [ ] Trigger manual release via GitHub Actions `workflow_dispatch`.
  - [ ] Sideload and test `ShellLite.ipa` on physical iOS devices via SideStore / Sideloadly.
