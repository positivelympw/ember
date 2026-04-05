//
//  DocumentStore.swift
//  Ember
//
//  Created by Marcus Win on 4/5/26.
//

import Foundation

// DocumentStore.swift
// Ember — Document Intelligence Layer
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// DocumentStore manages the agent's uploaded documents.
// It does for documents what CircleStore does for people:
//   1. Holds the list of EmberDocuments in memory
//   2. Saves to UserDefaults when anything changes
//   3. Loads back when the app opens
//
// The extracted text from each document is what gets injected
// into Claude's context window when a client asks a question.
// This is called Retrieval-Augmented Generation (RAG) —
// grounding AI responses in real, specific documents rather
// than general knowledge.
// ============================================================
//
// ============================================================
// LESSON: What is RAG?
// ============================================================
// Large language models know a lot — but they don't know YOUR
// documents. Without RAG, if a client asks "what's the HOA fee
// on 123 Main St?" Claude has to guess or admit it doesn't know.
//
// With RAG:
//   1. Agent uploads the listing PDF
//   2. Ember extracts the text
//   3. When client asks, Ember finds relevant sections
//   4. Those sections go into the Claude system prompt
//   5. Claude answers accurately from the actual document
//
// The document text becomes part of Claude's "knowledge"
// for that conversation — without retraining the model.
// ============================================================

import Foundation
import SwiftUI
import Combine

// ============================================================
// LESSON: struct EmberDocument
// Same Codable pattern as CircleMember.
// extractedText is the raw text pulled from the PDF —
// this is what gets sent to Claude as context.
// ============================================================
struct EmberDocument: Identifiable, Codable {
    let id: String
    var fileName: String
    var propertyAddress: String   // Tag to a property for filtering
    var documentType: DocumentType
    var extractedText: String     // The content Claude reads
    var uploadedAt: Date
    var pageCount: Int

    // ============================================================
    // LESSON: Computed property for display
    // A clean summary string for the document list UI.
    // Derived from stored properties — never stored separately.
    // ============================================================
    var displaySummary: String {
        "\(documentType.displayName) · \(pageCount) pages · \(propertyAddress.isEmpty ? "No property tagged" : propertyAddress)"
    }

    init(id: String = UUID().uuidString,
         fileName: String,
         propertyAddress: String = "",
         documentType: DocumentType = .other,
         extractedText: String,
         pageCount: Int) {
        self.id = id
        self.fileName = fileName
        self.propertyAddress = propertyAddress
        self.documentType = documentType
        self.extractedText = extractedText
        self.pageCount = pageCount
        self.uploadedAt = Date()
    }
}

// ============================================================
// LESSON: enum DocumentType
// Fixed set of real estate document categories.
// Drives filtering, display, and context injection logic.
// Adding a new type here automatically works everywhere.
// ============================================================
enum DocumentType: String, Codable, CaseIterable {
    case listing     = "listing"
    case disclosure  = "disclosure"
    case lease       = "lease"
    case inspection  = "inspection"
    case offer       = "offer"
    case other       = "other"

    var displayName: String {
        switch self {
        case .listing:    return "Listing"
        case .disclosure: return "Disclosure"
        case .lease:      return "Lease"
        case .inspection: return "Inspection"
        case .offer:      return "Offer"
        case .other:      return "Document"
        }
    }

    var icon: String {
        switch self {
        case .listing:    return "house"
        case .disclosure: return "doc.text"
        case .lease:      return "signature"
        case .inspection: return "checklist"
        case .offer:      return "dollarsign.circle"
        case .other:      return "doc"
        }
    }
}

// ============================================================
// LESSON: ObservableObject + @Published — same pattern as CircleStore
// Any view that reads documents redraws when the list changes.
// Consistency matters: every store in Ember follows this pattern.
// ============================================================
final class DocumentStore: ObservableObject {

    @Published var documents: [EmberDocument] = []

    // Active document — when set, its text is injected into
    // every Claude call as context. This is the RAG mechanism.
    @Published var activeDocument: EmberDocument? = nil

    private let storageKey = "ember.documents.v1"

    init() { load() }

    // MARK: Add

    func add(_ document: EmberDocument) {
        documents.append(document)
        save()
    }

    // MARK: Remove

    func remove(_ document: EmberDocument) {
        documents.removeAll { $0.id == document.id }
        if activeDocument?.id == document.id {
            activeDocument = nil
        }
        save()
    }

    // MARK: Update

    func update(_ document: EmberDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
            save()
        }
    }

    // MARK: Filtering

    // Documents for a specific property address
    func documents(for address: String) -> [EmberDocument] {
        documents.filter { $0.propertyAddress.localizedCaseInsensitiveContains(address) }
    }

    // ============================================================
    // LESSON: Building context for Claude — the RAG injection
    // This is the core of the document intelligence feature.
    // We take the extracted text and wrap it in clear instructions
    // so Claude knows: "answer questions using ONLY this content."
    //
    // The character limit prevents exceeding Claude's context window.
    // 8000 characters ≈ ~2000 tokens — safe for most documents.
    // Longer documents need chunking (a future enhancement).
    // ============================================================
    func buildDocumentContext() -> String {
        guard let doc = activeDocument else { return "" }

        let truncated = doc.extractedText.count > 8000
            ? String(doc.extractedText.prefix(8000)) + "\n\n[Document truncated — showing first portion]"
            : doc.extractedText

        return """
            DOCUMENT CONTEXT:
            Type: \(doc.documentType.displayName)
            File: \(doc.fileName)
            Property: \(doc.propertyAddress.isEmpty ? "Not specified" : doc.propertyAddress)

            CONTENT:
            \(truncated)

            INSTRUCTIONS:
            Answer questions using the document content above.
            Be specific — reference exact figures, dates, and terms from the document.
            If the answer is not in the document, say so clearly.
            Do not invent or assume information not present in the document.
            """
    }

    // MARK: Persistence — same JSONEncoder/Decoder pattern as CircleStore

    private func save() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([EmberDocument].self, from: data)
        else { return }
        documents = saved
    }
}
