// MemoryStore.swift
// Ember — Cross-Session Conversation Memory
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// MemoryStore persists conversation summaries across sessions.
//
// The problem: UserDefaults can't store thousands of messages.
// The solution: after each conversation, ask Claude to
// summarize what was discussed into 2-3 sentences.
// Store that summary. Inject it next session.
//
// This is how Ember "remembers" without storing raw history.
// It's also more useful than raw history — a summary surfaces
// the signal, not the noise.
//
// ============================================================
// LESSON: Summary-based memory
// ============================================================
// This pattern mirrors how humans actually remember conversations.
// You don't recall every word — you recall what mattered.
// "We talked about Marcus's job change and decided to grab
// coffee next week" is more useful to Ember than 40 raw messages.
//
// The summary becomes part of the system prompt on the next
// session — Ember walks into the conversation already knowing
// what happened last time.
// ============================================================

import Foundation
import SwiftUI
import Combine

// ============================================================
// LESSON: Two separate memory types
// PersonMemory: one entry per CircleMember
// GroupMemory: one entry per EmberGroup
// Both follow the same structure — id, summary, updatedAt.
// Keeping them separate makes lookup fast and clear.
// ============================================================
struct PersonMemory: Identifiable, Codable {
    let id: String          // CircleMember ID
    var summary: String     // Claude-generated summary
    var updatedAt: Date
    var sessionCount: Int   // How many sessions we've had

    init(id: String, summary: String) {
        self.id = id
        self.summary = summary
        self.updatedAt = Date()
        self.sessionCount = 1
    }
}

struct GroupMemory: Identifiable, Codable {
    let id: String          // EmberGroup ID
    var summary: String
    var updatedAt: Date
    var sessionCount: Int

    init(id: String, summary: String) {
        self.id = id
        self.summary = summary
        self.updatedAt = Date()
        self.sessionCount = 1
    }
}

final class MemoryStore: ObservableObject {

    @Published var personMemories: [PersonMemory] = []
    @Published var groupMemories: [GroupMemory] = []

    private let personKey = "ember.memory.persons.v1"
    private let groupKey  = "ember.memory.groups.v1"

    init() { load() }

    // MARK: Read

    func summary(for personID: String) -> String? {
        personMemories.first { $0.id == personID }?.summary
    }

    func groupSummary(for groupID: String) -> String? {
        groupMemories.first { $0.id == groupID }?.summary
    }

    // ============================================================
    // LESSON: Building context strings for injection
    // We format the memory as a clear instruction to Claude:
    // "Here is what happened in previous sessions."
    // This framing tells Claude to treat it as established
    // background, not as something to verify or question.
    // ============================================================
    func contextString(for personID: String, name: String) -> String {
        guard let summary = summary(for: personID) else { return "" }
        return """
            PREVIOUS SESSIONS WITH \(name.uppercased()):
            \(summary)
            """
    }

    func groupContextString(for groupID: String, name: String) -> String {
        guard let summary = groupSummary(for: groupID) else { return "" }
        return """
            PREVIOUS SESSIONS IN \(name.uppercased()):
            \(summary)
            """
    }

    // MARK: Write

    func updatePersonMemory(id: String, summary: String) {
        if let index = personMemories.firstIndex(where: { $0.id == id }) {
            personMemories[index].summary = summary
            personMemories[index].updatedAt = Date()
            personMemories[index].sessionCount += 1
        } else {
            personMemories.append(PersonMemory(id: id, summary: summary))
        }
        savePersonMemories()
    }

    func updateGroupMemory(id: String, summary: String) {
        if let index = groupMemories.firstIndex(where: { $0.id == id }) {
            groupMemories[index].summary = summary
            groupMemories[index].updatedAt = Date()
            groupMemories[index].sessionCount += 1
        } else {
            groupMemories.append(GroupMemory(id: id, summary: summary))
        }
        saveGroupMemories()
    }

    func clearPersonMemory(for id: String) {
        personMemories.removeAll { $0.id == id }
        savePersonMemories()
    }

    func clearGroupMemory(for id: String) {
        groupMemories.removeAll { $0.id == id }
        saveGroupMemories()
    }

    // MARK: Summary generation

    // ============================================================
    // LESSON: Asking Claude to summarize Claude's own output
    // We send the conversation history back to Claude with
    // a specific instruction: summarize this for future context.
    //
    // The resulting summary is dense and useful — Claude knows
    // what matters from its own perspective.
    //
    // We call this when the user leaves a conversation thread.
    // It runs in the background — the user never sees it happen.
    // ============================================================
    func generateSummary(
        for messages: [(role: String, content: String)],
        personName: String? = nil,
        groupName: String? = nil,
        apiKey: String,
        completion: @escaping (String) -> Void
    ) {
        guard !messages.isEmpty else { return }

        let subject = personName ?? groupName ?? "this conversation"
        let transcript = messages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")

        let prompt = """
            Summarize this conversation about \(subject) in 2-3 sentences.
            Focus on: what was discussed, any decisions made, any context
            about the person or situation that would be useful next time.
            Be specific — names, dates, and concrete details matter.
            Write in third person as if briefing someone before their next conversation.

            CONVERSATION:
            \(transcript)
            """

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 200,
            "messages": [["role": "user", "content": prompt]]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let content = json["content"] as? [[String: Any]],
                let text = content.first?["text"] as? String
            else { return }

            DispatchQueue.main.async {
                completion(text)
            }
        }.resume()
    }

    // MARK: Persistence

    private func savePersonMemories() {
        guard let data = try? JSONEncoder().encode(personMemories) else { return }
        UserDefaults.standard.set(data, forKey: personKey)
    }

    private func saveGroupMemories() {
        guard let data = try? JSONEncoder().encode(groupMemories) else { return }
        UserDefaults.standard.set(data, forKey: groupKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: personKey),
           let saved = try? JSONDecoder().decode([PersonMemory].self, from: data) {
            personMemories = saved
        }
        if let data = UserDefaults.standard.data(forKey: groupKey),
           let saved = try? JSONDecoder().decode([GroupMemory].self, from: data) {
            groupMemories = saved
        }
    }
}
