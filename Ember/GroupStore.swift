// GroupStore.swift
// Ember — Group Threads
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// GroupStore owns named groups — collections of CircleMembers
// with shared context and conversation history.
//
// A group is different from a person:
//   - Multiple members contribute to one shared context
//   - Ember coordinates between members, not just with one
//   - Groups have types: social (friends) or org (teams)
//   - Groups can link to a document for enterprise use
//
// Same persistence pattern as CircleStore:
//   ObservableObject + @Published + UserDefaults + Codable
// ============================================================

import Foundation
import SwiftUI
import Combine

// ============================================================
// LESSON: Nested Codable structs
// GroupMessage is Codable so it can be stored inside
// EmberGroup which is also Codable.
// The entire object tree serializes to JSON in one call.
// ============================================================
struct GroupMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isFromUser: Bool
    let createdAt: Date

    init(id: String = UUID().uuidString,
         content: String,
         isFromUser: Bool) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.createdAt = Date()
    }
}

struct EmberGroup: Identifiable, Codable {
    let id: String
    var name: String
    var groupType: GroupType
    var memberIDs: [String]        // References CircleMember IDs
    var sharedContext: String      // What this group is about
    var activeDocumentID: String?  // Linked enterprise document
    var conversationHistory: [GroupMessage]
    var lastActiveAt: Date
    var createdAt: Date

    // ============================================================
    // LESSON: Computed properties on Codable structs
    // These derive values from stored data — never stored themselves.
    // They are excluded from Codable automatically because they
    // have no stored property backing them.
    // ============================================================
    var displayMemberCount: String {
        memberIDs.isEmpty ? "No members" :
        memberIDs.count == 1 ? "1 person" :
        "\(memberIDs.count) people"
    }

    var lastMessage: GroupMessage? {
        conversationHistory.last
    }

    init(id: String = UUID().uuidString,
         name: String,
         groupType: GroupType = .social,
         memberIDs: [String] = []) {
        self.id = id
        self.name = name
        self.groupType = groupType
        self.memberIDs = memberIDs
        self.sharedContext = ""
        self.activeDocumentID = nil
        self.conversationHistory = []
        self.lastActiveAt = Date()
        self.createdAt = Date()
    }
}

enum GroupType: String, Codable, CaseIterable {
    case social       = "social"
    case organization = "organization"

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

    var prompt: String {
        switch self {
        case .social:
            return "This is a social group — friends or people coordinating plans."
        case .organization:
            return "This is an organizational group — a team, project, or professional context."
        }
    }
}

final class GroupStore: ObservableObject {

    @Published var groups: [EmberGroup] = []

    private let storageKey = "ember.groups.v1"

    init() { load() }

    // MARK: CRUD

    func create(name: String, type: GroupType, memberIDs: [String]) -> EmberGroup {
        let group = EmberGroup(name: name, groupType: type, memberIDs: memberIDs)
        groups.append(group)
        save()
        return group
    }

    func update(_ group: EmberGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            save()
        }
    }

    func delete(_ group: EmberGroup) {
        groups.removeAll { $0.id == group.id }
        save()
    }

    func group(for id: String) -> EmberGroup? {
        groups.first { $0.id == id }
    }

    // MARK: Messages

    func addMessage(_ message: GroupMessage, to groupID: String) {
        if let index = groups.firstIndex(where: { $0.id == groupID }) {
            groups[index].conversationHistory.append(message)
            groups[index].lastActiveAt = Date()
            save()
        }
    }

    func clearHistory(for groupID: String) {
        if let index = groups.firstIndex(where: { $0.id == groupID }) {
            groups[index].conversationHistory = []
            save()
        }
    }

    // MARK: Members

    func addMember(_ memberID: String, to groupID: String) {
        if let index = groups.firstIndex(where: { $0.id == groupID }) {
            guard !groups[index].memberIDs.contains(memberID) else { return }
            groups[index].memberIDs.append(memberID)
            save()
        }
    }

    func removeMember(_ memberID: String, from groupID: String) {
        if let index = groups.firstIndex(where: { $0.id == groupID }) {
            groups[index].memberIDs.removeAll { $0 == memberID }
            save()
        }
    }

    // MARK: Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([EmberGroup].self, from: data)
        else { return }
        groups = saved
    }
}
