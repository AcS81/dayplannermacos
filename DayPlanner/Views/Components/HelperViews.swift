//
//  HelperViews.swift
//  DayPlanner
//
//  Helper views and components extracted from DayPlannerApp.swift
//

import SwiftUI

// MARK: - Helper Views

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(16)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct PillarEditView: View {
    let pillar: Pillar
    let onSave: (Pillar) -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var frequency: PillarFrequency
    @Environment(\.dismiss) private var dismiss
    
    init(pillar: Pillar, onSave: @escaping (Pillar) -> Void) {
        self.pillar = pillar
        self.onSave = onSave
        self._name = State(initialValue: pillar.name)
        self._description = State(initialValue: pillar.description)
        self._frequency = State(initialValue: pillar.frequency)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PillarFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Edit Pillar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedPillar = pillar
                        updatedPillar.name = name
                        updatedPillar.description = description
                        updatedPillar.frequency = frequency
                        onSave(updatedPillar)
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct ChainEditView: View {
    let chain: Chain
    let onSave: (Chain) -> Void
    
    @State private var name: String
    @State private var blocks: [TimeBlock]
    
    init(chain: Chain, onSave: @escaping (Chain) -> Void) {
        self.chain = chain
        self.onSave = onSave
        self._name = State(initialValue: chain.name)
        self._blocks = State(initialValue: chain.blocks)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Chain Name", text: $name)
                }
                
                Section("Time Blocks") {
                    ForEach($blocks, id: \.id) { $block in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Title", text: $block.title)
                            
                            HStack {
                                Text("Duration:")
                                Stepper("\(Int(block.duration/60))min", 
                                       value: Binding(
                                           get: { Double(block.duration/60) },
                                           set: { newValue in
                                               block.duration = TimeInterval(newValue * 60)
                                           }
                                       ), 
                                       in: 5...480, 
                                       step: 5)
                                Spacer()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button("Add Block") {
                        let newBlock = TimeBlock(
                            title: "New Activity",
                            startTime: Date(),
                            duration: 30 * 60,
                            energy: .daylight,
                            emoji: "📋"
                        )
                        blocks.append(newBlock)
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Edit Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave(chain) // Cancel without changes
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedChain = chain
                        updatedChain.name = name
                        updatedChain.blocks = blocks
                        onSave(updatedChain)
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - AI Diagnostics View

struct AIDiagnosticsView: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var diagnosticsText = "Running diagnostics..."
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AI Service Diagnostics")
                    .font(.headline)
                
                ScrollView {
                    Text(diagnosticsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 300)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                
                HStack {
                    Button("Refresh") {
                        runDiagnostics()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Test Connection") {
                        testConnection()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("AI Diagnostics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            runDiagnostics()
        }
    }
    
    private func runDiagnostics() {
        diagnosticsText = "Running diagnostics...\n\n"
        
        Task {
            let result = await aiService.runDiagnostics()
            await MainActor.run {
                diagnosticsText = result
            }
        }
    }
    
    private func testConnection() {
        diagnosticsText += "\n\nTesting connection...\n"
        
        Task {
            let result = await aiService.testConnection()
            await MainActor.run {
                diagnosticsText += result
            }
        }
    }
}
