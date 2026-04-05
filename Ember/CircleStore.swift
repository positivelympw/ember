//
//  CircleStore.swift
//  Ember
//
//  Created by Marcus Win on 4/4/26.
//
// Ember — Personal Circle & Relationship Memory
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// CircleStore owns the user's personal circle — the specific
// people Ember pays attention to.
//
// It does three things:
//   1. Holds the list of CircleMembers in memory
//   2. Saves to UserDefaults when anything changes
//   3. Loads back when the app opens
//
// Keeping this in its own file means ContentView stays
// focused on the UI. This is called separation of concerns —
// each file has one job.
// ============================================================

import Foundation
import SwiftUI
import Combine

// ============================================================
// LESSON: Codable
// Codable means Swift can automatically convert this struct
// to and from JSON. We need this to save to UserDefaults.
//
// UserDefaults stores Data (raw bytes), not Swift structs.
// Codable handles the translation both ways:
//   Struct → JSON Data (saving)
//   JSON Data → Struct (loading)
// ============================================================
struct CircleMember: Identifiable, Codable {
    let id: String
    var name: String
    var phone: String

    // ============================================================
    // Relationship memory — filled through conversation.
    // Not read from private data. The user tells Ember.
    // The more context here, the more personal Ember feels.
    // ============================================================
    var lastConnectedDescription: String  // "grabbed coffee in February"
    var sharedContext: String             // "met in college, both love hiking"
    var currentContext: String            // "just started a new job"
    var driftLevel: DriftLevel
    var addedAt: Date

    // ============================================================
    // LESSON: Computed property
    // firstName is calculated from name each time it's read.
    // We never store it separately — it stays in sync
    // automatically because it's derived from name.
    // ============================================================
    var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }

    // ============================================================
    // LESSON: Custom initialiser
    // We define init so new members always start in a clean
    // default state. Callers only need to provide id, name,
    // and phone — the rest fills in automatically.
    // ============================================================
    init(id: String, name: String, phone: String) {
        self.id = id
        self.name = name
        self.phone = phone
        self.lastConnectedDescription = ""
        self.sharedContext = ""
        self.currentContext = ""
        self.driftLevel = .unknown
        self.addedAt = Date()
    }
}

// ============================================================
// LESSON: enum DriftLevel
// An enum defines a fixed set of possible values.
// DriftLevel can only ever be one of these four things —
// the compiler prevents any other value.
//
// Using an enum instead of a String prevents bugs:
//   "conected" would compile. .conected would not.
// ============================================================
enum DriftLevel: String, Codable, CaseIterable {
    case connected  // In good touch recently
    case drifting   // Haven't connected in a while
    case distant    // It's been a long time
    case unknown    // No signal yet

    var color: Color {
        switch self {
        case .connected: return .green
        case .drifting:  return Color(red: 0.5, green: 0.47, blue: 0.87)
        case .distant:   return .orange
        case .unknown:   return .gray
        }
    }

    var label: String {
        switch self {
        case .connected: return "Connected"
        case .drifting:  return "Drifting"
        case .distant:   return "Distant"
        case .unknown:   return "New"
        }
    }
}

// ============================================================
// LESSON: ObservableObject
// CircleStore is a class, not a struct.
// Classes are reference types — one shared instance
// that multiple views can all read and write.
//
// ObservableObject means any SwiftUI view watching this
// will automatically redraw when @Published data changes.
// ============================================================
final class CircleStore: ObservableObject {

    // @Published: changes to members trigger view redraws
    @Published var members: [CircleMember] = []

    private let storageKey = "ember.circle.v1"

    init() {
        load()
    }

    // MARK: Add

    func add(_ contact: Contact) {
        // Prevent duplicates — same person can't be in circle twice
        guard !members.contains(where: { $0.id == contact.id }) else { return }
        members.append(CircleMember(id: contact.id, name: contact.name, phone: contact.phone))
        save()
    }

    // MARK: Remove

    func remove(_ member: CircleMember) {
        members.removeAll { $0.id == member.id }
        save()
    }

    // MARK: Update

    // Called after Ember learns something new about a person
    func update(_ member: CircleMember) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index] = member
            save()
        }
    }

    // MARK: Lookup

    func member(for contactID: String) -> CircleMember? {
        members.first { $0.id == contactID }
    }

    func isInCircle(_ contactID: String) -> Bool {
        members.contains { $0.id == contactID }
    }

    // MARK: Persistence

    // ============================================================
    // LESSON: Saving with JSONEncoder
    // JSONEncoder().encode(members) converts [CircleMember]
    // into JSON Data — a sequence of bytes.
    // UserDefaults.standard.set stores that permanently.
    //
    // try? means "attempt this — if it fails, return nil."
    // The guard exits early if encoding fails (very rare).
    // ============================================================
    private func save() {
        guard let data = try? JSONEncoder().encode(members) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // ============================================================
    // LESSON: Loading with JSONDecoder
    // Reverse the save process:
    //   Read Data from UserDefaults
    //   Decode back into [CircleMember]
    //
    // If either step fails (first launch, corrupted data),
    // guard exits early and members stays empty — safe fallback.
    // ============================================================
    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([CircleMember].self, from: data)
        else { return }
        members = saved
    }
}
