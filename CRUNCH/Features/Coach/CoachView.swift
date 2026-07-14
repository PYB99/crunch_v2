import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
final class CoachViewModel {

    // MARK: State

    var messages: [CoachMessage] = []
    var conversationId: UUID?     = nil
    var isLoadingHistory          = true
    var isTyping                  = false
    var loadError: String?        = nil
    var sendError: String?        = nil
    var failedInputText: String?  = nil
    var isOffline                 = false
    var isCooldown                = false

    // MARK: Derived

    var sections: [MessageSection] {
        let calendar = Calendar.current
        let grouped  = Dictionary(grouping: messages) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted().map { date in
            MessageSection(
                date: date,
                messages: grouped[date]!.sorted { $0.createdAt < $1.createdAt }
            )
        }
    }

    private static let sectionFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return Self.sectionFormatter.string(from: date)
    }

    // MARK: Load history

    func loadHistory() async {
        isLoadingHistory = true
        loadError        = nil
        defer { isLoadingHistory = false }

        do {
            guard let (conv, msgs) = try await AnthropicService.loadLatestConversationWithMessages() else {
                return
            }
            conversationId = conv.id
            messages       = msgs
        } catch {
            loadError = "Couldn't load messages. Tap to retry."
        }
    }

    // Push-notification deep link. Falls back to the latest conversation if
    // the id isn't found (e.g. a transient RLS/read hiccup) rather than
    // leaving Coach stuck on a load error for a tap that should just work.
    func loadConversation(id: UUID) async {
        isLoadingHistory = true
        loadError        = nil
        defer { isLoadingHistory = false }

        do {
            guard let (conv, msgs) = try await AnthropicService.loadConversation(id: id) else {
                await loadHistory()
                return
            }
            conversationId = conv.id
            messages       = msgs
        } catch {
            loadError = "Couldn't load messages. Tap to retry."
        }
    }

    // MARK: Send message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCooldown, !isOffline else { return }

        sendError       = nil
        failedInputText = nil

        // Optimistic user message (temp ID; real one saved by Edge Function)
        let tempId      = UUID()
        let tempConvId  = conversationId ?? UUID()
        let optimistic  = CoachMessage(
            id: tempId, conversationId: tempConvId,
            userId: "", role: .user,
            content: trimmed, createdAt: Date()
        )
        messages.append(optimistic)
        isTyping   = true
        isCooldown = true

        MixpanelService.track(.coachMessageSent(isPostRun: false))

        do {
            let token  = try await ClerkService.currentToken()
            let result = try await AnthropicService.coachRespond(
                conversationId: conversationId,
                userMessage:    trimmed,
                clerkToken:     token
            )
            conversationId = result.conversationId
            isTyping       = false
            messages.append(result.assistantMessage)
        } catch let err as NSError
            where err.domain == NSURLErrorDomain
               && err.code   == NSURLErrorNotConnectedToInternet
        {
            isTyping        = false
            isOffline       = true
            sendError       = "You're offline. Reconnect to send."
            failedInputText = trimmed
            messages.removeAll { $0.id == tempId }
        } catch {
            isTyping        = false
            sendError       = "Something went wrong."
            failedInputText = trimmed
            messages.removeAll { $0.id == tempId }
        }

        // 2-second send cooldown
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Constants.coachSendCooldownSeconds))
            self?.isCooldown = false
        }
    }

    func retryLastMessage() async {
        guard let text = failedInputText else { return }
        isOffline = false
        sendError = nil
        await sendMessage(text)
    }
}

// MARK: - Section model

struct MessageSection: Identifiable {
    let date:     Date
    let messages: [CoachMessage]
    var id:       Date { date }
}

// MARK: - CoachView

struct CoachView: View {
    @State private var viewModel = CoachViewModel()
    @State private var inputText = ""
    @State private var showSettings = false
    @Environment(AppRouter.self) private var router

    private let bottomAnchor = "coachBottom"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversationArea
                CoachInputView(
                    text:       $inputText,
                    isDisabled: viewModel.isTyping || viewModel.isCooldown,
                    isOffline:  viewModel.isOffline,
                    onSend:     sendTapped
                )
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Coach")
                        .font(Theme.subheading)
                        .foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .task {
            if let pendingId = router.pendingCoachConversationId {
                await viewModel.loadConversation(id: pendingId)
                router.pendingCoachConversationId = nil
            } else {
                await viewModel.loadHistory()
            }
        }
        .onChange(of: router.pendingCoachConversationId) { _, newValue in
            guard let newValue else { return }
            Task {
                await viewModel.loadConversation(id: newValue)
                router.pendingCoachConversationId = nil
            }
        }
    }

    // MARK: Conversation area

    @ViewBuilder
    private var conversationArea: some View {
        if viewModel.isLoadingHistory {
            loadingView
        } else if let error = viewModel.loadError {
            errorLoadView(error)
        } else if viewModel.messages.isEmpty && viewModel.sendError == nil {
            emptyStateView
        } else {
            messagesScrollView
        }
    }

    // MARK: Loading skeleton

    private var loadingView: some View {
        VStack(spacing: Theme.md) {
            skeletonBubble(width: 200, role: .assistant)
            skeletonBubble(width: 140, role: .user)
            skeletonBubble(width: 220, role: .assistant)
            Spacer()
        }
        .padding(.top, Theme.lg)
    }

    private func skeletonBubble(width: CGFloat, role: CoachMessage.MessageRole) -> some View {
        HStack {
            if role == .user { Spacer() }
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.card)
                .frame(width: width, height: 44)
                .padding(.horizontal, Theme.md)
            if role == .assistant { Spacer() }
        }
    }

    // MARK: Load error

    private func errorLoadView(_ message: String) -> some View {
        VStack(spacing: Theme.md) {
            Spacer()
            ErrorBanner(message: message) {
                Task { await viewModel.loadHistory() }
            }
            .padding(.horizontal, Theme.md)
            Spacer()
        }
    }

    // MARK: Empty state

    private var emptyStateView: some View {
        VStack(spacing: Theme.lg) {
            Spacer()
            VStack(spacing: Theme.sm) {
                Text("Hey! I'm your Crunch coach")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Ask me anything about fueling for your race.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.lg)

            VStack(spacing: Theme.sm) {
                chipButton("What should I eat today?")
                chipButton("Explain carb loading")
                chipButton("Help me plan race day nutrition")
            }
            .padding(.horizontal, Theme.md)

            Spacer()
        }
    }

    private func chipButton(_ label: String) -> some View {
        Button {
            inputText = label
            sendTapped()
        } label: {
            Text(label)
                .font(Theme.body)
                .foregroundStyle(Theme.brand)
                .padding(.horizontal, Theme.md)
                .padding(.vertical, Theme.sm)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.pillRadius)
                        .strokeBorder(Theme.brand.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius))
        }
    }

    // MARK: Messages scroll view

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sections) { section in
                        dateSectionHeader(viewModel.sectionTitle(for: section.date))
                        ForEach(section.messages) { message in
                            CoachMessageView(message: message)
                        }
                    }

                    if viewModel.isTyping {
                        TypingIndicatorView()
                    }

                    if let _ = viewModel.sendError {
                        ErrorCoachBubble {
                            Task { await viewModel.retryLastMessage() }
                        }
                    }

                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(.top, Theme.sm)
            }
            .onChange(of: viewModel.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: viewModel.isTyping)       { _, v in if v { scrollToBottom(proxy) } }
            .onChange(of: viewModel.sendError)      { _, v in if v != nil { scrollToBottom(proxy) } }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
        }
    }

    private func dateSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.caption)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.sm)
    }

    // MARK: Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    private func sendTapped() {
        let text = inputText
        inputText = ""
        Task { await viewModel.sendMessage(text) }
    }
}

// MARK: - Preview

#Preview("Empty state") {
    CoachView()
        .environment(AppRouter.shared)
}
