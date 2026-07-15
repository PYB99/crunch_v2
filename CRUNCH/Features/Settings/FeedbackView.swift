import SwiftUI
import MessageUI
import UIKit

// TODO: switch to a dedicated support@ alias once configured. Placeholder for
// beta — change this one constant, no surrounding UI needs to move.
private let feedbackRecipient = "prakashbhagat2006@gmail.com"
private let feedbackSubject = "Crunch Feedback"

// Version-stamped body. Auto-included but user-editable (not hidden): it seeds
// both the Mail composer and the copy-to-clipboard fallback.
private func feedbackBodyTemplate() -> String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    let iosVersion = UIDevice.current.systemVersion
    return """


    ———
    App version: \(version) (\(build))
    iOS: \(iosVersion)
    """
}

// MARK: - View

struct FeedbackView: View {
    @State private var showMailComposer = false
    @State private var fallbackBody = feedbackBodyTemplate()
    @State private var didCopy = false

    private var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    var body: some View {
        List {
            Section {
                Text("Found a bug or have an idea? We'd love to hear it.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            if canSendMail {
                Section {
                    Button {
                        showMailComposer = true
                    } label: {
                        Text("Send Feedback")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 44)
                    }
                    .listRowBackground(Theme.card)
                } footer: {
                    Text("Opens Mail with your app and device details attached so we can help faster.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                // Fallback: no mail account configured. Copy the same info to the
                // clipboard with instructions to email it manually.
                Section("Your feedback") {
                    TextEditor(text: $fallbackBody)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .listRowBackground(Theme.card)
                }

                Section {
                    Button {
                        copyToClipboard()
                    } label: {
                        Text(didCopy ? "Copied" : "Copy to Clipboard")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 44)
                    }
                    .listRowBackground(Theme.card)
                } footer: {
                    Text("No mail account is set up on this device. Copy your feedback, then email it to \(feedbackRecipient) with the subject “\(feedbackSubject)”.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipient: feedbackRecipient,
                subject: feedbackSubject,
                body: feedbackBodyTemplate()
            )
            .ignoresSafeArea()
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string =
            "To: \(feedbackRecipient)\nSubject: \(feedbackSubject)\n\(fallbackBody)"
        didCopy = true
    }
}

// MARK: - Mail composer bridge

private struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
