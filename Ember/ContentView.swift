// ContentView.swift
// Ember — Conversational Context Framework v1.0.0-beta
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// The main UI for Ember — the front-end agent surface built
// on the Ember context framework.
//
// The framework: builds context through conversation,
// stores it on-device, persists it across sessions.
//
// This file orchestrates every surface:
//   - Conversation view (main agent interface)
//   - Circle view (individual people)
//   - Groups view (named groups — social or org)
//   - Documents view (Pro — PDF RAG)
//   - Group thread view (group conversation)
//
// ============================================================
// LESSON: AppView enum — making illegal states impossible
// ============================================================
// Instead of multiple booleans (showingCircle, showingGroups,
// showingDocuments) we use one enum. An enum can only be
// ONE value at a time — you can't have showingCircle AND
// showingGroups both true. This is called making illegal
// states unrepresentable. It prevents entire categories of bugs.
//
// Equatable conformance lets us use == comparisons in the UI:
//   currentView == .conversation
//   currentView == .circle
// Without Equatable, Swift can't compare enum values.
//
// The groupThread case carries an associated value (EmberGroup)
// which requires EmberGroup to also be Equatable.
// We implement == on EmberGroup using ID comparison only.
// ============================================================

import SwiftUI
import Contacts
import MessageUI
import Speech
import AVFoundation

// ============================================================
// LESSON: struct Message
// Blueprint for one chat bubble.
// isDraft: true = Ember wrote this as an SMS draft.
// Dashed border + Send via Messages button appears on drafts.
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
// We only extract what we need — id, name, phone.
// CNContact is heavy and complex. This keeps things simple.
// ============================================================
struct Contact: Identifiable {
    let id: String
    let name: String
    let phone: String
}

// ============================================================
// LESSON: AppView — the single source of navigation truth
// ============================================================
enum AppView: Equatable {
    case conversation
    case circle
    case groups
    case documents
    case groupThread(EmberGroup)

    // ============================================================
    // LESSON: Custom Equatable for associated values
    // Swift can auto-synthesize Equatable for simple enums but
    // when a case carries an associated value (EmberGroup here),
    // we need to tell Swift what "equal" means for that case.
    // We compare by group ID — two groupThread cases are equal
    // if they reference the same group.
    // ============================================================
    static func == (lhs: AppView, rhs: AppView) -> Bool {
        switch (lhs, rhs) {
        case (.conversation, .conversation): return true
        case (.circle, .circle):             return true
        case (.groups, .groups):             return true
        case (.documents, .documents):       return true
        case (.groupThread(let a), .groupThread(let b)):
            return a.id == b.id
        default: return false
        }
    }
}

// ============================================================
// MAIN VIEW
// ============================================================

struct ContentView: View {

    @State private var messages: [Message] = [
        Message(text: "What's the situation?", isFromUser: false)
    ]
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var showingContactPicker: Bool = false
    @State private var showingGroupCreator: Bool = false
    @State private var contacts: [Contact] = []
    @State private var selectedContact: CircleMember? = nil
    @State private var selectedGroup: EmberGroup? = nil
    @State private var currentView: AppView = .conversation
    @State private var showingComposer: Bool = false
    @State private var draftedMessage: String = ""
    @State private var showingPaywall: Bool = false
    @State private var logoTapCount: Int = 0
    @State private var showingUnlockConfirm: Bool = false

    // ============================================================
    // LESSON: @StateObject — for ObservableObject class instances
    // Creates the store once and keeps it alive for the app's life.
    // @State would recreate on every redraw — wrong for classes.
    // Each store owns one domain of data.
    // ============================================================
    @StateObject private var circleStore   = CircleStore()
    @StateObject private var groupStore    = GroupStore()
    @StateObject private var documentStore = DocumentStore()
    @StateObject private var voiceManager  = VoiceInputManager()
    @StateObject private var proManager    = ProManager()
    @StateObject private var memoryStore   = MemoryStore()

    let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            mainContent
            Divider()
            inputBar
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
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
        .sheet(isPresented: $showingGroupCreator) {
            GroupCreatorView(circleStore: circleStore) { name, type, memberIDs in
                let group = groupStore.create(name: name, type: type, memberIDs: memberIDs)
                showingGroupCreator = false
                selectedGroup = group
                currentView = .groupThread(group)
                emberGreetsGroup(group)
            }
        }
        .sheet(isPresented: $showingComposer) {
            if let contact = selectedContact, !contact.phone.isEmpty {
                MessageComposerView(
                    recipient: contact.phone,
                    body: draftedMessage
                ) { result in
                    showingComposer = false
                    if case .sent = result {
                        messages.append(Message(
                            text: "Sent to \(contact.firstName).",
                            isFromUser: false
                        ))
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(proManager: proManager)
        }
        .alert("Unlock Pro (Dev Mode)", isPresented: $showingUnlockConfirm) {
            Button("Unlock Pro") {
                proManager.manualUnlock()
                messages.append(Message(text: "Pro unlocked.", isFromUser: false))
            }
            Button("Revoke Pro") {
                proManager.manualRevoke()
                messages.append(Message(text: "Pro revoked.", isFromUser: false))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dev mode — tap Ember logo 5x to toggle Pro without App Store.")
        }
    }

    // MARK: Main content switcher

    @ViewBuilder
    var mainContent: some View {
        switch currentView {
        case .conversation:
            messageList
        case .circle:
            circleView
        case .groups:
            groupsView
        case .documents:
            DocumentView(documentStore: documentStore)
        case .groupThread(let group):
            groupThreadView(group)
        }
    }

    // MARK: Header

    var headerBar: some View {
        HStack {
            // ============================================================
            // LESSON: Hidden dev unlock
            // Tap the logo 5 times quickly to open the manual Pro unlock.
            // Lets you test Pro features without the App Store.
            // Remove before App Store submission or gate with a build flag.
            // ============================================================
            ZStack {
                Circle()
                    .stroke(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.3), lineWidth: 1)
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.6), lineWidth: 1)
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(Color(red: 0.18, green: 0.77, blue: 0.71))
                    .frame(width: 6, height: 6)
            }
            .onTapGesture {
                logoTapCount += 1
                if logoTapCount >= 5 {
                    logoTapCount = 0
                    showingUnlockConfirm = true
                }
            }

            HStack(spacing: 4) {
                Text("ember")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                if proManager.isPro {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.18, green: 0.77, blue: 0.71))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            HStack(spacing: 16) {

                // Conversation
                Button {
                    saveCurrentSessionMemory()
                    selectedContact = nil
                    selectedGroup = nil
                    currentView = .conversation
                } label: {
                    Image(systemName: currentView == .conversation ? "bubble.left.fill" : "bubble.left")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                }

                // Circle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentView = .circle
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: currentView == .circle ? "person.2.fill" : "person.2")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        if !circleStore.members.isEmpty {
                            Text("\(circleStore.members.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color(red: 0.18, green: 0.77, blue: 0.71))
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                // Groups
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentView = .groups
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: currentView == .groups ? "person.3.fill" : "person.3")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        if !groupStore.groups.isEmpty {
                            Text("\(groupStore.groups.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color(red: 0.18, green: 0.77, blue: 0.71))
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                // Documents — Pro gated
                Button {
                    if proManager.isPro {
                        currentView = .documents
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: currentView == .documents ? "doc.text.fill" : "doc.text")
                            .font(.system(size: 20))
                            .foregroundColor(
                                proManager.isPro
                                    ? Color(red: 0.18, green: 0.77, blue: 0.71)
                                    : Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.4)
                            )
                        if !proManager.isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 13, height: 13)
                                .background(Color.gray.opacity(0.5))
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        } else if !documentStore.documents.isEmpty {
                            Text("\(documentStore.documents.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color(red: 0.18, green: 0.77, blue: 0.71))
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                // Add contact
                Button { requestContactsAndShow() } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
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
                    emptyStateView(
                        icon: "person.2",
                        title: "Your circle is empty",
                        message: "Tap + to add the people\nEmber pays attention to."
                    )
                } else {
                    ForEach(circleStore.members) { member in
                        CircleMemberRow(
                            member: member,
                            onSelect: {
                                selectedContact = member
                                currentView = .conversation
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

    // MARK: Groups view

    var groupsView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button {
                    showingGroupCreator = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        }
                        Text("Create a group")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                Divider()

                if groupStore.groups.isEmpty {
                    emptyStateView(
                        icon: "person.3",
                        title: "No groups yet",
                        message: "Create a group to coordinate\nbetween multiple people at once."
                    )
                } else {
                    ForEach(groupStore.groups) { group in
                        GroupRow(
                            group: group,
                            members: group.memberIDs.compactMap { circleStore.member(for: $0) },
                            onSelect: {
                                selectedGroup = group
                                currentView = .groupThread(group)
                                if group.conversationHistory.isEmpty {
                                    emberGreetsGroup(group)
                                }
                            },
                            onDelete: {
                                groupStore.delete(group)
                            }
                        )
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: Group thread view

    func groupThreadView(_ group: EmberGroup) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    GroupThreadHeader(
                        group: group,
                        members: group.memberIDs.compactMap { circleStore.member(for: $0) },
                        onBack: {
                            saveGroupSessionMemory(group)
                            currentView = .groups
                            selectedGroup = nil
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // ============================================================
                    // LESSON: Rendering stored group history
                    // GroupMessage is Codable (for storage).
                    // Message is for the UI.
                    // We map GroupMessage → Message for display only.
                    // Storage and UI concerns stay separate.
                    // ============================================================
                    ForEach(group.conversationHistory) { msg in
                        MessageBubble(
                            message: Message(text: msg.content, isFromUser: msg.isFromUser)
                        )
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message)
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

    // MARK: Message list

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let person = selectedContact {
                        ActivePersonBar(
                            member: person,
                            onDismiss: {
                                saveCurrentSessionMemory()
                                selectedContact = nil
                            },
                            onDraft: { draftMessageFor(person) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    if let doc = documentStore.activeDocument {
                        ActiveDocumentBanner(document: doc) {
                            documentStore.activeDocument = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, selectedContact == nil ? 8 : 4)
                    }

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
            // Quick-access circle pill strip
            if !circleStore.members.isEmpty && currentView == .conversation {
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
                                        .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedContact?.id == member.id
                                        ? Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.15)
                                        : Color.white
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("What's the situation?", text: $inputText, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .onSubmit { sendMessage() }
                    .onChange(of: voiceManager.transcribedText) { newText in
                        if voiceManager.isListening { inputText = newText }
                    }

                // Microphone button
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
                    Image(systemName: voiceManager.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(voiceManager.isListening
                                         ? .red
                                         : Color(red: 0.18, green: 0.77, blue: 0.71))
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
                                : Color(red: 0.18, green: 0.77, blue: 0.71)
                        )
                        .animation(.easeInOut(duration: 0.15), value: inputText)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 20)
            .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        }
    }

    // MARK: Memory

    // ============================================================
    // LESSON: Session memory — saving on navigate away
    // When the user leaves a conversation thread we silently
    // generate a Claude summary of what was discussed.
    // That summary is injected next time they return.
    // The user never manages this — it just happens.
    // ============================================================
    func saveCurrentSessionMemory() {
        guard messages.count > 2, let contact = selectedContact else { return }
        let history = messages.map { (role: $0.isFromUser ? "User" : "Ember", content: $0.text) }
        memoryStore.generateSummary(for: history, personName: contact.name, apiKey: apiKey) { summary in
            memoryStore.updatePersonMemory(id: contact.id, summary: summary)
        }
        messages = [Message(text: "What's the situation?", isFromUser: false)]
    }

    func saveGroupSessionMemory(_ group: EmberGroup) {
        guard messages.count > 1 else { return }
        for msg in messages where !msg.text.contains("What's the situation?") {
            groupStore.addMessage(GroupMessage(content: msg.text, isFromUser: msg.isFromUser), to: group.id)
        }
        let history = messages.map { (role: $0.isFromUser ? "User" : "Ember", content: $0.text) }
        memoryStore.generateSummary(for: history, groupName: group.name, apiKey: apiKey) { summary in
            memoryStore.updateGroupMemory(id: group.id, summary: summary)
        }
        messages = [Message(text: "What's the situation?", isFromUser: false)]
    }

    // MARK: Ember conversations

    func emberGreetsMember(_ member: CircleMember) {
        currentView = .conversation
        isThinking = true
        Task {
            let memory = buildMemoryContext(for: member)
            let sessionMemory = memoryStore.contextString(for: member.id, name: member.name)
            let prompt = """
                The user wants to focus on \(member.name).
                \(memory)
                \(sessionMemory)
                Greet naturally — reference something specific from previous sessions
                if memory exists, otherwise ask one warm question about the relationship.
                Two sentences maximum.
                """
            let reply = await askClaude(prompt, history: [])
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    func emberGreetsGroup(_ group: EmberGroup) {
        isThinking = true
        let memberNames = group.memberIDs
            .compactMap { circleStore.member(for: $0)?.firstName }
            .joined(separator: ", ")
        let groupMemory = memoryStore.groupContextString(for: group.id, name: group.name)
        Task {
            let prompt = """
                The user opened a \(group.groupType.label.lowercased()) group called "\(group.name)".
                Members: \(memberNames.isEmpty ? "No members yet" : memberNames)
                \(groupMemory)
                \(group.groupType.prompt)
                Welcome the group thread. If there's previous context, reference it.
                Otherwise ask what needs to happen with this group. Two sentences.
                """
            let reply = await askClaude(prompt, history: [])
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    func emberBuildsProfile(_ member: CircleMember) {
        currentView = .conversation
        isThinking = true
        Task {
            let prompt = """
                \(member.name) was just added to the Ember context framework.
                Ask one warm, specific question: when did they last connect
                and what was it about? Two sentences. Warm, not clinical.
                """
            let reply = await askClaude(prompt, history: [])
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    func draftMessageFor(_ member: CircleMember) {
        isThinking = true
        Task {
            let memory = buildMemoryContext(for: member)
            let sessionMemory = memoryStore.contextString(for: member.id, name: member.name)
            let prompt = """
                Draft a short, direct message from the user to \(member.name).
                \(memory)
                \(sessionMemory)
                Rules: sound like a real person, reference something specific,
                one or two sentences, action-oriented, do not start with "Hey".
                Return only the message text.
                """
            let draft = await askClaude(prompt, history: [])
            isThinking = false
            messages.append(Message(text: draft, isFromUser: false, isDraft: true))
        }
    }

    // MARK: Context building

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
        return parts.isEmpty ? "No context yet." : parts.joined(separator: ". ")
    }

    func buildCircleContext() -> String {
        guard !circleStore.members.isEmpty else { return "" }
        let names = circleStore.members.map { $0.firstName }.joined(separator: ", ")
        return "People in context: \(names)."
    }

    func buildGroupContext(for group: EmberGroup) -> String {
        let memberNames = group.memberIDs
            .compactMap { circleStore.member(for: $0)?.firstName }
            .joined(separator: ", ")
        return """
            Active group: \(group.name) (\(group.groupType.label))
            Members: \(memberNames.isEmpty ? "None" : memberNames)
            Context: \(group.sharedContext.isEmpty ? "Not set" : group.sharedContext)
            """
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
                    .filter { !$0.isEmpty }.joined(separator: " ")
                guard !fullName.isEmpty else { return }
                let phone = cnContact.phoneNumbers.first?.value.stringValue ?? ""
                loaded.append(Contact(id: cnContact.identifier, name: fullName, phone: phone))
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

        // If in a group thread, store immediately
        if case .groupThread(let group) = currentView {
            groupStore.addMessage(GroupMessage(content: text, isFromUser: true), to: group.id)
        }

        inputText = ""
        isThinking = true
        let currentHistory = messages
        Task {
            let reply = await askClaude(text, history: currentHistory)
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
            if case .groupThread(let group) = currentView {
                groupStore.addMessage(GroupMessage(content: reply, isFromUser: false), to: group.id)
            }
        }
    }

    // MARK: Claude API

    // ============================================================
    // LESSON: Dynamic system prompt assembly
    // The system prompt changes on every call based on:
    //   - Who is selected (person context + memory)
    //   - Which group is active (group context + memory)
    //   - Which document is active (RAG document context)
    //   - Who is in the circle (circle overview)
    //
    // This is what makes Ember feel personal — the same Claude
    // model powers millions of apps but the system prompt is
    // what makes each response feel specific to this person,
    // this situation, this moment.
    // ============================================================
    func askClaude(_ userMessage: String, history: [Message]) async -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let circleContext  = buildCircleContext()
        let personContext  = selectedContact.map { buildMemoryContext(for: $0) } ?? ""
        let personMemory   = selectedContact.map {
            memoryStore.contextString(for: $0.id, name: $0.name)
        } ?? ""
        let groupContext: String = {
            if case .groupThread(let g) = currentView { return buildGroupContext(for: g) }
            return ""
        }()
        let groupMemory: String = {
            if case .groupThread(let g) = currentView {
                return memoryStore.groupContextString(for: g.id, name: g.name)
            }
            return ""
        }()
        let documentContext = documentStore.buildDocumentContext()

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 500,
            "system": """
                You are Ember's front-end agent — a conversational facilitator
                built on the Ember context framework.
                The framework builds and holds context through conversation.
                Your role is to act on that context.

                Persona: empathetic and action-oriented. Always resolves situations.
                Never leaves threads open. Be warm, specific, brief — 2-3 sentences max.
                Never say "reach out", "touch base", or "circle back".
                When document context is provided, answer from it precisely.
                When coordinating a group, name who needs to do what.

                \(circleContext)
                \(personContext)
                \(personMemory)
                \(groupContext)
                \(groupMemory)
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

    // MARK: Helpers

    func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.3))
                .padding(.top, 60)
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Group Thread Header

struct GroupThreadHeader: View {
    let group: EmberGroup
    let members: [CircleMember]
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
            }
            Image(systemName: group.groupType.icon)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
            Text(group.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
            if !members.isEmpty {
                Text("· \(members.map { $0.firstName }.joined(separator: ", "))")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let group: EmberGroup
    let members: [CircleMember]
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var showingConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: group.groupType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                    Text(group.groupType.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.1))
                        .clipShape(Capsule())
                }
                if let last = group.lastMessage {
                    Text(last.content)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else {
                    Text(group.displayMemberCount)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.5))
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
            "Delete \"\(group.name)\"?",
            isPresented: $showingConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Group Creator

struct GroupCreatorView: View {
    let circleStore: CircleStore
    let onCreate: (String, GroupType, [String]) -> Void

    @State private var name = ""
    @State private var groupType: GroupType = .social
    @State private var selectedMemberIDs: Set<String> = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group name", text: $name)
                    Picker("Type", selection: $groupType) {
                        ForEach(GroupType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon).tag(type)
                        }
                    }
                } header: { Text("Group details") }

                Section {
                    if circleStore.members.isEmpty {
                        Text("Add people to your circle first")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    } else {
                        ForEach(circleStore.members) { member in
                            Button {
                                if selectedMemberIDs.contains(member.id) {
                                    selectedMemberIDs.remove(member.id)
                                } else {
                                    selectedMemberIDs.insert(member.id)
                                }
                            } label: {
                                HStack {
                                    Text(member.name)
                                        .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                                    Spacer()
                                    if selectedMemberIDs.contains(member.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: { Text("Add members") }
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !name.isEmpty else { return }
                        onCreate(name, groupType, Array(selectedMemberIDs))
                    }
                    .fontWeight(.medium)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Circle Member Row

struct CircleMemberRow: View {
    let member: CircleMember
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var showingConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(member.name.initials)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                Circle()
                    .fill(member.driftLevel.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                if !member.lastConnectedDescription.isEmpty {
                    Text(member.lastConnectedDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else {
                    Text("Tap to start")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.5))
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
            "Remove \(member.firstName) from your circle?",
            isPresented: $showingConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { onRemove() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Active Person Bar

struct ActivePersonBar: View {
    let member: CircleMember
    let onDismiss: () -> Void
    let onDraft: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(member.driftLevel.color.opacity(0.3))
                .frame(width: 8, height: 8)
            Text("Focusing on \(member.firstName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
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
                        Image(systemName: "bubble.left").font(.system(size: 11))
                        Text("Draft").font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 11)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Active Document Banner

struct ActiveDocumentBanner: View {
    let document: EmberDocument
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.documentType.icon)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
            VStack(alignment: .leading, spacing: 1) {
                Text("Reading \(document.documentType.displayName.lowercased())")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                Text(document.fileName)
                    .font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Voice Listening Banner

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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        .onAppear { animating = true }
    }
}

// MARK: - Contact Picker View

struct ContactPickerView: View {
    let contacts: [Contact]
    let circleStore: CircleStore
    let onSelect: (Contact) -> Void
    let onRefresh: () async -> Void
    @State private var searchText = ""

    var filtered: [Contact] {
        searchText.isEmpty ? contacts :
        contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { contact in
                Button { onSelect(contact) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(contact.name.initials)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                            if !contact.phone.isEmpty {
                                Text(contact.phone).font(.system(size: 13)).foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        if circleStore.isInCircle(contact.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .refreshable { await onRefresh() }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Add to circle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    var onSend: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isFromUser {
                Circle()
                    .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(Circle()
                        .fill(Color(red: 0.18, green: 0.77, blue: 0.71))
                        .frame(width: 8, height: 8))
            }
            if message.isFromUser { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(
                        message.isFromUser ? .white : Color(red: 0.06, green: 0.05, blue: 0.04)
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromUser
                            ? Color(red: 0.18, green: 0.77, blue: 0.71)
                            : message.isDraft
                                ? Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.06)
                                : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        message.isDraft
                            ? RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1, dash: [4])
                                )
                            : nil
                    )
                if message.isDraft, let onSend, MFMessageComposeViewController.canSendText() {
                    Button(action: onSend) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill").font(.system(size: 12))
                            Text("Send via Messages").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.18, green: 0.77, blue: 0.71))
                        .clipShape(Capsule())
                    }
                    .padding(.leading, 4)
                }
            }
            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(Circle()
                    .fill(Color(red: 0.18, green: 0.77, blue: 0.71))
                    .frame(width: 8, height: 8))
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

// MARK: - String Extension

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
