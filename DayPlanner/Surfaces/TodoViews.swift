//
//  TodoViews.swift
//  DayPlanner
//
//  To-Do List Components for Calendar Panel
//

import SwiftUI

// MARK: - To-Do Data Model

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var dueDate: Date?
    var isCompleted: Bool = false
    var createdDate: Date = Date()
    
    var dueDateString: String {
        guard let dueDate = dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: dueDate)
    }
}

// MARK: - To-Do List View

struct TodoListView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var todoItems: [TodoItem] = []
    @State private var newTodoTitle = ""
    @State private var showingAddTodo = false
    
    var body: some View {
        VStack(spacing: 0) {
            // To-Do Header
            HStack {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundStyle(.blue)
                
                Text("To-Do")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingAddTodo.toggle() }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .padding(6)
                        .background(.blue.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.3))
            
            // To-Do Items List
            if todoItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("No pending items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("Add your first todo") {
                        showingAddTodo = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(todoItems) { item in
                            TodoItemRow(
                                item: item,
                                onToggleComplete: { toggleComplete(item) },
                                onReschedule: { rescheduleItem(item) },
                                onAddToTimeline: { addToTimeline(item) },
                                onShowContextMenu: { showContextMenu(item) },
                                onDelete: { deleteItem(item) },
                                onDrag: { _ in dragItem(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingAddTodo) {
            AddTodoSheet { title, dueDate in
                addTodoItem(title: title, dueDate: dueDate)
            }
        }
        .onAppear {
            loadTodoItems()
        }
    }
    
    private func loadTodoItems() {
        // Load from data manager or create sample data
        todoItems = [
            TodoItem(title: "Review project proposal", dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())),
            TodoItem(title: "Call dentist for appointment", dueDate: nil),
            TodoItem(title: "Buy groceries for weekend", dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())),
            TodoItem(title: "Prepare presentation slides", dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()))
        ]
    }
    
    private func addTodoItem(title: String, dueDate: Date?) {
        let newItem = TodoItem(title: title, dueDate: dueDate)
        todoItems.append(newItem)
    }
    
    private func toggleComplete(_ item: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == item.id }) {
            todoItems[index].isCompleted.toggle()
        }
    }
    
    private func rescheduleItem(_ item: TodoItem) {
        // TODO: Show date picker for rescheduling
    }
    
    private func addToTimeline(_ item: TodoItem) {
        // TODO: Add to timeline via drag and drop or direct action
    }
    
    private func showContextMenu(_ item: TodoItem) {
        // TODO: Show context menu with more options
    }
    
    private func deleteItem(_ item: TodoItem) {
        todoItems.removeAll { $0.id == item.id }
    }
    
    private func dragItem(_ item: TodoItem) {
        // This function is called when drag ends
        // The actual drop handling is done by the timeline's drop delegate
        // We could optionally remove the item from the todo list here if it was successfully dropped
        // For now, we'll keep it in the todo list until explicitly completed
    }
}

// MARK: - To-Do Item Row

struct TodoItemRow: View {
    let item: TodoItem
    let onToggleComplete: () -> Void
    let onReschedule: () -> Void
    let onAddToTimeline: () -> Void
    let onShowContextMenu: () -> Void
    let onDelete: () -> Void
    let onDrag: (TodoItem) -> Void
    @State private var isPressed = false
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion checkbox
            Button(action: onToggleComplete) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                
                if item.dueDate != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(item.dueDateString)
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Reschedule button
                Button(action: onReschedule) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(.orange.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Reschedule")
                
                // Add to timeline button
                Button(action: onAddToTimeline) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(6)
                        .background(.blue.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Add to timeline")
                
                // Context menu button
                Button(action: onShowContextMenu) {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.secondary.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .help("More options")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(isDragging ? 0.6 : 0.3), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(isDragging ? 0.3 : 0.1), lineWidth: isDragging ? 2 : 1)
        )
        .scaleEffect(isDragging ? 0.95 : (isPressed ? 0.98 : 1.0))
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.2 : 0.05), radius: isDragging ? 4 : 1, y: isDragging ? 2 : 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onDrag {
            createDragProvider()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    isDragging = false
                    dragOffset = .zero
                    onDrag(item)
                }
        )
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    private func createDragProvider() -> NSItemProvider {
        // Create a detailed drag payload for todo item
        let dueDateString = item.dueDate?.timeIntervalSince1970.description ?? "nil"
        let dragPayload = "todo_item:\(item.title)|\(item.id.uuidString)|\(dueDateString)|\(item.isCompleted)"
        return NSItemProvider(object: dragPayload as NSString)
    }
}

// MARK: - Add To-Do Sheet

struct AddTodoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    
    let onAdd: (String, Date?) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Todo Title")
                        .font(.headline)
                    
                    TextField("Enter todo title...", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Set due date", isOn: $hasDueDate)
                        .font(.headline)
                    
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Todo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(title, hasDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }
}

