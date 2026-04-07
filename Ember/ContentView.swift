// ContentView.swift
// Ember — Group Coordination Platform
//
// ============================================================
// WHAT EMBER IS NOW
// ============================================================
// Ember is a conversational coordination platform for groups.
//
// Two surfaces:
//   Social groups — friends booking reservations, planning
//   events, coordinating logistics via conversation + SMS
//
//   Organizations — teams collaborating, negotiating,
//   managing documents, tracking decisions
//
// Agent persona: organization leader.
// Empathetic and action-oriented.
// Always resolves a situation.
// Never leaves a thread open.
// ============================================================

import SwiftUI
import Contacts
import MessageUI
import Speech
import AVFoundation

// ============================================================
// LESSON: struct Message
// Blueprint for one chat bubble.
// isDraft: true = Ember wrote this to send via SMS.
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
// Only the three fields we need.
// ============================================================
struct Contact: Identifiable {
    let id: String
    let name: String
    let phone: String
}

// ============================================================
// LESSON: Group — a named collection of circle members
// Groups are how Ember handles coordination for multiple
// people at once. A group can be "Saturday dinner crew"
// or "Q2 product team" — same data model, different context.
// ============================================================
struct EmberGroup: Identifiable, Codable {
    let id: String
    var name: String
    var memberIDs: [String]
    var context: String       // What this group is about
    var lastActivity: Date
    var groupType: GroupType

    init(id: String = UUID().uuidString,
         name: String,
         memberIDs: [String] = [],
         context: String = "",
         groupType: GroupType = .social) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.context = context
        self.lastActivity = Date()
        self.groupType = groupType
    }
}

enum GroupType: String, Codable, CaseIterable {
    case social       = "social"         // Friends, family, social planning
    case organization = "organization"   // Teams, companies, professional

    var icon: String {
        switch self {
        case .social:       return "person.3"
        case .organization: return "building.2"
        }
    }

    var label: String {
        switch self {
        case .social:       return "Social"
        case .organization: return "Organization"
        }
    }
}

// ============================================================
// MAIN VIEW
// ============================================================

struct ContentView: View {

    @State private var messages: [Message] = [
        Message(text: "What needs to get done?", isFromUser: false)
    ]
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var showingContactPicker: Bool = false
    @State private var showingCircle: Bool = false
    @State private var showingDocuments: Bool = false
    @State private var contacts: [Contact] = []
    @State private var selectedContact: CircleMember? = nil
    @State private var selectedGroup: EmberGroup? = nil
    @State private var showingComposer: Bool = false
    @State private var draftedMessage: String = ""

    // ============================================================
    // LESSON: @StateObject for persistent stores
    // Each store owns one domain of data.
    // CircleStore: individual people
    // DocumentStore: uploaded documents
    // VoiceInputManager: microphone and transcription
    // ============================================================
    @StateObject private var circleStore = CircleStore()
    @StateObject private var documentStore = DocumentStore()
    @StateObject private var voiceManager = VoiceInputManager()

    let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar

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
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        .onAppear {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .authorized { loadContacts() }
        }
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
                            text: "Couldn't send. Try again?",
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
                // People / circle toggle
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

                // Documents toggle
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

                // Add contact
                Button { requestContactsAndShow() } label: {
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
                // ============================================================
                // Group context header
                // Shows the active group at top of circle view.
                // Ember coordinates between people in the group.
                // ============================================================
                if let group = selectedGroup {
                    GroupContextBar(group: group) {
                        selectedGroup = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }

                if circleStore.members.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(
                                Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.3)
                            )
                            .padding(.top, 60)
                        Text("No one here yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                        Text("Tap + to add people.\nEmber coordinates between them.")
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
                    // Active person bar
                    if let person = selectedContact {
                        ActivePersonBar(
                            member: person,
                            onDismiss: { selectedContact = nil },
                            onDraft: { draftMessageFor(person) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // Active document banner
                    if let doc = documentStore.activeDocument {
                        ActiveDocumentBanner(document: doc) {
                            documentStore.activeDocument = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, selectedContact == nil ? 8 : 4)
                    }

                    // Voice listening indicator
                    if voiceManager.isListening {
                        VoiceListeningBanner()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
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
            // Quick-access pill strip
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
                // LESSON: Single input field for text and voice
                // Voice transcription feeds the same TextField as typing.
                // One field. Two input methods. Same send action.
                // The .onChange syncs voiceManager.transcribedText
                // into inputText as the user speaks.
                // ============================================================
                TextField("What needs to get done?", text: $inputText, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .onSubmit { sendMessage() }
                    .onChange(of: voiceManager.transcribedText) { newText in
                        if voiceManager.isListening {
                            inputText = newText
                        }
                    }

                // ============================================================
                // LESSON: Mic button with pulse animation
                // Red pulsing when active — clear signal to the user
                // that the microphone is live and recording.
                // Purple mic when idle — matches the app's visual language.
                // ============================================================
                Button {
                    if voiceManager.isListening {
                        voiceManager.stopListening()
                    } else {
                        voiceManager.requestPermissions { granted in
                            if granted {
                                voiceManager.startListening()
                            } else {
                                messages.append(Message(
                                    text: "To use voice, go to Settings → Ember → allow Microphone and Speech Recognition.",
                                    isFromUser: false
                                ))
                            }
                        }
                    }
                } label: {
                    Image(systemName: voiceManager.isListening
                          ? "stop.circle.fill"
                          : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(voiceManager.isListening
                                         ? .red
                                         : Color(red: 0.5, green: 0.47, blue: 0.87))
                        .scaleEffect(voiceManager.isListening ? 1.15 : 1.0)
                        .animation(
                            voiceManager.isListening
                                ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                                : .spring(),
                            value: voiceManager.isListening
                        )
                }

                // Send button
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

    func draftMessageFor(_ member: CircleMember) {
        isThinking = true
        Task {
            let memory = buildMemoryContext(for: member)
            let prompt = """
                Draft a short, direct message from the user to \(member.name).
                \(memory)
                Rules:
                - Sound like a decisive leader, not an app
                - Reference the specific situation if context exists
                - One or two sentences maximum
                - Action-oriented — move something forward
                - Do not start with "Hey"
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
                The user is focusing on \(member.name).
                \(memory)
                As an action-oriented organization leader:
                acknowledge who this person is and immediately
                ask what needs to happen with them right now.
                Be direct and warm. Two sentences maximum.
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
                \(member.name) was just added to the user's group coordination platform.
                As an action-oriented organization leader, welcome this
                and immediately ask: what's the active situation with \(member.name)
                that needs to be resolved?
                Warm but direct. Two sentences maximum.
                """
            let reply = await askClaude(prompt, history: messages)
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    // ============================================================
    // LESSON: Context assembly — the core of the agent
    // All stored context assembles into plain English for Claude.
    // The agent persona is set in askClaude's system prompt.
    // Context here feeds specificity. Persona drives behavior.
    // ============================================================
    func buildMemoryContext(for member: CircleMember) -> String {
        var parts: [String] = []
        if !member.lastConnectedDescription.isEmpty {
            parts.append("Last interaction: \(member.lastConnectedDescription)")
        }
        if !member.sharedContext.isEmpty {
            parts.append("Background: \(member.sharedContext)")
        }
        if !member.currentContext.isEmpty {
            parts.append("Current situation: \(member.currentContext)")
        }
        parts.append("Status: \(member.driftLevel.rawValue)")
        return parts.isEmpty
            ? "No context yet on this person."
            : parts.joined(separator: ". ")
    }

    func buildCircleContext() -> String {
        guard !circleStore.members.isEmpty else { return "" }
        let names = circleStore.members.map { $0.firstName }.joined(separator: ", ")
        return "People in this coordination group: \(names)."
    }

    func buildGroupContext() -> String {
        guard let group = selectedGroup else { return "" }
        return """
            Active group: \(group.name) (\(group.groupType.label))
            Group context: \(group.context.isEmpty ? "No context set." : group.context)
            """
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
                        text: "To see contacts, go to Settings → Ember → allow Contacts.",
                        isFromUser: false
                    ))
                }
            }
        }
    }

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
        if voiceManager.isListening { voiceManager.stopListening() }
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
    // LESSON: Agent persona via system prompt
    // The system prompt defines who Ember IS in this conversation.
    // Changing the system prompt changes the entire personality,
    // communication style, and decision-making approach.
    //
    // Ember is now an organization leader:
    //   - Empathetic: understands people and situations
    //   - Action-oriented: always moves toward resolution
    //   - Resolves situations: never leaves threads open
    //
    // This persona works for both social coordination
    // (planning dinner with friends) and organizational use
    // (managing a negotiation or project decision).
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
        let groupContext = buildGroupContext()
        let documentContext = documentStore.buildDocumentContext()

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 500,
            "system": """
                You are Ember — an organization leader embedded in a group coordination platform.

                YOUR PERSONA:
                Empathetic and action-oriented. You read situations accurately,
                understand what people need, and always move toward resolution.
                You never leave a situation open. Every response either resolves
                something, advances it, or names exactly what needs to happen next.

                YOUR USERS:
                Social groups coordinating events, reservations, and plans.
                Organizations collaborating, negotiating, and managing documents.
                You serve both. The tone shifts to match — warmer for social,
                more precise for organizational — but the resolve is always the same.

                YOUR RULES:
                - Always be specific. Name the action, the person, the next step.
                - Never say "reach out", "touch base", or "circle back".
                - Never leave a situation without a proposed resolution.
                - Be brief. Two to three sentences unless a document requires more.
                - When document context is provided, answer from it precisely.
                - When coordinating a group, name who needs to do what.

                CONTEXT:
                \(circleContext)
                \(personContext)
                \(groupContext)
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
// GROUP CONTEXT BAR
// Shows the active group at top of circle view.
// ============================================================
struct GroupContextBar: View {
    let group: EmberGroup
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.groupType.icon)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
            Text(group.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
            if !group.context.isEmpty {
                Text("· \(group.context)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
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
// VOICE LISTENING BANNER
// Shows in the conversation while the mic is active.
// Animated dots signal that Ember is hearing the user.
// ============================================================
struct VoiceListeningBanner: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 3, height: animating ? 14 : 6)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .frame(height: 16)

            Text("Listening...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear { animating = true }
    }
}

// ============================================================
// ACTIVE DOCUMENT BANNER
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
                    Text("Tap to coordinate")
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
        .confirmationDialog(
            "Remove \(member.firstName)?",
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
            Text("Coordinating with \(member.firstName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
            if !member.lastConnectedDescription.isEmpty {
                Text("· \(member.lastConnectedDescription)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
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
            .navigationTitle("Add to group")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ============================================================
// MESSAGE BUBBLE
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
