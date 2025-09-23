//
//  ExportComponents.swift
//  DayPlanner
//
//  Export and history components extracted from DayPlannerApp.swift
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Document

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - History Log View

struct HistoryLogView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if dataManager.appState.preferences.keepUndoHistory {
                    Text("History logging is enabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("History log functionality would be implemented here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text("History logging is disabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("History Log")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
    }
}
