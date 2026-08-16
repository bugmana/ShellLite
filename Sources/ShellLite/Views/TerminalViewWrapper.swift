#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import ShellLiteCore

/// SwiftUI bridge to the UIKit-based terminal view controller.
public struct TerminalViewWrapper: UIViewControllerRepresentable {
    public let profile: ServerProfile

    public init(profile: ServerProfile) {
        self.profile = profile
    }

    public func makeUIViewController(context: Context) -> TerminalViewController {
        TerminalViewController(profile: profile)
    }

    public func updateUIViewController(_ vc: TerminalViewController, context: Context) {
        // No dynamic updates needed — session lifecycle is owned by the VC.
    }
}

// MARK: - TerminalViewController

/// Full-screen SSH terminal with inline editing.
///
/// Output from the server is displayed in terminal green. The user types at the
/// bottom of the view after the `▶ ` prompt; pressing Return sends the command
/// via a new SSH exec channel. The Up/Down accessory bar keys cycle in-memory
/// command history. All text above the current input line is read-only.
@MainActor
public final class TerminalViewController: UIViewController {

    // MARK: - Properties

    private let profile: ServerProfile
    private let session = SSHSession()

    // MARK: Terminal view

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable    = true
        tv.isSelectable  = true
        tv.font          = Self.baseFont
        tv.backgroundColor = UIColor(white: 0.05, alpha: 1)
        tv.autocorrectionType     = .no
        tv.autocapitalizationType = .none
        tv.spellCheckingType      = .no
        tv.smartDashesType        = .no
        tv.smartQuotesType        = .no
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        return tv
    }()

    private lazy var accessoryBar: KeyboardAccessoryBar = {
        let bar = KeyboardAccessoryBar()
        bar.onKeyTap = { [weak self] key in
            guard let self else { return }
            switch key.label {
            case "↑": self.cycleHistory(direction: .up)
            case "↓": self.cycleHistory(direction: .down)
            default:
                Task { await self.session.sendInput(Data(key.sequence.utf8)) }
            }
        }
        return bar
    }()

    // MARK: Input state

    /// UTF-16 offset where the editable input region begins (right after `▶ `).
    private var inputStart: Int = 0
    /// In-memory command history, newest entry first.
    private var commandHistory: [String] = []
    /// Current position while cycling history. `-1` = composing a new command.
    private var historyIndex: Int = -1
    /// Saved draft while cycling through history.
    private var historyDraft: String = ""

    // MARK: Scroll

    private var isScrolledToBottom: Bool = true

    // MARK: Style constants

    private static let baseFont    = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let outputColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.85)
    private static let statusColor = UIColor.secondaryLabel
    private static let inputColor  = UIColor.white
    private static let promptColor = UIColor.systemYellow.withAlphaComponent(0.6)
    private static let errorColor  = UIColor.systemOrange

    // MARK: - Init

    public init(profile: ServerProfile) {
        self.profile = profile
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = profile.displayName
        view.backgroundColor = UIColor(white: 0.05, alpha: 1)

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        textView.inputAccessoryView = accessoryBar
        Task { await startSession() }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Task { await session.disconnect() }
    }

    // MARK: - SSH Session

    private func startSession() async {
        appendText(
            "Connecting to \(profile.username)@\(profile.host):\(profile.port)…\n",
            color: Self.statusColor
        )
        do {
            let auth: SSHAuth
            switch profile.authMethod {
            case .password(let tag):
                let password = try KeychainManager.shared.retrieve(for: tag)
                auth = .password(username: profile.username, password: password)
            case .sshKey(let tag):
                let pem = try KeychainManager.shared.retrieve(for: tag)
                let key = try parseOpenSSHPrivateKey(pem)
                auth = .sshKey(username: profile.username, privateKey: key)
            }
            try await session.connect(host: profile.host, port: profile.port, auth: auth)
            appendText("Connected.\n", color: Self.statusColor)
            appendPrompt()

            // Auto-run the initial command if the profile has one configured.
            if let cmd = profile.initialCommand, !cmd.isEmpty {
                replaceInputText(cmd)
                sendCurrentCommand()
            }
        } catch {
            appendText("⚠️ \(error.localizedDescription)\n", color: Self.errorColor)
        }
    }

    /// Runs `command` via SSH exec and streams each output line into the terminal.
    private func runCommand(_ command: String) async {
        do {
            let stream = try await session.execute(command)
            for try await chunk in stream {
                appendText(chunk + "\n", color: Self.outputColor)
            }
        } catch {
            appendText("⚠️ \(error.localizedDescription)\n", color: Self.errorColor)
        }
        appendPrompt()
    }

    // MARK: - Input Handling

    /// Reads the current input region, dispatches the command, and resets for
    /// the next one.
    private func sendCurrentCommand() {
        let cmd = inputText().trimmingCharacters(in: .whitespaces)

        // Append a newline to visually close the input line.
        appendText("\n", color: Self.inputColor)
        // Advance inputStart so everything above becomes read-only.
        inputStart = textView.textStorage.length

        guard !cmd.isEmpty else {
            appendPrompt()
            return
        }

        // Dedup consecutive identical entries.
        if commandHistory.first != cmd { commandHistory.insert(cmd, at: 0) }
        historyIndex = -1
        historyDraft = ""

        Task { await runCommand(cmd) }
    }

    /// Returns the text the user has typed in the current input region.
    /// Uses NSString for safe UTF-16 offset arithmetic.
    private func inputText() -> String {
        let ns = textView.textStorage.string as NSString
        guard inputStart < ns.length else { return "" }
        return ns.substring(from: inputStart)
    }

    // MARK: - History

    private enum HistoryDirection { case up, down }

    private func cycleHistory(direction: HistoryDirection) {
        switch direction {
        case .up:
            if historyIndex == -1 { historyDraft = inputText() }
            let next = historyIndex + 1
            guard next < commandHistory.count else { return }
            historyIndex = next
            replaceInputText(commandHistory[historyIndex])

        case .down:
            guard historyIndex > -1 else { return }
            historyIndex -= 1
            replaceInputText(historyIndex == -1 ? historyDraft : commandHistory[historyIndex])
        }
    }

    /// Replaces everything after the prompt with `text`, styled as input.
    private func replaceInputText(_ text: String) {
        let storage = textView.textStorage
        let range = NSRange(location: inputStart, length: storage.length - inputStart)
        storage.replaceCharacters(
            in: range,
            with: NSAttributedString(string: text, attributes: inputAttributes())
        )
        textView.selectedRange = NSRange(location: storage.length, length: 0)
        scrollToBottomIfNeeded()
    }

    // MARK: - Display

    /// Appends styled `text` to the text storage. Always on the main actor.
    private func appendText(_ text: String, color: UIColor) {
        textView.textStorage.append(
            NSAttributedString(
                string: text,
                attributes: [.foregroundColor: color, .font: Self.baseFont]
            )
        )
        scrollToBottomIfNeeded()
    }

    /// Appends the `▶ ` prompt and records the new `inputStart`.
    private func appendPrompt() {
        textView.textStorage.append(
            NSAttributedString(
                string: "▶ ",
                attributes: [.foregroundColor: Self.promptColor, .font: Self.baseFont]
            )
        )
        inputStart = textView.textStorage.length
        textView.selectedRange = NSRange(location: inputStart, length: 0)
        scrollToBottomIfNeeded()
    }

    private func inputAttributes() -> [NSAttributedString.Key: Any] {
        [.foregroundColor: Self.inputColor, .font: Self.baseFont]
    }

    // MARK: - Scroll

    private func scrollToBottomIfNeeded() {
        guard isScrolledToBottom else { return }
        let end = NSRange(location: textView.textStorage.length, length: 0)
        textView.scrollRangeToVisible(end)
    }
}

// MARK: - UITextViewDelegate

extension TerminalViewController: UITextViewDelegate {

    public func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        // Reject edits that start before the read-only output region.
        guard range.location >= inputStart else { return false }

        // Intercept Return — send the command ourselves.
        if text == "\n" {
            sendCurrentCommand()
            return false
        }

        // Block multi-line paste.
        if text.contains("\n") { return false }

        return true
    }

    public func textViewDidChange(_ textView: UITextView) {
        // Re-apply white colour to the input region after user edits.
        // (The system may reset it after autocorrect or paste.)
        let len = textView.textStorage.length
        guard inputStart < len else { return }
        textView.textStorage.addAttributes(
            inputAttributes(),
            range: NSRange(location: inputStart, length: len - inputStart)
        )
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        // If the user taps in the read-only output region, snap cursor to end.
        guard let sel = textView.selectedTextRange else { return }
        let offset = textView.offset(from: textView.beginningOfDocument, to: sel.start)
        if offset < inputStart {
            let end = textView.endOfDocument
            textView.selectedTextRange = textView.textRange(from: end, to: end)
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let distFromBottom = scrollView.contentSize.height
                           - scrollView.contentOffset.y
                           - scrollView.bounds.height
        isScrolledToBottom = distFromBottom < 60
    }
}
#endif
