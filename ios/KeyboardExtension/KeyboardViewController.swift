import UIKit

/// Teclado personalizado: escribe un prompt, pregunta al modelo del usuario
/// (proveedor espejado en el App Group) e inserta la respuesta en cualquier app.
class KeyboardViewController: UIInputViewController {
    private let promptField = UITextField()
    private let responseView = UITextView()
    private let askButton = UIButton(type: .system)
    private let insertButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var busy = false

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let nextButton = UIButton(type: .system)
        nextButton.setTitle("🌐", for: .normal)
        nextButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        promptField.placeholder = "Ask your model…"
        promptField.borderStyle = .roundedRect
        promptField.returnKeyType = .send
        promptField.addTarget(self, action: #selector(ask), for: .editingDidEndOnExit)

        askButton.setTitle("Ask", for: .normal)
        askButton.addTarget(self, action: #selector(ask), for: .touchUpInside)

        responseView.isEditable = false
        responseView.font = .systemFont(ofSize: 14)
        responseView.backgroundColor = .secondarySystemBackground
        responseView.layer.cornerRadius = 8

        insertButton.setTitle("Insert", for: .normal)
        insertButton.addTarget(self, action: #selector(insert), for: .touchUpInside)
        insertButton.isEnabled = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 2

        let topRow = UIStackView(arrangedSubviews: [promptField, askButton, nextButton])
        topRow.axis = .horizontal
        topRow.spacing = 6
        let bottomRow = UIStackView(arrangedSubviews: [statusLabel, insertButton])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 6
        let stack = UIStackView(arrangedSubviews: [topRow, responseView, bottomRow])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            responseView.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            view.heightAnchor.constraint(equalToConstant: 240),
        ])
    }

    @objc private func ask() {
        guard !busy else { return }
        let prompt = (promptField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard let provider = KeyboardShared.load() else {
            statusLabel.text = "Enable the AI Keyboard in Open Pilot Settings first."
            return
        }
        busy = true
        askButton.isEnabled = false
        statusLabel.text = "Asking \(provider.name)…"
        Task { @MainActor in
            do {
                let text = try await KeyboardChat.complete(provider: provider, prompt: prompt)
                responseView.text = text
                insertButton.isEnabled = true
                statusLabel.text = "Done."
            } catch {
                statusLabel.text = error.localizedDescription
            }
            busy = false
            askButton.isEnabled = true
        }
    }

    @objc private func insert() {
        let text = responseView.text ?? ""
        guard !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
    }
}