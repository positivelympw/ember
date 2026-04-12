// ContentView.swift
// Ember v1.2.0

import SwiftUI
import Contacts
import MessageUI
import Speech
import AVFoundation

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    var isDraft: Bool = false
}

struct Contact: Identifiable {
    let id: String
    let name: String
    let phone: String
}

enum AppView: Equatable {
    case conversation
    case circle
    case groups
    case documents
    case sms
    case groupThread(EmberGroup)

    static func == (lhs: AppView, rhs: AppView) -> Bool {
        switch (lhs, rhs) {
        case (.conversation, .conversation): return true
        case (.circle, .circle):             return true
        case (.groups, .groups):             return true
        case (.documents, .documents):       return true
        case (.sms, .sms):                   return true
        case (.groupThread(let a), .groupThread(let b)): return a.id == b.id
        default: return false
        }
    }
}

struct ContentView: View {
    @State private var messages: [Message] = [Message(text: "What is the situation?", isFromUser: false)]
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var showingContactPicker = false
    @State private var showingGroupCreator = false
    @State private var contacts: [Contact] = []
    @State private var selectedContact: CircleMember? = nil
    @State private var selectedGroup: EmberGroup? = nil
    @State private var currentView: AppView = .conversation
    @State private var showingComposer = false
    @State private var draftedMessage = ""
    @State private var showingPaywall = false
    @State private var logoTapCount = 0
    @State private var showingUnlockConfirm = false

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
            if currentView != .sms { Divider(); inputBar }
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        .onAppear { if CNContactStore.authorizationStatus(for: .contacts) == .authorized { loadContacts() } }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView(contacts: contacts, circleStore: circleStore, onSelect: { contact in
                showingContactPicker = false; handleContactSelected(contact)
            }, onRefresh: {
                await withCheckedContinuation { c in loadContacts(); DispatchQueue.main.asyncAfter(deadline: .now()+0.6) { c.resume() } }
            })
        }
        .sheet(isPresented: $showingGroupCreator) {
            GroupCreatorView(circleStore: circleStore) { name, type, ids in
                let g = groupStore.create(name: name, type: type, memberIDs: ids)
                showingGroupCreator = false; selectedGroup = g; currentView = .groupThread(g); emberGreetsGroup(g)
            }
        }
        .sheet(isPresented: $showingComposer) {
            if let c = selectedContact, !c.phone.isEmpty {
                MessageComposerView(recipient: c.phone, body: draftedMessage) { result in
                    showingComposer = false
                    if case .sent = result { messages.append(Message(text: "Sent to \(c.firstName).", isFromUser: false)) }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) { ProPaywallView(proManager: proManager) }
        .alert("Unlock Pro", isPresented: $showingUnlockConfirm) {
            Button("Unlock") { proManager.manualUnlock(); messages.append(Message(text: "Pro unlocked.", isFromUser: false)) }
            Button("Revoke")  { proManager.manualRevoke(); messages.append(Message(text: "Pro revoked.", isFromUser: false)) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Dev mode") }
    }

    @ViewBuilder var mainContent: some View {
        switch currentView {
        case .conversation:       messageList
        case .circle:             circleView
        case .groups:             groupsView
        case .documents:          DocumentView(documentStore: documentStore)
        case .sms:                NavigationStack { SMSSurfaceView() }
        case .groupThread(let g): groupThreadView(g)
        }
    }

    var headerBar: some View {
        HStack {
            ZStack {
                Circle().stroke(Color(red:0.18,green:0.77,blue:0.71).opacity(0.3),lineWidth:1).frame(width:22,height:22)
                Circle().stroke(Color(red:0.18,green:0.77,blue:0.71).opacity(0.6),lineWidth:1).frame(width:14,height:14)
                Circle().fill(Color(red:0.18,green:0.77,blue:0.71)).frame(width:6,height:6)
            }
            .onTapGesture { logoTapCount += 1; if logoTapCount >= 5 { logoTapCount=0; showingUnlockConfirm=true } }
            HStack(spacing:4) {
                Text("ember").font(.system(size:17,weight:.medium)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
                if proManager.isPro { Text("PRO").font(.system(size:9,weight:.bold)).foregroundColor(.white).padding(.horizontal,5).padding(.vertical,2).background(Color(red:0.18,green:0.77,blue:0.71)).clipShape(Capsule()) }
            }
            Spacer()
            HStack(spacing:16) {
                Button { saveCurrentSessionMemory(); selectedContact=nil; selectedGroup=nil; currentView = .conversation } label: {
                    Image(systemName: currentView == .conversation ? "bubble.left.fill" : "bubble.left").font(.system(size:20)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
                }
                Button { withAnimation(.spring(response:0.3)) { currentView = .circle } } label: {
                    ZStack(alignment:.topTrailing) {
                        Image(systemName: currentView == .circle ? "person.2.fill" : "person.2").font(.system(size:20)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
                        if !circleStore.members.isEmpty { Text("\(circleStore.members.count)").font(.system(size:10,weight:.bold)).foregroundColor(.white).frame(width:16,height:16).background(Color(red:0.18,green:0.77,blue:0.71)).clipShape(Circle()).offset(x:6,y:-6) }
                    }
                }
                Button { withAnimation(.spring(response:0.3)) { currentView = .groups } } label: {
                    ZStack(alignment:.topTrailing) {
                        Image(systemName: currentView == .groups ? "person.3.fill" : "person.3").font(.system(size:20)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
                        if !groupStore.groups.isEmpty { Text("\(groupStore.groups.count)").font(.system(size:10,weight:.bold)).foregroundColor(.white).frame(width:16,height:16).background(Color(red:0.18,green:0.77,blue:0.71)).clipShape(Circle()).offset(x:6,y:-6) }
                    }
                }
                Button { if proManager.isPro { currentView = .documents } else { showingPaywall=true } } label: {
                    ZStack(alignment:.topTrailing) {
                        Image(systemName: currentView == .documents ? "doc.text.fill" : "doc.text").font(.system(size:20)).foregroundColor(proManager.isPro ? Color(red:0.18,green:0.77,blue:0.71) : Color(red:0.18,green:0.77,blue:0.71).opacity(0.4))
                        if !proManager.isPro { Image(systemName:"lock.fill").font(.system(size:7,weight:.bold)).foregroundColor(.white).frame(width:13,height:13).background(Color.gray.opacity(0.5)).clipShape(Circle()).offset(x:6,y:-6) }
                        else if !documentStore.documents.isEmpty { Text("\(documentStore.documents.count)").font(.system(size:10,weight:.bold)).foregroundColor(.white).frame(width:16,height:16).background(Color(red:0.18,green:0.77,blue:0.71)).clipShape(Circle()).offset(x:6,y:-6) }
                    }
                }
                Button { withAnimation(.spring(response:0.3)) { currentView = .sms } } label: {
                    Image(systemName: currentView == .sms ? "message.fill" : "message").font(.system(size:20)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
                }
                Button { requestContactsAndShow() } label: {
                    Image(systemName:"plus.circle").font(.system(size:20)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
                }
            }
        }
        .padding(.horizontal,20).padding(.vertical,14)
    }

    var circleView: some View {
        ScrollView {
            VStack(spacing:0) {
                if circleStore.members.isEmpty {
                    emptyStateView(icon:"person.2",title:"Your circle is empty",message:"Tap + to add people")
                } else {
                    ForEach(circleStore.members) { m in
                        CircleMemberRow(member:m,
                            onSelect: { selectedContact=m; currentView = .conversation; emberGreetsMember(m) },
                            onRemove: { circleStore.remove(m); if selectedContact?.id==m.id { selectedContact=nil } })
                        Divider().padding(.leading,72)
                    }
                }
            }.padding(.top,8)
        }
    }

    var groupsView: some View {
        ScrollView {
            VStack(spacing:0) {
                Button { showingGroupCreator=true } label: {
                    HStack(spacing:12) {
                        ZStack { Circle().fill(Color(red:0.18,green:0.77,blue:0.71).opacity(0.1)).frame(width:44,height:44); Image(systemName:"plus").font(.system(size:16)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71)) }
                        Text("Create a group").font(.system(size:15)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71)); Spacer()
                    }.padding(.horizontal,20).padding(.vertical,12)
                }
                Divider()
                if groupStore.groups.isEmpty {
                    emptyStateView(icon:"person.3",title:"No groups yet",message:"Create a group to coordinate")
                } else {
                    ForEach(groupStore.groups) { g in
                        GroupRow(group:g, members:g.memberIDs.compactMap { circleStore.member(for:$0) },
                            onSelect: { selectedGroup=g; currentView = .groupThread(g); if g.conversationHistory.isEmpty { emberGreetsGroup(g) } },
                            onDelete: { groupStore.delete(g) })
                        Divider().padding(.leading,72)
                    }
                }
            }.padding(.top,8)
        }
    }

    func groupThreadView(_ group: EmberGroup) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing:8) {
                    GroupThreadHeader(group:group, members:group.memberIDs.compactMap { circleStore.member(for:$0) },
                        onBack: { saveGroupSessionMemory(group); currentView = .groups; selectedGroup=nil })
                    .padding(.horizontal,16).padding(.top,8)
                    ForEach(group.conversationHistory) { msg in MessageBubble(message:Message(text:msg.content,isFromUser:msg.isFromUser)) }
                    ForEach(messages) { m in MessageBubble(message:m) }
                    if isThinking { TypingIndicator().id("typing") }
                    Color.clear.frame(height:1).id("bottom")
                }.padding(.horizontal,16).padding(.vertical,8)
            }
            .onChange(of:messages.count) { withAnimation { proxy.scrollTo("bottom") } }
            .onChange(of:isThinking) { withAnimation { proxy.scrollTo("bottom") } }
        }
    }

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing:8) {
                    if let p = selectedContact {
                        ActivePersonBar(member:p, onDismiss: { saveCurrentSessionMemory(); selectedContact=nil }, onDraft: { draftMessageFor(p) })
                        .padding(.horizontal,16).padding(.top,8)
                    }
                    if let doc = documentStore.activeDocument {
                        ActiveDocumentBanner(document:doc) { documentStore.activeDocument=nil }.padding(.horizontal,16).padding(.top,selectedContact==nil ? 8:4)
                    }
                    if voiceManager.isListening { VoiceListeningBanner().padding(.horizontal,16).padding(.top,4) }
                    ForEach(messages) { m in MessageBubble(message:m, onSend: m.isDraft ? { draftedMessage=m.text; showingComposer=true } : nil) }
                    if isThinking { TypingIndicator().id("typing") }
                    Color.clear.frame(height:1).id("bottom")
                }.padding(.horizontal,16).padding(.vertical,8)
            }
            .onChange(of:messages.count) { withAnimation { proxy.scrollTo("bottom") } }
            .onChange(of:isThinking) { withAnimation { proxy.scrollTo("bottom") } }
        }
    }

    var inputBar: some View {
        VStack(spacing:0) {
            if !circleStore.members.isEmpty && currentView == .conversation {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:8) {
                        ForEach(circleStore.members) { m in
                            Button { selectedContact=m; emberGreetsMember(m) } label: {
                                HStack(spacing:6) {
                                    Circle().fill(m.driftLevel.color.opacity(0.8)).frame(width:7,height:7)
                                    Text(m.firstName).font(.system(size:13)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
                                }
                                .padding(.horizontal,12).padding(.vertical,6)
                                .background(selectedContact?.id==m.id ? Color(red:0.18,green:0.77,blue:0.71).opacity(0.15) : Color.white)
                                .clipShape(Capsule())
                            }
                        }
                    }.padding(.horizontal,16).padding(.vertical,8)
                }.background(Color(red:0.97,green:0.96,blue:0.94))
            }
            HStack(alignment:.bottom,spacing:10) {
                TextField("What is the situation?",text:$inputText,axis:.vertical)
                    .font(.system(size:16)).lineLimit(1...5)
                    .padding(.horizontal,14).padding(.vertical,10)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius:22))
                    .onSubmit { sendMessage() }
                    .onChange(of:voiceManager.transcribedText) { t in if voiceManager.isListening { inputText=t } }
                Button {
                    if voiceManager.isListening { voiceManager.stopListening() }
                    else { voiceManager.requestPermissions { g in if g { voiceManager.startListening() } else { messages.append(Message(text:"Enable Microphone in Settings.",isFromUser:false)) } } }
                } label: {
                    Image(systemName:voiceManager.isListening ? "stop.circle.fill":"mic.circle.fill").font(.system(size:32))
                        .foregroundColor(voiceManager.isListening ? .red : Color(red:0.18,green:0.77,blue:0.71))
                        .scaleEffect(voiceManager.isListening ? 1.15:1.0)
                        .animation(voiceManager.isListening ? .easeInOut(duration:0.5).repeatForever(autoreverses:true) : .spring(), value:voiceManager.isListening)
                }
                Button { sendMessage() } label: {
                    Image(systemName:"arrow.up.circle.fill").font(.system(size:32))
                        .foregroundColor(inputText.trimmingCharacters(in:.whitespaces).isEmpty ? Color.gray.opacity(0.4) : Color(red:0.18,green:0.77,blue:0.71))
                }
                .disabled(inputText.trimmingCharacters(in:.whitespaces).isEmpty || isThinking)
            }
            .padding(.horizontal,16).padding(.vertical,12).padding(.bottom,20).background(Color(red:0.97,green:0.96,blue:0.94))
        }
    }

    func saveCurrentSessionMemory() {
        guard messages.count > 2, let c = selectedContact else { return }
        let h = messages.map { (role:$0.isFromUser ? "User":"Ember", content:$0.text) }
        memoryStore.generateSummary(for:h,personName:c.name,apiKey:apiKey) { memoryStore.updatePersonMemory(id:c.id,summary:$0) }
        messages = [Message(text:"What is the situation?",isFromUser:false)]
    }

    func saveGroupSessionMemory(_ g: EmberGroup) {
        guard messages.count > 1 else { return }
        for m in messages where !m.text.contains("What is the situation?") { groupStore.addMessage(GroupMessage(content:m.text,isFromUser:m.isFromUser),to:g.id) }
        let h = messages.map { (role:$0.isFromUser ? "User":"Ember", content:$0.text) }
        memoryStore.generateSummary(for:h,groupName:g.name,apiKey:apiKey) { memoryStore.updateGroupMemory(id:g.id,summary:$0) }
        messages = [Message(text:"What is the situation?",isFromUser:false)]
    }

    func emberGreetsMember(_ m: CircleMember) {
        currentView = .conversation; isThinking = true
        Task {
            let r = await askClaude("Focus on \(m.name). \(buildMemoryContext(for:m)) \(memoryStore.contextString(for:m.id,name:m.name)) Greet warmly, two sentences.", history:[])
            isThinking = false; messages.append(Message(text:r,isFromUser:false))
        }
    }

    func emberGreetsGroup(_ g: EmberGroup) {
        isThinking = true
        let names = g.memberIDs.compactMap { circleStore.member(for:$0)?.firstName }.joined(separator:", ")
        Task {
            let r = await askClaude("Group: \(g.name). Members: \(names). \(memoryStore.groupContextString(for:g.id,name:g.name)) Welcome briefly.", history:[])
            isThinking = false; messages.append(Message(text:r,isFromUser:false))
        }
    }

    func emberBuildsProfile(_ m: CircleMember) {
        currentView = .conversation; isThinking = true
        Task {
            let r = await askClaude("\(m.name) just added. Ask one warm question about when they last connected.", history:[])
            isThinking = false; messages.append(Message(text:r,isFromUser:false))
        }
    }

    func draftMessageFor(_ m: CircleMember) {
        isThinking = true
        Task {
            let r = await askClaude("Draft message to \(m.name). \(buildMemoryContext(for:m)) One or two sentences, personal, no Hey.", history:[])
            isThinking = false; messages.append(Message(text:r,isFromUser:false,isDraft:true))
        }
    }

    func buildMemoryContext(for m: CircleMember) -> String {
        var p: [String] = []
        if !m.lastConnectedDescription.isEmpty { p.append("Last: \(m.lastConnectedDescription)") }
        if !m.sharedContext.isEmpty  { p.append("Background: \(m.sharedContext)") }
        if !m.currentContext.isEmpty { p.append("Now: \(m.currentContext)") }
        p.append("Status: \(m.driftLevel.rawValue)")
        return p.joined(separator:". ")
    }

    func buildCircleContext() -> String {
        guard !circleStore.members.isEmpty else { return "" }
        return "Circle: \(circleStore.members.map{$0.firstName}.joined(separator:", "))."
    }

    func buildGroupContext(for g: EmberGroup) -> String {
        let names = g.memberIDs.compactMap { circleStore.member(for:$0)?.firstName }.joined(separator:", ")
        return "Group: \(g.name). Members: \(names)."
    }

    func handleContactSelected(_ c: Contact) {
        if circleStore.isInCircle(c.id) {
            if let m = circleStore.member(for:c.id) { selectedContact=m; emberGreetsMember(m) }
        } else {
            circleStore.add(c)
            if let m = circleStore.member(for:c.id) { selectedContact=m; emberBuildsProfile(m) }
        }
    }

    func requestContactsAndShow() {
        CNContactStore().requestAccess(for:.contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted { loadContacts(); DispatchQueue.main.asyncAfter(deadline:.now()+0.4) { showingContactPicker=true } }
                else { messages.append(Message(text:"Enable Contacts in Settings.",isFromUser:false)) }
            }
        }
    }

    func loadContacts() {
        DispatchQueue.global(qos:.userInitiated).async {
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor,CNContactGivenNameKey as CNKeyDescriptor,CNContactFamilyNameKey as CNKeyDescriptor,CNContactPhoneNumbersKey as CNKeyDescriptor]
            var loaded: [Contact] = []
            try? store.enumerateContacts(with:CNContactFetchRequest(keysToFetch:keys)) { c, _ in
                let name = [c.givenName,c.familyName].filter{!$0.isEmpty}.joined(separator:" ")
                guard !name.isEmpty else { return }
                loaded.append(Contact(id:c.identifier,name:name,phone:c.phoneNumbers.first?.value.stringValue ?? ""))
            }
            DispatchQueue.main.async {
                contacts = loaded.sorted { $0.name < $1.name }
                for m in circleStore.members {
                    if let f = loaded.first(where:{$0.id==m.id}) { var u=m; u.name=f.name; u.phone=f.phone; circleStore.update(u) }
                }
            }
        }
    }

    func sendMessage() {
        if voiceManager.isListening { voiceManager.stopListening() }
        let text = inputText.trimmingCharacters(in:.whitespaces)
        guard !text.isEmpty else { return }
        messages.append(Message(text:text,isFromUser:true))
        if case .groupThread(let g) = currentView { groupStore.addMessage(GroupMessage(content:text,isFromUser:true),to:g.id) }
        inputText = ""; isThinking = true
        let h = messages
        Task {
            let r = await askClaude(text,history:h)
            isThinking = false; messages.append(Message(text:r,isFromUser:false))
            if case .groupThread(let g) = currentView { groupStore.addMessage(GroupMessage(content:r,isFromUser:false),to:g.id) }
        }
    }

    func askClaude(_ msg: String, history: [Message]) async -> String {
        let url = URL(string:"https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url:url)
        req.httpMethod = "POST"
        req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.setValue(apiKey,forHTTPHeaderField:"x-api-key")
        req.setValue("2023-06-01",forHTTPHeaderField:"anthropic-version")
        let gc: String = { if case .groupThread(let g) = currentView { return buildGroupContext(for:g) }; return "" }()
        let gm: String = { if case .groupThread(let g) = currentView { return memoryStore.groupContextString(for:g.id,name:g.name) }; return "" }()
        let sys = """
            You are Ember agent. Empathetic, action-oriented, brief (2-3 sentences).
            Never say reach out, touch base, or circle back.
            \(buildCircleContext())
            \(selectedContact.map { buildMemoryContext(for:$0) } ?? "")
            \(selectedContact.map { memoryStore.contextString(for:$0.id,name:$0.name) } ?? "")
            \(gc) \(gm)
            \(documentStore.buildDocumentContext())
            WIDGETS:
            Restaurant: [OPENTABLE:Name|id|Cuisine|Price|Neighborhood]
            Flights: [FLIGHTS:ORIG|DEST|YYYY-MM-DD|YYYY-MM-DD]
            Draft: [DRAFT:name|message body]
            """
        let body: [String:Any] = ["model":"claude-sonnet-4-6","max_tokens":500,"system":sys,
            "messages":history.map{["role":$0.isFromUser ? "user":"assistant","content":$0.text]}+[["role":"user","content":msg]]]
        req.httpBody = try? JSONSerialization.data(withJSONObject:body)
        guard let (data,_) = try? await URLSession.shared.data(for:req) else { return "Something went wrong." }
        guard let json = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let c = json["content"] as? [[String:Any]], let t = c.first?["text"] as? String else { return "Something went wrong." }
        return t
    }

    func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing:16) {
            Image(systemName:icon).font(.system(size:48)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71).opacity(0.3)).padding(.top,60)
            Text(title).font(.system(size:18,weight:.medium)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
            Text(message).font(.system(size:15)).foregroundColor(.gray).multilineTextAlignment(.center)
        }.frame(maxWidth:.infinity)
    }
}

struct GroupThreadHeader: View {
    let group: EmberGroup; let members: [CircleMember]; let onBack: () -> Void
    var body: some View {
        HStack(spacing:10) {
            Button(action:onBack) { Image(systemName:"chevron.left").font(.system(size:13,weight:.medium)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71)) }
            Image(systemName:group.groupType.icon).font(.system(size:11)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
            Text(group.name).font(.system(size:13,weight:.medium)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
            if !members.isEmpty { Text(members.map{$0.firstName}.joined(separator:", ")).font(.system(size:13)).foregroundColor(.gray).lineLimit(1) }
            Spacer()
        }.padding(.horizontal,14).padding(.vertical,8).background(Color.white).clipShape(RoundedRectangle(cornerRadius:10))
    }
}

struct GroupRow: View {
    let group: EmberGroup; let members: [CircleMember]; let onSelect: () -> Void; let onDelete: () -> Void
    @State private var showingConfirm = false
    var body: some View {
        HStack(spacing:12) {
            ZStack { Circle().fill(Color(red:0.18,green:0.77,blue:0.71).opacity(0.1)).frame(width:48,height:48); Image(systemName:group.groupType.icon).font(.system(size:18)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71)) }
            VStack(alignment:.leading,spacing:3) {
                HStack(spacing:6) {
                    Text(group.name).font(.system(size:16)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
                    Text(group.groupType.label).font(.system(size:10,weight:.medium)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71)).padding(.horizontal,6).padding(.vertical,2).background(Color(red:0.18,green:0.77,blue:0.71).opacity(0.1)).clipShape(Capsule())
                }
                if let last = group.lastMessage { Text(last.content).font(.system(size:13)).foregroundColor(.gray).lineLimit(1) }
                else { Text(group.displayMemberCount).font(.system(size:13)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71).opacity(0.5)) }
            }
            Spacer()
            Button { showingConfirm=true } label: { Image(systemName:"minus.circle").font(.system(size:22)).foregroundColor(.gray.opacity(0.4)) }
        }
        .padding(.horizontal,20).padding(.vertical,12).contentShape(Rectangle()).onTapGesture { onSelect() }
        .confirmationDialog("Delete group?",isPresented:$showingConfirm,titleVisibility:.visible) {
            Button("Delete",role:.destructive) { onDelete() }; Button("Cancel",role:.cancel) {}
        }
    }
}

struct GroupCreatorView: View {
    let circleStore: CircleStore; let onCreate: (String,GroupType,[String]) -> Void
    @State private var name = ""; @State private var groupType: GroupType = .social; @State private var selectedIDs: Set<String> = []
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group name",text:$name)
                    Picker("Type",selection:$groupType) { ForEach(GroupType.allCases,id:\.self) { Label($0.label,systemImage:$0.icon).tag($0) } }
                } header: { Text("Details") }
                Section {
                    if circleStore.members.isEmpty { Text("Add people first").foregroundColor(.gray) }
                    else { ForEach(circleStore.members) { m in
                        Button { if selectedIDs.contains(m.id) { selectedIDs.remove(m.id) } else { selectedIDs.insert(m.id) } } label: {
                            HStack { Text(m.name).foregroundColor(Color(red:0.06,green:0.05,blue:0.04)); Spacer()
                                if selectedIDs.contains(m.id) { Image(systemName:"checkmark.circle.fill").foregroundColor(Color(red:0.18,green:0.77,blue:0.71)) }
                            }
                        }.buttonStyle(.plain)
                    }}
                } header: { Text("Members") }
            }
            .navigationTitle("New group").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement:.confirmationAction) { Button("Create") { guard !name.isEmpty else { return }; onCreate(name,groupType,Array(selectedIDs)) }.disabled(name.isEmpty) }
            }
        }
    }
}

struct CircleMemberRow: View {
    let member: CircleMember; let onSelect: () -> Void; let onRemove: () -> Void
    @State private var showingConfirm = false
    var body: some View {
        HStack(spacing:12) {
            ZStack(alignment:.bottomTrailing) {
                Circle().fill(Color(red:0.18,green:0.77,blue:0.71).opacity(0.12)).frame(width:48,height:48)
                Text(member.name.initials).font(.system(size:16,weight:.medium)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
                Circle().fill(member.driftLevel.color).frame(width:12,height:12).overlay(Circle().stroke(Color.white,lineWidth:2))
            }
            VStack(alignment:.leading,spacing:3) {
                Text(member.name).font(.system(size:16)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
                if !member.lastConnectedDescription.isEmpty { Text(member.lastConnectedDescription).font(.system(size:13)).foregroundColor(.gray).lineLimit(1) }
                else { Text("Tap to start").font(.system(size:13)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71).opacity(0.5)) }
            }
            Spacer()
            Button { showingConfirm=true } label: { Image(systemName:"minus.circle").font(.system(size:22)).foregroundColor(.gray.opacity(0.4)) }
        }
        .padding(.horizontal,20).padding(.vertical,12).contentShape(Rectangle()).onTapGesture { onSelect() }
        .confirmationDialog("Remove from circle?",isPresented:$showingConfirm,titleVisibility:.visible) {
            Button("Remove",role:.destructive) { onRemove() }; Button("Cancel",role:.cancel) {}
        }
    }
}

struct ActivePersonBar: View {
    let member: CircleMember; let onDismiss: () -> Void; let onDraft: () -> Void
    var body: some View {
        HStack(spacing:10) {
            Circle().fill(member.driftLevel.color.opacity(0.3)).frame(width:8,height:8)
            Text("Focusing on \(member.firstName)").font(.system(size:13,weight:.medium)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
            if !member.lastConnectedDescription.isEmpty { Text(member.lastConnectedDescription).font(.system(size:13)).foregroundColor(.gray).lineLimit(1) }
            Spacer()
            if MFMessageComposeViewController.canSendText() {
                Button(action:onDraft) { HStack(spacing:4) { Image(systemName:"bubble.left").font(.system(size:11)); Text("Draft").font(.system(size:12)) }.foregroundColor(Color(red:0.18,green:0.77,blue:0.71)).padding(.horizontal,10).padding(.vertical,4).background(Color(red:0.18,green:0.77,blue:0.71).opacity(0.1)).clipShape(Capsule()) }
            }
            Button(action:onDismiss) { Image(systemName:"xmark").font(.system(size:11)).foregroundColor(.gray) }
        }.padding(.horizontal,14).padding(.vertical,8).background(Color.white).clipShape(RoundedRectangle(cornerRadius:10))
    }
}

struct ActiveDocumentBanner: View {
    let document: EmberDocument; let onDismiss: () -> Void
    var body: some View {
        HStack(spacing:10) {
            Image(systemName:document.documentType.icon).font(.system(size:12)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71))
            VStack(alignment:.leading,spacing:1) {
                Text("Reading \(document.documentType.displayName.lowercased())").font(.system(size:12,weight:.medium)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04))
                Text(document.fileName).font(.system(size:11)).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            Button(action:onDismiss) { Image(systemName:"xmark").font(.system(size:10)).foregroundColor(.gray) }
        }
        .padding(.horizontal,12).padding(.vertical,7)
        .background(Color(red:0.18,green:0.77,blue:0.71).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius:8))
        .overlay(RoundedRectangle(cornerRadius:8).stroke(Color(red:0.18,green:0.77,blue:0.71).opacity(0.2),lineWidth:0.5))
    }
}

struct VoiceListeningBanner: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing:10) {
            HStack(spacing:4) { ForEach(0..<3,id:\.self) { i in RoundedRectangle(cornerRadius:2).fill(Color.red).frame(width:3,height:animating ? 14:6).animation(.easeInOut(duration:0.4).repeatForever(autoreverses:true).delay(Double(i)*0.15),value:animating) } }.frame(height:16)
            Text("Listening...").font(.system(size:13,weight:.medium)).foregroundColor(.red); Spacer()
        }
        .padding(.horizontal,14).padding(.vertical,8).background(Color.red.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(Color.red.opacity(0.2),lineWidth:0.5))
        .onAppear { animating=true }
    }
}

struct ContactPickerView: View {
    let contacts: [Contact]; let circleStore: CircleStore; let onSelect: (Contact) -> Void; let onRefresh: () async -> Void
    @State private var searchText = ""
    var filtered: [Contact] { searchText.isEmpty ? contacts : contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    var body: some View {
        NavigationStack {
            List(filtered) { c in
                Button { onSelect(c) } label: {
                    HStack(spacing:12) {
                        ZStack { Circle().fill(Color(red:0.18,green:0.77,blue:0.71).opacity(0.15)).frame(width:40,height:40); Text(c.name.initials).font(.system(size:14,weight:.medium)).foregroundColor(Color(red:0.18,green:0.77,blue:0.71)) }
                        VStack(alignment:.leading,spacing:2) { Text(c.name).font(.system(size:16)).foregroundColor(Color(red:0.06,green:0.05,blue:0.04)); if !c.phone.isEmpty { Text(c.phone).font(.system(size:13)).foregroundColor(.gray) } }
                        Spacer()
                        if circleStore.isInCircle(c.id) { Image(systemName:"checkmark.circle.fill").foregroundColor(Color(red:0.18,green:0.77,blue:0.71)) }
                    }.padding(.vertical,4)
                }.buttonStyle(.plain)
            }
            .listStyle(.plain).refreshable { await onRefresh() }.searchable(text:$searchText,prompt:"Search contacts")
            .navigationTitle("Add to circle").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MessageBubble: View {
    let message: Message; var onSend: (() -> Void)? = nil
    var body: some View {
        HStack(alignment:.bottom,spacing:8) {
            if !message.isFromUser { Circle().fill(Color(red:0.18,green:0.77,blue:0.71).opacity(0.15)).frame(width:28,height:28).overlay(Circle().fill(Color(red:0.18,green:0.77,blue:0.71)).frame(width:8,height:8)) }
            if message.isFromUser { Spacer(minLength:60) }
            VStack(alignment:.leading,spacing:6) {
                EmberMessageView(text:message.text,isUser:message.isFromUser)
                    .padding(.horizontal,14).padding(.vertical,10)
                    .background(message.isFromUser ? Color(red:0.18,green:0.77,blue:0.71) : message.isDraft ? Color(red:0.18,green:0.77,blue:0.71).opacity(0.06) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius:18))
                    .overlay(message.isDraft ? RoundedRectangle(cornerRadius:18).stroke(Color(red:0.18,green:0.77,blue:0.71).opacity(0.4),style:StrokeStyle(lineWidth:1,dash:[4])) : nil)
                if message.isDraft, let onSend, MFMessageComposeViewController.canSendText() {
                    Button(action:onSend) {
                        HStack(spacing:6) { Image(systemName:"paperplane.fill").font(.system(size:12)); Text("Send via Messages").font(.system(size:13,weight:.medium)) }
                        .foregroundColor(.white).padding(.horizontal,14).padding(.vertical,8).background(Color(red:0.18,green:0.77,blue:0.71)).clipShape(Capsule())
                    }.padding(.leading,4)
                }
            }
            if !message.isFromUser { Spacer(minLength:60) }
        }
    }
}

struct TypingIndicator: View {
    @State private var animatingDot = 0
    var body: some View {
        HStack(alignment:.bottom,spacing:8) {
            Circle().fill(Color(red:0.18,green:0.77,blue:0.71).opacity(0.15)).frame(width:28,height:28).overlay(Circle().fill(Color(red:0.18,green:0.77,blue:0.71)).frame(width:8,height:8))
            HStack(spacing:5) { ForEach(0..<3,id:\.self) { i in Circle().fill(Color.gray.opacity(0.4)).frame(width:8,height:8).offset(y:animatingDot==i ? -5:0).animation(.easeInOut(duration:0.4).repeatForever(autoreverses:true).delay(Double(i)*0.15),value:animatingDot) } }.padding(.horizontal,14).padding(.vertical,12).background(Color.white).clipShape(RoundedRectangle(cornerRadius:18))
            Spacer(minLength:60)
        }.onAppear { animatingDot=2 }
    }
}

extension String {
    var initials: String { components(separatedBy:" ").prefix(2).compactMap{$0.first}.map(String.init).joined() }
    var firstName: String { components(separatedBy:" ").first ?? self }
}

#Preview { ContentView() }
