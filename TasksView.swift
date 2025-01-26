import SwiftUI

struct TasksView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDueDate = Date()
    @State private var newTaskPriority = 0
    
    var body: some View {
        NavigationView {
            List {
                ForEach(taskManager.tasks) { task in
                    TaskRow(task: task)
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(isPresented: $showingAddTask)
            }
        }
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        // Implement delete functionality
    }
}

struct TaskRow: View {
    let task: Task
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.headline)
                Text(task.dueDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddTaskView: View {
    @EnvironmentObject var taskManager: TaskManager
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var priority = 0
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Task")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Add") {
                    addTask()
                }
                .disabled(title.isEmpty)
            )
        }
    }
    
    private func addTask() {
        let task = Task(
            id: UUID(),
            title: title,
            dueDate: dueDate,
            priority: priority,
            isCompleted: false,
            notes: notes.isEmpty ? nil : notes
        )
        taskManager.addTask(task)
        isPresented = false
    }
} 