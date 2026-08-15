#if canImport(UIKit)
import UIKit

/// A horizontally scrollable input accessory bar with terminal shortcut keys.
///
/// Attach as `textView.inputAccessoryView` on any `UITextView`-based terminal view.
public final class KeyboardAccessoryBar: UIInputView {

    // MARK: - Key Model

    /// A labelled terminal shortcut that emits a raw escape sequence.
    public struct Key: Sendable {
        public let label: String
        /// Raw bytes / escape sequence to send down the SSH channel.
        public let sequence: String

        public init(label: String, sequence: String) {
            self.label = label
            self.sequence = sequence
        }
    }

    /// Default set of terminal navigation shortcuts.
    public static let defaultKeys: [Key] = [
        Key(label: "⇥ Tab",  sequence: "\t"),
        Key(label: "^C",     sequence: "\u{03}"),
        Key(label: "^D",     sequence: "\u{04}"),
        Key(label: "↑",      sequence: "\u{1B}[A"),
        Key(label: "↓",      sequence: "\u{1B}[B"),
        Key(label: "←",      sequence: "\u{1B}[D"),
        Key(label: "→",      sequence: "\u{1B}[C"),
        Key(label: "Esc",    sequence: "\u{1B}"),
        Key(label: "|",      sequence: "|"),
        Key(label: "~",      sequence: "~"),
    ]

    // MARK: - Public Interface

    /// Called whenever the user taps a shortcut key.
    public var onKeyTap: ((Key) -> Void)?

    // MARK: - Init

    public init(keys: [Key] = defaultKeys) {
        let frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        super.init(frame: frame, inputViewStyle: .keyboard)
        buildUI(keys: keys)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Private UI

    private func buildUI(keys: [Key]) {
        backgroundColor = UIColor.systemGroupedBackground

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(
                equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -12),
        ])

        for key in keys {
            stack.addArrangedSubview(makeButton(for: key))
        }
    }

    private func makeButton(for key: Key) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = key.label
        config.cornerStyle = .medium
        config.baseForegroundColor = .label
        config.baseBackgroundColor = UIColor.secondarySystemBackground
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)

        let button = UIButton(configuration: config)
        button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        button.addAction(
            UIAction { [weak self] _ in self?.onKeyTap?(key) },
            for: .touchUpInside
        )
        return button
    }
}
#endif
