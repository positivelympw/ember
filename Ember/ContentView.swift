// ContentView.swift
// Ember — Personal Circle + Document Intelligence + SMS Drafting

import SwiftUI
import Contacts
import MessageUI

// ============================================================
// LESSON: struct Message
// Blueprint for one chat bubble.
// isDraft: true means Ember wrote this to send via SMS —
// it gets a dashed border and a Send via Messages button.
// ============================================================
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    var isDraft: Bool = false
}

// ============================================================
// LESSON: struct Contact
// Lightweight copy of a CNContact from iOS.
// Only the three fields we need — id, name, phone.
// ============================================================
struct Contact: Identifiable {
    let id: String
    let name: String
    let phone: String
}

// ============================================================
// MAIN VIEW
// ============================================================

struct ContentView: View {

    // ============================================================
    // LESSON: @State — local view memory
    // Every @State change triggers a view redraw.
    // Core SwiftUI loop: user acts → state changes → view redraws.
    // ============================================================
    @State private var messages: [Message] = [
        Message(text: "Who's on your mind?", isFromUser: false)
    ]
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var showingContactPicker: Bool = false
    @State private var showingCircle: Bool = false
    @State private var showingDocuments: Bool = false
    @State private var contacts: [Contact] = []
    @State private var selectedContact: CircleMember? = nil
    @State private var showingComposer: Bool = false
    @State private var draftedMessage: String = ""

    // ============================================================
    // LESSON: @StateObject
    // For ObservableObject class instances.
    // Creates once, keeps alive for the life of the view.
    // @State would recreate on every redraw — wrong for classes.
    // ============================================================
    @StateObject private var circleStore = CircleStore()
    @StateObject private var documentStore = DocumentStore()

    // API key loaded securely from Config.xcconfig via Info.plist
    let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            // ============================================================
            // LESSON: Conditional rendering
            // SwiftUI evaluates these flags and renders the matching view.
            // When a flag flips, the view swaps automatically.
            // ============================================================
            if showingCircle {
                circleView
            } else if showingDocuments {
                DocumentView(documentStore: documentStore)
            } else {
                messageList
            }

            Divider()
            inputBar
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.93))
        .ignoresSafeArea(edges: .bottom)
        // Tap anywhere to dismiss keyboard
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        // ============================================================
        // LESSON: .onAppear
        // Runs every time the view appears — launch and foreground.
        // Silently refreshes contacts if permission already granted.
        // ============================================================
        .onAppear {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .authorized {
                loadContacts()
            }
        }
        // Contact picker sheet
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView(
                contacts: contacts,
                circleStore: circleStore,
                onSelect: { contact in
                    showingContactPicker = false
                    handleContactSelected(contact)
                },
                onRefresh: {
                    await withCheckedContinuation { continuation in
                        loadContacts()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            continuation.resume()
                        }
                    }
                }
            )
        }
        // ============================================================
        // LESSON: SMS composer sheet
        // MessageComposerView is a UIViewControllerRepresentable —
        // it wraps Apple's native MFMessageComposeViewController.
        // The user sees a pre-filled Messages draft and taps Send.
        // Ember never sends without explicit user confirmation.
        // ============================================================
        .sheet(isPresented: $showingComposer) {
            if let contact = selectedContact, !contact.phone.isEmpty {
                MessageComposerView(
                    recipient: contact.phone,
                    body: draftedMessage
                ) { result in
                    showingComposer = false
                    switch result {
                    case .sent:
                        messages.append(Message(
                            text: "Sent to \(contact.firstName).",
                            isFromUser: false
                        ))
                    case .cancelled:
                        break
                    case .failed:
                        messages.append(Message(
                            text: "Something went wrong sending. Try again?",
                            isFromUser: false
                        ))
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    // MARK: Header

    var headerBar: some View {
        HStack {
            // Ember logo — three concentric circles
            ZStack {
                Circle()
                    .stroke(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.3), lineWidth: 1)
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.6), lineWidth: 1)
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(Color(red: 0.5, green: 0.47, blue: 0.87))
                    .frame(width: 6, height: 6)
            }

            Text("ember")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))

            Spacer()

            HStack(spacing: 16) {
                // Circle toggle with member count badge
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingCircle.toggle()
                        if showingCircle { showingDocuments = false }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: showingCircle ? "person.2.fill" : "person.2")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                        if !circleStore.members.isEmpty {
                            Text("\(circleStore.members.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color(red: 0.5, green: 0.47, blue: 0.87))
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                // Documents toggle with doc count badge
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingDocuments.toggle()
                        if showingDocuments { showingCircle = false }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: showingDocuments ? "doc.text.fill" : "doc.text")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                        if !documentStore.documents.isEmpty {
                            Text("\(documentStore.documents.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color(red: 0.5, green: 0.47, blue: 0.87))
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                // Add contact button
                Button {
                    requestContactsAndShow()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Circle view

    var circleView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if circleStore.members.isEmpty {
                    // ============================================================
                    // LESSON: Empty state
                    // Never show a blank screen. Guide the user to the action
                    // that fills it. Every list needs an empty state.
                    // ============================================================
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(
                                Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.3)
                            )
                            .padding(.top, 60)
                        Text("Your circle is empty")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                        Text("Tap + to add the people\nEmber pays attention to.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(circleStore.members) { member in
                        CircleMemberRow(
                            member: member,
                            onSelect: {
                                selectedContact = member
                                showingCircle = false
                                emberGreetsMember(member)
                            },
                            onRemove: {
                                circleStore.remove(member)
                                if selectedContact?.id == member.id {
                                    selectedContact = nil
                                }
                            }
                        )
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: Message list

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Active person context bar
                    if let person = selectedContact {
                        ActivePersonBar(
                            member: person,
                            onDismiss: { selectedContact = nil },
                            onDraft: { draftMessageFor(person) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // Active document context bar
                    if let doc = documentStore.activeDocument {
                        ActiveDocumentBanner(document: doc) {
                            documentStore.activeDocument = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, selectedContact == nil ? 8 : 4)
                    }

                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            onSend: message.isDraft ? {
                                draftedMessage = message.text
                                showingComposer = true
                            } : nil
                        )
                    }

                    if isThinking {
                        TypingIndicator().id("typing")
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: isThinking) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    // MARK: Input bar

    var inputBar: some View {
        VStack(spacing: 0) {
            // Quick-access pill strip — circle members
            if !circleStore.members.isEmpty && !showingCircle && !showingDocuments {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(circleStore.members) { member in
                            Button {
                                selectedContact = member
                                emberGreetsMember(member)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(member.driftLevel.color.opacity(0.8))
                                        .frame(width: 7, height: 7)
                                    Text(member.firstName)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedContact?.id == member.id
                                        ? Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.15)
                                        : Color.white
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(red: 0.96, green: 0.95, blue: 0.93))
            }

            HStack(alignment: .bottom, spacing: 10) {
                // ============================================================
                // LESSON: Two ways to send
                // .onSubmit fires on return key press.
                // Button fires on tap. Both call sendMessage().
                // Two paths, one action — good mobile UX.
                // ============================================================
                TextField("Say something...", text: $inputText, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .onSubmit { sendMessage() }

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.4)
                                : Color(red: 0.5, green: 0.47, blue: 0.87)
                        )
                        .animation(.easeInOut(duration: 0.15), value: inputText)
                }
                .disabled(
                    inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 20)
            .background(Color(red: 0.96, green: 0.95, blue: 0.93))
        }
    }

    // MARK: SMS drafting

    // ============================================================
    // LESSON: Drafting with Claude then sending via SMS
    // We ask Claude to write a message using stored memory.
    // The draft appears as a special bubble — dashed border,
    // Send via Messages button underneath.
    // The user reviews and confirms. Ember never sends alone.
    // ============================================================
    func draftMessageFor(_ member: CircleMember) {
        isThinking = true
        Task {
            let memory = buildMemoryContext(for: member)
            let prompt = """
                Draft a short, warm text message from the user to \(member.name).
                \(memory)
                Rules:
                - Sound like a real person, not an app
                - Reference something specific if context exists
                - One or two sentences maximum
                - No emojis unless it feels completely natural
                - Do not start with "Hey" — be more specific
                Return only the message text. Nothing else.
                """
            let draft = await askClaude(prompt, history: [])
            isThinking = false
            messages.append(Message(text: draft, isFromUser: false, isDraft: true))
        }
    }

    // MARK: Contact handling

    func handleContactSelected(_ contact: Contact) {
        if circleStore.isInCircle(contact.id) {
            if let member = circleStore.member(for: contact.id) {
                selectedContact = member
                emberGreetsMember(member)
            }
        } else {
            circleStore.add(contact)
            if let member = circleStore.member(for: contact.id) {
                selectedContact = member
                emberBuildsProfile(member)
            }
        }
    }

    // MARK: Ember conversations

    func emberGreetsMember(_ member: CircleMember) {
        showingCircle = false
        showingDocuments = false
        isThinking = true
        Task {
            let memory = buildMemoryContext(for: member)
            let prompt = """
                The user wants to think about \(member.name).
                \(memory)
                Greet naturally — reference something specific if context
                exists, otherwise ask one warm question.
                Two sentences maximum.
                """
            let reply = await askClaude(prompt, history: messages)
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    func emberBuildsProfile(_ member: CircleMember) {
        showingCircle = false
        showingDocuments = false
        isThinking = true
        Task {
            let prompt = """
                The user just added \(member.name) to their personal circle.
                Welcome this warmly and ask one specific question:
                when did they last connect and what was it about?
                Two sentences. Warm, not clinical.
                """
            let reply = await askClaude(prompt, history: messages)
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    // ============================================================
    // LESSON: Context assembly — the memory-as-interface pattern
    // Everything Ember knows about a person assembles into plain
    // English and goes into the system prompt.
    // More context = more specific and personal the response.
    // No scrolling needed — Ember holds the context.
    // ============================================================
    func buildMemoryContext(for member: CircleMember) -> String {
        var parts: [String] = []
        if !member.lastConnectedDescription.isEmpty {
            parts.append("Last connected: \(member.lastConnectedDescription)")
        }
        if !member.sharedContext.isEmpty {
            parts.append("Shared context: \(member.sharedContext)")
        }
        if !member.currentContext.isEmpty {
            parts.append("What's current: \(member.currentContext)")
        }
        parts.append("Alignment: \(member.driftLevel.rawValue)")
        return parts.isEmpty
            ? "No context yet — first time focusing on this person."
            : parts.joined(separator: ". ")
    }

    func buildCircleContext() -> String {
        guard !circleStore.members.isEmpty else { return "" }
        let names = circleStore.members.map { $0.firstName }.joined(separator: ", ")
        return "The user's personal circle includes: \(names)."
    }

    // MARK: Contacts

    func requestContactsAndShow() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    loadContacts()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showingContactPicker = true
                    }
                } else {
                    messages.append(Message(
                        text: "To see your contacts, go to Settings → Ember → allow Contacts.",
                        isFromUser: false
                    ))
                }
            }
        }
    }

    // ============================================================
    // LESSON: Background thread + main thread update
    // Reading contacts from disk is slow — background thread.
    // UI updates must be on main thread — always.
    // Also syncs circle member names/phones with iOS Contacts
    // so changes the user makes in Contacts show up here.
    // ============================================================
    func loadContacts() {
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var loaded: [Contact] = []

            try? store.enumerateContacts(with: request) { cnContact, _ in
                let fullName = [cnContact.givenName, cnContact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard !fullName.isEmpty else { return }
                let phone = cnContact.phoneNumbers.first?.value.stringValue ?? ""
                loaded.append(Contact(
                    id: cnContact.identifier,
                    name: fullName,
                    phone: phone
                ))
            }

            DispatchQueue.main.async {
                contacts = loaded.sorted { $0.name < $1.name }
                for member in circleStore.members {
                    if let fresh = loaded.first(where: { $0.id == member.id }) {
                        var updated = member
                        updated.name = fresh.name
                        updated.phone = fresh.phone
                        circleStore.update(updated)
                    }
                }
            }
        }
    }

    // MARK: Send message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append(Message(text: text, isFromUser: true))
        inputText = ""
        isThinking = true
        let currentHistory = messages
        Task {
            let reply = await askClaude(text, history: currentHistory)
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    // MARK: Claude API

    // ============================================================
    // LESSON: Dynamic system prompt assembly
    // The system prompt changes on every call based on:
    //   - Who is selected (person context)
    //   - What circle members exist (circle context)
    //   - Which document is active (document context — RAG)
    //
    // This is what makes Ember feel specific, not generic.
    // The same Claude model powers thousands of apps — the
    // system prompt is what makes it feel like Ember.
    // ============================================================
    func askClaude(_ userMessage: String, history: [Message]) async -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let circleContext = buildCircleContext()
        let personContext = selectedContact.map { buildMemoryContext(for: $0) } ?? ""
        let documentContext = documentStore.buildDocumentContext()

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 500,
            "system": """
                You are Ember, a personal relationship agent and document intelligence assistant.
                You help people stay close to the people who matter most to them.
                When document context is provided below, answer questions accurately
                from that document — be specific, reference exact figures and terms.
                If asked about a document and none is active, ask the user to activate one
                from the Documents section (doc icon in the header).
                Be warm, brief, and specific. Two to three sentences maximum.
                Never say 'reach out' or 'touch base'.
                When you suggest something, name it concretely.
                \(circleContext)
                \(personContext)
                \(documentContext)
                """,
            "messages": history.map { msg in
                ["role": msg.isFromUser ? "user" : "assistant",
                 "content": msg.text]
            } + [["role": "user", "content": userMessage]]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request)
        else { return "Something went wrong. Try again?" }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let first = content.first,
            let text = first["text"] as? String
        else { return "Something went wrong. Try again?" }

        return text
    }
}

// ============================================================
// ACTIVE DOCUMENT BANNER
// Shows in the conversation when a document is active.
// Tells the user Ember is reading from that document.
// Dismiss to deactivate.
// ============================================================
struct ActiveDocumentBanner: View {
    let document: EmberDocument
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.documentType.icon)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))

            VStack(alignment: .leading, spacing: 1) {
                Text("Reading \(document.documentType.displayName.lowercased())")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                Text(document.fileName)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.2), lineWidth: 0.5)
        )
    }
}

// ============================================================
// CIRCLE MEMBER ROW
// One person in the circle list.
// Tap to focus Ember on them. Minus to remove with confirmation.
// Drift dot shows alignment status at a glance.
// ============================================================
struct CircleMemberRow: View {
    let member: CircleMember
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var showingConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(member.name.initials)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                Circle()
                    .fill(member.driftLevel.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                if !member.lastConnectedDescription.isEmpty {
                    Text(member.lastConnectedDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else {
                    Text("Tap to start")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.5))
                }
            }

            Spacer()

            Button { showingConfirm = true } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        // ============================================================
        // LESSON: .confirmationDialog
        // Always confirm destructive actions.
        // role: .destructive makes the button red automatically.
        // ============================================================
        .confirmationDialog(
            "Remove \(member.firstName) from your circle?",
            isPresented: $showingConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { onRemove() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// ============================================================
// ACTIVE PERSON BAR
// Shows at top of conversation — who Ember is focused on.
// Draft button opens SMS drafting flow.
// ============================================================
struct ActivePersonBar: View {
    let member: CircleMember
    let onDismiss: () -> Void
    let onDraft: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(member.driftLevel.color.opacity(0.3))
                .frame(width: 8, height: 8)

            Text("Thinking about \(member.firstName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))

            if !member.lastConnectedDescription.isEmpty {
                Text("· \(member.lastConnectedDescription)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Draft button — only if SMS is available on this device
            if MFMessageComposeViewController.canSendText() {
                Button(action: onDraft) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 11))
                        Text("Draft")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// ============================================================
// CONTACT PICKER VIEW
// Slides up as a sheet.
// Search filters in real time. Pull to refresh from iOS Contacts.
// Checkmark on contacts already in circle.
// ============================================================
struct ContactPickerView: View {
    let contacts: [Contact]
    let circleStore: CircleStore
    let onSelect: (Contact) -> Void
    let onRefresh: () async -> Void
    @State private var searchText = ""

    var filtered: [Contact] {
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { contact in
                Button { onSelect(contact) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(contact.name.initials)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                            if !contact.phone.isEmpty {
                                Text(contact.phone)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        if circleStore.isInCircle(contact.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .refreshable { await onRefresh() }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Add to your circle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ============================================================
// MESSAGE BUBBLE
// Purple right = user. White left = Ember.
// Draft bubbles get dashed border + Send via Messages button.
// ============================================================
struct MessageBubble: View {
    let message: Message
    var onSend: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isFromUser {
                Circle()
                    .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .fill(Color(red: 0.5, green: 0.47, blue: 0.87))
                            .frame(width: 8, height: 8)
                    )
            }

            if message.isFromUser { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(
                        message.isFromUser ? .white : Color(red: 0.1, green: 0.1, blue: 0.09)
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromUser
                            ? Color(red: 0.5, green: 0.47, blue: 0.87)
                            : message.isDraft
                                ? Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.06)
                                : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        message.isDraft
                            ? RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1, dash: [4])
                                )
                            : nil
                    )

                // ============================================================
                // LESSON: Conditional Send button
                // Three conditions must all be true:
                //   1. This is a draft bubble
                //   2. onSend closure was passed in
                //   3. This device can send messages
                // All three protect against accidental sends.
                // ============================================================
                if message.isDraft,
                   let onSend,
                   MFMessageComposeViewController.canSendText() {
                    Button(action: onSend) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12))
                            Text("Send via Messages")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.5, green: 0.47, blue: 0.87))
                        .clipShape(Capsule())
                    }
                    .padding(.leading, 4)
                }
            }

            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
}

// ============================================================
// TYPING INDICATOR
// Three dots wave while Ember thinks.
// One @State drives all three — staggered delay creates wave.
// ============================================================
struct TypingIndicator: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.5, green: 0.47, blue: 0.87))
                        .frame(width: 8, height: 8)
                )
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .offset(y: animatingDot == index ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animatingDot
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 60)
        }
        .onAppear { animatingDot = 2 }
    }
}

// ============================================================
// STRING EXTENSION
// .initials and .firstName work on any String in the app.
// One definition, used everywhere — no duplication.
// ============================================================
extension String {
    var initials: String {
        let parts = components(separatedBy: " ").prefix(2)
        return parts.compactMap { $0.first }.map(String.init).joined()
    }

    var firstName: String {
        components(separatedBy: " ").first ?? self
    }
}

#Preview {
    ContentView()
}
