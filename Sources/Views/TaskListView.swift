import SwiftUI
import CoreLocation

struct TaskListView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedCategory: TaskCategory?
    @State private var sortOption: TaskSortOption = .dueDate
    @State private var showingNewTaskSheet = false
    @State private var searchText = ""
    
    var body: some View {
        List {
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    CategoryButton(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )
                    
                    ForEach(TaskCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            title: category.rawValue.capitalized,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // Tasks
            ForEach(filteredTasks) { task in
                TaskDetailRow(task: task, viewModel: viewModel)
            }
        }
        .navigationTitle("Tasks")
        .searchable(text: $searchText, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.description).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewTaskSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            NewTaskView(viewModel: viewModel)
        }
    }
    
    private var filteredTasks: [SmartTask] {
        var tasks = viewModel.todayTasks
        
        // Apply category filter
        if let category = selectedCategory {
            tasks = tasks.filter { $0.category == category }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            tasks = tasks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply sorting
        return tasks.sorted(by: sortOption.sortPredicate)
    }
}

struct TaskDetailRow: View {
    let task: SmartTask
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                    
                    VStack(alignment: .leading) {
                        Text(task.title)
                            .font(.headline)
                            .strikethrough(task.status == .completed)
                        
                        Text(task.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    priorityBadge
                }
                
                if !task.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(task.tags), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    if let location = task.location {
                        Label(location.address, systemImage: "location")
                            .font(.caption)
                    }
                    
                    if task.weatherDependent {
                        Label("Weather Dependent", systemImage: "cloud")
                            .font(.caption)
                    }
                    
                    if !task.linkedDevices.isEmpty {
                        Label("\(task.linkedDevices.count) Devices", systemImage: "lightbulb")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task, viewModel: viewModel)
        }
    }
    
    private var statusIcon: String {
        switch task.status {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "clock.fill"
        case .delayed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "circle"
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case .completed: return .green
        case .inProgress: return .blue
        case .delayed: return .orange
        case .cancelled: return .red
        default: return .gray
        }
    }
    
    private var priorityBadge: some View {
        Text(task.priority.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(8)
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

enum TaskSortOption: Int, CaseIterable, Identifiable {
    case dueDate
    case priority
    case title
    case status
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .dueDate: return "Due Date"
        case .priority: return "Priority"
        case .title: return "Title"
        case .status: return "Status"
        }
    }
    
    var sortPredicate: (SmartTask, SmartTask) -> Bool {
        switch self {
        case .dueDate:
            return { $0.dueDate < $1.dueDate }
        case .priority:
            return { $0.priority.score > $1.priority.score }
        case .title:
            return { $0.title < $1.title }
        case .status:
            return { $0.status.rawValue < $1.status.rawValue }
        }
    }
}

struct NewTaskView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority = TaskPriority.medium
    @State private var category = TaskCategory.general
    @State private var isWeatherDependent = false
    @State private var tags: Set<String> = []
    @State private var newTag = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Details") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized).tag(priority)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    
                    Toggle("Weather Dependent", isOn: $isWeatherDependent)
                }
                
                Section("Tags") {
                    HStack {
                        TextField("Add Tag", text: $newTag)
                        Button("Add") {
                            if !newTag.isEmpty {
                                tags.insert(newTag)
                                newTag = ""
                            }
                        }
                    }
                    
                    ForEach(Array(tags), id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button {
                                tags.remove(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTask()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createTask() {
        let task = SmartTask(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority,
            category: category,
            weatherDependent: isWeatherDependent,
            tags: tags
        )
        
        // TODO: Add task to viewModel
    }
} 