import SwiftUI

struct CalendarChatBar: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var inputText: String = ""
    @State private var activeBlock: TimeBlock?
    @State private var isSending = false
    @State private var editingBlock: TimeBlock?
    @State private var undoCandidate: Record?
    @FocusState private var isFocused: Bool
    
    private var currentPrompt: String {
        if let block = activeBlock {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: block.startTime)
            return "How did \(block.title) at \(timeString) go?"
        }
        return "What should I plan next?"
    }
    
    private var isConfirming: Bool {
        activeBlock != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isConfirming ? "questionmark.circle" : "sparkles")
                    .font(.title3)
                    .foregroundStyle(isConfirming ? .blue : .purple)
                Text(currentPrompt)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            if let record = undoCandidate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Recorded \(record.title). Undo?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Undo", action: undoLastConfirmation)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }
            }
            
            if let block = activeBlock {
                HStack(spacing: 8) {
                    ChatActionButton(title: "Confirm", systemImage: "checkmark.circle.fill", tint: .green) {
                        confirm(block: block, notes: inputText)
                    }
                    ChatActionButton(title: "Edit & Confirm", systemImage: "pencil.circle", tint: .blue) {
                        editingBlock = block
                    }
                    ChatActionButton(title: "Re-queue", systemImage: "arrow.uturn.left.circle", tint: .orange) {
                        requeue(block: block, notes: inputText)
                    }
                }
            }
            
            HStack(spacing: 12) {
                TextField("Type a quick reply…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSending)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(handleSend)
                
                Button(action: handleSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(isSending ? Color.gray : Color.blue, in: Circle())
                }
                .disabled(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            HStack(spacing: 10) {
                ChatChip(title: "Tell me what you did") {
                    handleTellMeChip()
                }
                ChatChip(title: "Ask me to book") {
                    handleAskMeChip()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .onAppear(perform: refreshPrompt)
        .onChange(of: dataManager.appState.currentDay.blocks) { _, _ in
            refreshPrompt()
        }
        .sheet(item: $editingBlock) { block in
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: dataManager.appState.currentDay.blocks,
                onSave: { updatedBlock in
                    dataManager.updateTimeBlock(updatedBlock)
                    dataManager.confirmBlock(updatedBlock.id, notes: updatedBlock.notes)
                    editingBlock = nil
                    refreshPrompt()
                },
                onDelete: {
                    dataManager.removeTimeBlock(block.id)
                    editingBlock = nil
                    refreshPrompt()
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private func refreshPrompt() {
        dataManager.refreshPastBlocks()
        activeBlock = dataManager.nextUnconfirmedBlock()
        if activeBlock == nil {
            isFocused = false
        }
    }
    
    private func handleSend() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        if let block = activeBlock {
            handleConfirmationReply(trimmed, for: block)
        } else {
            sendPlanningMessage(trimmed)
        }
        inputText = ""
    }
    
    private func handleConfirmationReply(_ message: String, for block: TimeBlock) {
        let lowered = message.lowercased()
        if lowered.contains("requeue") || lowered.contains("later") || lowered.contains("tomorrow") || lowered.contains("reschedule") || lowered.contains("no") {
            requeue(block: block, notes: message)
        } else {
            confirm(block: block, notes: message)
        }
    }
    
    private func confirm(block: TimeBlock, notes: String?) {
        dataManager.confirmBlock(block.id, notes: notes)
        undoCandidate = dataManager.appState.records.last
        refreshPrompt()
    }
    
    private func requeue(block: TimeBlock, notes: String?) {
        dataManager.requeueBlock(block.id, notes: notes)
        refreshPrompt()
    }
    
    private func sendPlanningMessage(_ message: String) {
        isSending = true
        Task {
            let context = dataManager.createEnhancedContext(date: dataManager.appState.currentDay.date)
            do {
                _ = try await aiService.getSuggestions(for: message, context: context)
            } catch {
                // For now we silently ignore failures; logging could be added here
            }
            await MainActor.run {
                isSending = false
                refreshPrompt()
            }
        }
    }
    
    private func handleTellMeChip() {
        if let block = activeBlock {
            inputText = "I spent that time on \(block.title.lowercased())."
            isFocused = true
        } else {
            inputText = "I just wrapped something up."
            isFocused = true
        }
    }
    
    private func handleAskMeChip() {
        if isConfirming {
            if let block = activeBlock {
                requeue(block: block, notes: "Please reschedule this.")
            }
        } else {
            inputText = "Can you book the next thing for me?"
            isFocused = true
        }
    }
    
    private func undoLastConfirmation() {
        guard let record = undoCandidate else { return }
        dataManager.undoRecord(record.id)
        undoCandidate = nil
        refreshPrompt()
    }
}

private struct ChatChip: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ChatActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }
}
