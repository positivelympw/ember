//
//   DocumentView.swift
//  Ember
//
//  Created by Marcus Win on 4/5/26.
//

import Foundation
// DocumentView.swift
// Ember — Document Management UI
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// The Pro document management screen.
// Agents upload PDFs here, tag them to properties,
// and activate them for client Q&A conversations.
//
// This file teaches:
//   - UIDocumentPickerViewController in SwiftUI
//   - PDFKit text extraction
//   - File handling on iOS
//   - The coordinator pattern for UIKit delegates
// ============================================================

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// ============================================================
// LESSON: UIDocumentPickerViewController wrapped for SwiftUI
// The iOS file picker is a UIKit component — not native SwiftUI.
// We use UIViewControllerRepresentable to bridge it, exactly
// the same pattern as MessageComposerView.
//
// The picker lets users choose files from:
//   - Files app (local storage)
//   - iCloud Drive
//   - Dropbox, Google Drive (if installed)
//   - Email attachments
// ============================================================
struct DocumentPickerView: UIViewControllerRepresentable {

    let onPicked: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // UTType.pdf tells iOS we only want PDF files
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void

        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        // ============================================================
        // LESSON: Security-scoped resources
        // iOS sandboxes every app — you can't freely read files
        // outside your app's container.
        //
        // startAccessingSecurityScopedResource() asks iOS permission
        // to temporarily read an external file.
        // stopAccessingSecurityScopedResource() releases it when done.
        //
        // Always call stop after start — failure to do so is a
        // resource leak that Apple's reviewers will catch.
        // ============================================================
        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            onPicked(url)
        }
    }
}

// ============================================================
// MAIN DOCUMENT VIEW
// ============================================================
struct DocumentView: View {

    @ObservedObject var documentStore: DocumentStore

    @State private var showingPicker = false
    @State private var showingAddSheet = false
    @State private var isExtracting = false
    @State private var pendingURL: URL? = nil
    @State private var newPropertyAddress = ""
    @State private var newDocumentType: DocumentType = .listing
    @State private var selectedDocument: EmberDocument? = nil
    @State private var searchText = ""

    var filtered: [EmberDocument] {
        if searchText.isEmpty { return documentStore.documents }
        return documentStore.documents.filter {
            $0.fileName.localizedCaseInsensitiveContains(searchText) ||
            $0.propertyAddress.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if documentStore.documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .background(Color(red: 0.96, green: 0.95, blue: 0.93))
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingPicker = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                    }
                }
            }
            // File picker sheet
            .sheet(isPresented: $showingPicker) {
                DocumentPickerView { url in
                    pendingURL = url
                    showingPicker = false
                    showingAddSheet = true
                }
            }
            // Document details entry after picking
            .sheet(isPresented: $showingAddSheet) {
                addDocumentSheet
            }
            // Document detail view
            .sheet(item: $selectedDocument) { doc in
                DocumentDetailView(document: doc, documentStore: documentStore)
            }
        }
        // Show extraction progress
        .overlay {
            if isExtracting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("Reading document...")
                            .foregroundColor(.white)
                            .font(.system(size: 15))
                    }
                    .padding(24)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.09).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: Empty state

    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.3))
                .padding(.top, 80)

            Text("No documents yet")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))

            Text("Upload listings, disclosures, and leases.\nClients ask questions. Ember answers.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                    Text("Upload a document")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 0.5, green: 0.47, blue: 0.87))
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Document list

    var documentList: some View {
        List {
            // Active document section
            if let active = documentStore.activeDocument {
                Section {
                    ActiveDocumentRow(document: active) {
                        documentStore.activeDocument = nil
                    }
                } header: {
                    Text("Active for Q&A")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                }
            }

            // All documents
            Section {
                ForEach(filtered) { doc in
                    DocumentRow(
                        document: doc,
                        isActive: documentStore.activeDocument?.id == doc.id,
                        onActivate: {
                            documentStore.activeDocument = doc
                        },
                        onTap: {
                            selectedDocument = doc
                        }
                    )
                }
                .onDelete { indexSet in
                    indexSet.forEach { i in
                        documentStore.remove(filtered[i])
                    }
                }
            } header: {
                Text("\(documentStore.documents.count) document\(documentStore.documents.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search documents or addresses")
    }

    // MARK: Add document sheet

    var addDocumentSheet: some View {
        NavigationStack {
            Form {
                Section {
                    // ============================================================
                    // LESSON: Picker in a Form
                    // Picker inside a Form automatically gets the
                    // grouped list style with a disclosure chevron.
                    // The selection binding updates newDocumentType
                    // when the user picks a value.
                    // ============================================================
                    Picker("Document type", selection: $newDocumentType) {
                        ForEach(DocumentType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    HStack {
                        Image(systemName: "house")
                            .foregroundColor(.gray)
                        TextField("Property address (optional)", text: $newPropertyAddress)
                    }
                } header: {
                    Text("Tag this document")
                } footer: {
                    Text("Tagging to a property helps Ember find the right document when clients ask questions.")
                }

                if let url = pendingURL {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                            Text(url.lastPathComponent)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                        }
                    } header: {
                        Text("Selected file")
                    }
                }
            }
            .navigationTitle("Add document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSheet = false
                        pendingURL = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Extract") {
                        if let url = pendingURL {
                            extractAndSave(url: url)
                        }
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: PDF text extraction

    // ============================================================
    // LESSON: PDFKit text extraction
    // PDFKit is Apple's PDF framework — no third-party library needed.
    //
    // PDFDocument loads the file.
    // We iterate through every page and call string(for:)
    // to extract the text content from each page.
    //
    // The extracted text is plain — no formatting, no images.
    // That's exactly what we want: raw text for Claude to read.
    //
    // We do this on a background thread because large PDFs
    // can take a few seconds to process — same threading rule
    // as loadContacts(): slow work on background, UI on main.
    // ============================================================
    func extractAndSave(url: URL) {
        isExtracting = true
        showingAddSheet = false

        DispatchQueue.global(qos: .userInitiated).async {
            guard url.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async { isExtracting = false }
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Load the PDF
            guard let pdf = PDFDocument(url: url) else {
                DispatchQueue.main.async { isExtracting = false }
                return
            }

            // Extract text from every page
            var fullText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i),
                   let pageText = page.string {
                    fullText += pageText + "\n\n"
                }
            }

            let document = EmberDocument(
                fileName: url.lastPathComponent,
                propertyAddress: newPropertyAddress,
                documentType: newDocumentType,
                extractedText: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                pageCount: pdf.pageCount
            )

            DispatchQueue.main.async {
                isExtracting = false
                documentStore.add(document)
                // Auto-activate the newly uploaded document
                documentStore.activeDocument = document
                newPropertyAddress = ""
                newDocumentType = .listing
                pendingURL = nil
            }
        }
    }
}

// ============================================================
// DOCUMENT ROW
// One document in the list.
// Shows type icon, filename, property, page count.
// Activate button makes it the active Q&A context.
// ============================================================
struct DocumentRow: View {
    let document: EmberDocument
    let isActive: Bool
    let onActivate: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type icon with colored background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: document.documentType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(document.fileName)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                    .lineLimit(1)
                Text(document.displaySummary)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Active indicator or activate button
            if isActive {
                Text("Active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.5, green: 0.47, blue: 0.87))
                    .clipShape(Capsule())
            } else {
                Button(action: onActivate) {
                    Text("Use")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// ============================================================
// ACTIVE DOCUMENT ROW
// Shown at top when a document is active for Q&A.
// Clear button deactivates it.
// ============================================================
struct ActiveDocumentRow: View {
    let document: EmberDocument
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                    .lineLimit(1)
                Text("Ember is answering questions from this document")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// ============================================================
// DOCUMENT DETAIL VIEW
// Full screen view of extracted text.
// Shows metadata, extracted content, and allows editing
// the property address or document type.
// ============================================================
struct DocumentDetailView: View {
    @State var document: EmberDocument
    let documentStore: DocumentStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metadata card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: document.documentType.icon)
                                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                            Text(document.documentType.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.47, blue: 0.87))
                            Spacer()
                            Text("\(document.pageCount) pages")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }

                        Divider()

                        HStack {
                            Image(systemName: "house")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            TextField("Property address", text: $document.propertyAddress)
                                .font(.system(size: 15))
                                .onSubmit { documentStore.update(document) }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Extracted text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted text")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)

                        Text(document.extractedText.isEmpty
                             ? "No text could be extracted from this document."
                             : document.extractedText)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
                            .lineSpacing(4)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.96, green: 0.95, blue: 0.93))
            .navigationTitle(document.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        documentStore.update(document)
                        dismiss()
                    }
                }
            }
        }
    }
}

// ============================================================
// THEME STORE placeholder for DocumentView
// DocumentView uses themeStore colors. If you move DocumentView
// to a separate file without ContentView, add this.
// Currently DocumentView is injected from ContentView where
// ThemeStore is already available via @EnvironmentObject.
// ============================================================
// Note: ThemeStore is defined in EmberTheme.swift.
// If you get "cannot find ThemeStore in scope" add:
// import Foundation at top of this file and ensure
// EmberTheme.swift is in the same target.
