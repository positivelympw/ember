// EmberWidgets.swift
// Ember — Native Widget System
// Brick W: OpenTable + Flights in-app integration
// v1.1.0 — April 2026
//
// DROP INTO: Ember/ target (same folder as ContentView.swift)
// ADDS:
//   - EmberMessageParser   — parses Claude reply text into [MessageSegment]
//   - EmberMessageView     — renders segments (text + widgets) in the chat bubble
//   - OpenTableWidget      — tappable restaurant card → Safari/OpenTable deep link
//   - FlightPickerWidget   — scrollable flight carousel → Google Flights deep link
//   - DraftMessageWidget   — draft card with "Open in Messages" button (replaces web version)

import SwiftUI
import SafariServices

// MARK: - Message Segment Model ─────────────────────────────────────────────

enum MessageSegment: Identifiable {
    case text(String)
    case openTable(OTPayload)
    case flights(FlightPayload)
    case draft(DraftPayload)

    var id: String {
        switch self {
        case .text(let s):        return "text-\(s.prefix(20))"
        case .openTable(let p):   return "ot-\(p.name)"
        case .flights(let p):     return "fl-\(p.origin)-\(p.destination)"
        case .draft(let p):       return "dr-\(p.recipient)"
        }
    }
}

struct OTPayload {
    let name: String
    let otID: String        // numeric OpenTable restaurant ID, or "" to search by name
    let cuisine: String
    let price: String       // "$" | "$$" | "$$$" | "$$$$"
    let neighborhood: String
}

struct FlightPayload {
    let origin: String      // IATA code
    let destination: String
    let departDate: String  // YYYY-MM-DD
    let returnDate: String? // nil = one-way
}

struct DraftPayload {
    let recipient: String
    let body: String
}

// MARK: - Parser ────────────────────────────────────────────────────────────
//
// Scans Claude's raw reply for widget tags and splits it into segments.
// Tags are the same syntax used on the web:
//   [OPENTABLE:Name|id|cuisine|price|neighborhood]
//   [FLIGHTS:ORIG|DEST|YYYY-MM-DD|YYYY-MM-DD]
//   [DRAFT:recipient|message body]

enum EmberMessageParser {

    // Combined pattern that matches any widget tag or text between them
    private static let pattern = #"\[OPENTABLE:([^\]|]+)\|([^\]|]*)\|?([^\]|]*)\|?([^\]|]*)\|?([^\]]*)\]|\[FLIGHTS:([A-Z]{3})\|([A-Z]{3})\|(\d{4}-\d{2}-\d{2})\|?(\d{4}-\d{2}-\d{2})?\]|\[DRAFT:([^\]|]+)\|([^\]]+)\]"#

    static func parse(_ raw: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        var cursor = raw.startIndex
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsRaw = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))

        for match in matches {
            // Text before this match
            let matchStart = Range(match.range, in: raw)!.lowerBound
            if cursor < matchStart {
                let text = String(raw[cursor..<matchStart]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { segments.append(.text(text)) }
            }

            let full = nsRaw.substring(with: match.range)

            if full.uppercased().hasPrefix("[OPENTABLE:") {
                let g = { (i: Int) -> String in
                    match.range(at: i).location != NSNotFound
                        ? nsRaw.substring(with: match.range(at: i))
                        : ""
                }
                let payload = OTPayload(
                    name:         g(1).trimmingCharacters(in: .whitespaces),
                    otID:         g(2).trimmingCharacters(in: .whitespaces),
                    cuisine:      g(3).trimmingCharacters(in: .whitespaces),
                    price:        g(4).trimmingCharacters(in: .whitespaces),
                    neighborhood: g(5).trimmingCharacters(in: .whitespaces)
                )
                segments.append(.openTable(payload))

            } else if full.uppercased().hasPrefix("[FLIGHTS:") {
                let g = { (i: Int) -> String in
                    match.range(at: i).location != NSNotFound
                        ? nsRaw.substring(with: match.range(at: i))
                        : ""
                }
                let payload = FlightPayload(
                    origin:      g(6).uppercased(),
                    destination: g(7).uppercased(),
                    departDate:  g(8),
                    returnDate:  g(9).isEmpty ? nil : g(9)
                )
                segments.append(.flights(payload))

            } else if full.uppercased().hasPrefix("[DRAFT:") {
                let g = { (i: Int) -> String in
                    match.range(at: i).location != NSNotFound
                        ? nsRaw.substring(with: match.range(at: i))
                        : ""
                }
                let payload = DraftPayload(
                    recipient: g(10).trimmingCharacters(in: .whitespaces),
                    body:      g(11).trimmingCharacters(in: .whitespaces)
                )
                segments.append(.draft(payload))
            }

            cursor = Range(match.range, in: raw)!.upperBound
        }

        // Remaining text after last match
        if cursor < raw.endIndex {
            let tail = String(raw[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { segments.append(.text(tail)) }
        }

        return segments.isEmpty ? [.text(raw)] : segments
    }
}

// MARK: - Top-Level Message Renderer ────────────────────────────────────────
//
// Drop-in replacement for the plain Text() call inside your message bubble.
// Usage:
//   EmberMessageView(text: message.content, isUser: message.isUser)

struct EmberMessageView: View {
    let text: String
    let isUser: Bool

    @State private var safariURL: URL? = nil
    @State private var showSafari = false

    private var segments: [MessageSegment] {
        isUser ? [.text(text)] : EmberMessageParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                switch segment {
                case .text(let s):
                    EmberTextView(text: s, isUser: isUser)

                case .openTable(let p):
                    OpenTableWidget(payload: p) { url in
                        safariURL = url
                        showSafari = true
                    }

                case .flights(let p):
                    FlightPickerWidget(payload: p) { url in
                        safariURL = url
                        showSafari = true
                    }

                case .draft(let d):
                    DraftMessageWidget(payload: d)
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }
}

// MARK: - Markdown-lite text renderer ────────────────────────────────────────
// Handles **bold** and [label](url) links inside Claude's text segments.

struct EmberTextView: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Text(attributed)
            .font(.system(size: 14))
            .foregroundColor(isUser ? .white : Color("InkColor"))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        var remaining = text

        // Bold: **text**
        let boldPattern = try! NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
        // Link: [label](url)
        let linkPattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\((https?://[^)]+)\)"#)

        // Build a combined list of ranges to process
        var tokens: [(range: Range<String.Index>, kind: TokenKind)] = []
        let nsStr = remaining as NSString

        for m in boldPattern.matches(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
            if let r = Range(m.range, in: remaining) { tokens.append((r, .bold(nsStr.substring(with: m.range(at: 1))))) }
        }
        for m in linkPattern.matches(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
            let label = nsStr.substring(with: m.range(at: 1))
            let href  = nsStr.substring(with: m.range(at: 2))
            if let r = Range(m.range, in: remaining) { tokens.append((r, .link(label, href))) }
        }
        tokens.sort { $0.range.lowerBound < $1.range.lowerBound }

        var cursor = remaining.startIndex
        for token in tokens {
            // plain text before this token
            if cursor < token.range.lowerBound {
                result += AttributedString(String(remaining[cursor..<token.range.lowerBound]))
            }
            switch token.kind {
            case .bold(let s):
                var a = AttributedString(s)
                a.font = .system(size: 14, weight: .semibold)
                result += a
            case .link(let label, let href):
                var a = AttributedString(label)
                a.foregroundColor = Color(red: 0.18, green: 0.77, blue: 0.71)
                a.underlineStyle = .single
                if let url = URL(string: href) { a.link = url }
                result += a
            }
            cursor = token.range.upperBound
        }
        if cursor < remaining.endIndex {
            result += AttributedString(String(remaining[cursor...]))
        }
        return result
    }

    enum TokenKind { case bold(String); case link(String, String) }
}

// MARK: - OpenTable Widget ───────────────────────────────────────────────────

struct OpenTableWidget: View {
    let payload: OTPayload
    let onTap: (URL) -> Void

    @State private var pressed = false

    private var bookingURL: URL {
        let id = payload.otID
        if !id.isEmpty && id != "0" {
            return URL(string: "https://www.opentable.com/restref/client/?rid=\(id)")!
        }
        let q = payload.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.opentable.com/s/?term=\(q)")!
    }

    private var meta: String {
        [payload.cuisine, payload.price, payload.neighborhood]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        Button(action: { onTap(bookingURL) }) {
            HStack(spacing: 10) {
                // Restaurant icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.98, green: 0.95, blue: 0.91))
                        .frame(width: 36, height: 36)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.85, green: 0.22, blue: 0.11))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("InkColor"))
                        .lineLimit(1)
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.system(size: 11))
                            .foregroundColor(Color("InkFaintColor"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // OT pill
                Text("Reserve")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.85, green: 0.22, blue: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.07), lineWidth: 0.5)
                    )
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
        .frame(maxWidth: 320)
    }
}

// MARK: - Flight Picker Widget ───────────────────────────────────────────────

struct FlightPickerWidget: View {
    let payload: FlightPayload
    let onTap: (URL) -> Void

    // Seeded illustrative options — same logic as the web widget
    struct FlightOption: Identifiable {
        let id = UUID()
        let airline: String
        let code: String
        let price: Int
        let departTime: String
        let arriveTime: String
        let duration: String
        let url: URL
    }

    private var options: [FlightOption] {
        let airlines = [
            ("American", "AA", 1.00),
            ("Delta",    "DL", 1.08),
            ("United",   "UA", 0.95),
            ("Spirit",   "NK", 0.72),
        ]
        let seed = (payload.origin + payload.destination)
            .unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let base = 149 + (seed % 180)
        let dHours = [6, 8, 11, 14]
        let durs: [Double] = [2.5, 3.0, 3.5, 5.0]

        func fmt(_ h: Double) -> String {
            let hour = Int(h) % 24
            let min  = h.truncatingRemainder(dividingBy: 1) == 0.5 ? "30" : "00"
            let ampm = hour < 12 ? "am" : "pm"
            let h12  = hour % 12 == 0 ? 12 : hour % 12
            return "\(h12):\(min)\(ampm)"
        }
        func durStr(_ d: Double) -> String {
            d < 1 ? "\(Int(d*60))m" : "\(Int(d))h\(d.truncatingRemainder(dividingBy:1) != 0 ? " 30m" : "")"
        }

        return airlines.enumerated().map { (i, al) in
            let price = Int((Double(base) * al.2 / 5).rounded()) * 5
            let dH = Double(dHours[i])
            let dur = durs[i]
            let q = "Flights+from+\(payload.origin)+to+\(payload.destination)+\(al.0)+\(payload.departDate)"
            let url = URL(string: "https://www.google.com/travel/flights?q=\(q)")!
            return FlightOption(
                airline: al.0, code: al.1, price: price,
                departTime: fmt(dH), arriveTime: fmt(dH + dur),
                duration: durStr(dur), url: url
            )
        }
    }

    private var allFlightsURL: URL {
        let q = "Flights+from+\(payload.origin)+to+\(payload.destination)+on+\(payload.departDate)"
        let ret = payload.returnDate.map { "+returning+\($0)" } ?? ""
        return URL(string: "https://www.google.com/travel/flights?q=\(q)\(ret)")!
    }

    private var routeLabel: String {
        "\(payload.origin) → \(payload.destination)"
    }

    private var dateLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d"
        var s = ""
        if let d = fmt.date(from: payload.departDate) { s = out.string(from: d) }
        if let ret = payload.returnDate, let d = fmt.date(from: ret) { s += " – " + out.string(from: d) }
        return s.isEmpty ? payload.departDate : s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "airplane")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color("TealColor"))
                Text("\(routeLabel) · \(dateLabel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color("InkFaintColor"))
                    .lineLimit(1)
            }

            // Card carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { opt in
                        FlightCard(option: opt, onTap: { onTap(opt.url) })
                    }

                    // "All flights" card
                    Button(action: { onTap(allFlightsURL) }) {
                        VStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TealColor"))
                            Text("All options")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            Text("Google Flights")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color("TealColor"))
                        }
                        .frame(width: 100, height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("InkColor"))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 4)
            }
        }
    }
}

struct FlightCard: View {
    let option: FlightPickerWidget.FlightOption
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.airline + " · " + option.code)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color("InkFaintColor"))

                Text("\(option.departTime) – \(option.arriveTime)")
                    .font(.system(size: 12))
                    .foregroundColor(Color("InkColor"))

                Text(option.duration + " · Nonstop")
                    .font(.system(size: 10))
                    .foregroundColor(Color("InkFaintColor"))

                Spacer()

                Text("from $\(option.price)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color("TealColor"))
            }
            .padding(12)
            .frame(width: 140, height: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(pressed ? Color("TealColor") : Color.black.opacity(0.07), lineWidth: pressed ? 1 : 0.5)
                    )
            )
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: - Draft Message Widget ───────────────────────────────────────────────

struct DraftMessageWidget: View {
    let payload: DraftPayload
    @State private var draftText: String
    @State private var isEditing = false
    @State private var showMessageComposer = false
    @FocusState private var editorFocused: Bool

    init(payload: DraftPayload) {
        self.payload = payload
        _draftText = State(initialValue: payload.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            HStack(spacing: 4) {
                Circle()
                    .fill(Color("TealColor"))
                    .frame(width: 5, height: 5)
                Text("DRAFT FOR \(payload.recipient.uppercased())")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color("TealColor"))
            }

            // Draft text / editor
            if isEditing {
                TextEditor(text: $draftText)
                    .font(.system(size: 14))
                    .foregroundColor(Color("InkColor"))
                    .frame(minHeight: 80)
                    .focused($editorFocused)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("TealColor").opacity(0.4), lineWidth: 1.5)
                    )
            } else {
                Text(draftText)
                    .font(.system(size: 14))
                    .foregroundColor(Color("InkColor"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: openInMessages) {
                    Label("Open in Messages", systemImage: "message.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color("InkColor"))
                        .clipShape(Capsule())
                }

                Button(action: toggleEdit) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("InkFaintColor"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                        )
                }

                Spacer()

                Button(action: copyDraft) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(Color("InkFaintColor"))
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("TealColor").opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color("TealColor").opacity(0.28),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                        )
                )
        )
        .frame(maxWidth: 320)
    }

    private func toggleEdit() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditing.toggle()
            if isEditing { editorFocused = true }
        }
    }

    private func openInMessages() {
        let encoded = draftText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:&body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func copyDraft() {
        UIPasteboard.general.string = draftText
        // haptic
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Safari View ────────────────────────────────────────────────────────

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(red: 0.18, green: 0.77, blue: 0.71, alpha: 1)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Color Extensions ───────────────────────────────────────────────────
// Add these named colors to Assets.xcassets:
//
//   Name            Light                 Dark
//   InkColor        #0e0d0b              #F7F5F0
//   InkSoftColor    #4a4843              #c8c5bf
//   InkFaintColor   #9a9690              #6b6865
//   TealColor       #2ec4b6              #2ec4b6
//   WarmColor       #F7F5F0              #1a1917
//
// Or use the UIColor hex extension from SupportingFiles.swift and create
// Color("TealColor") via UIColor adapter:
//
//   extension Color {
//       static let teal    = Color(UIColor(hex: "#2ec4b6"))
//       static let ink     = Color(UIColor(hex: "#0e0d0b"))
//       static let inkSoft = Color(UIColor(hex: "#4a4843"))
//   }
