import SwiftUI
import CoreLocation

struct TaskListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingNewTask = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var searchText = ""
    
    enum TaskFilter {
        case all, today, upcoming, completed
        
        var description: String {
            switch self {
            case .all: return "All"
            case .today: return "Today"
            case .upcoming: return "Upcoming"
            case .completed: return "Completed"
            }
        }
    }
    
    var filteredTasks: [Task] {
        let filtered = taskManager.tasks.filter { task in
            if searchText.isEmpty {
                return true
            }
            return task.title.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .today:
            return filtered.filter { Calendar.current.isDateInToday($0.dueDate) }
        case .upcoming:
            return filtered.filter { $0.dueDate > Date() && !Calendar.current.isDateInToday($0.dueDate) }
        case .completed:
            return filtered.filter { $0.isCompleted }
        }
    }
    
    var body: some View {
        List {
            Picker("Filter", selection: $selectedFilter) {
                ForEach([TaskFilter.all, .today, .upcoming, .completed], id: \.self) { filter in
                    Text(filter.description).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .listRowBackground(Color.clear)
            .padding(.vertical)
            
            ForEach(filteredTasks) { task in
                TaskRow(task: task)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            taskManager.removeTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            taskManager.toggleTaskCompletion(task)
                        } label: {
                            Label(
                                task.isCompleted ? "Incomplete" : "Complete",
                                systemImage: task.isCompleted ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        .tint(task.isCompleted ? .orange : .green)
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks")
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskView()
        }
    }
}

struct TaskRow: View {
    let task: Task
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    taskManager.toggleTaskCompletion(task)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .gray)
                        .font(.title2)
                }
                
                VStack(alignment: .leading) {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                    
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if task.isOverdue && !task.isCompleted {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Label(task.dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if task.hasReminder {
                    Label("Reminder set", systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date()
    @State private var reminder = false
    @State private var reminderDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Due Date")) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Reminder")) {
                    Toggle("Set Reminder", isOn: $reminder)
                    
                    if reminder {
                        DatePicker("Reminder Time", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    let task = Task(
                        title: title,
                        notes: notes,
                        dueDate: dueDate,
                        reminder: reminder ? reminderDate : nil
                    )
                    taskManager.addTask(task)
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

#Preview {
    TaskListView()
        .environmentObject(TaskManager())
} 