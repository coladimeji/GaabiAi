import SwiftUI

struct TaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TaskPickerViewModel()
    @Binding var selectedTasks: [SmartTask]
    @State private var searchText = ""
    @State private var selectedCategory: TaskCategory?
    @State private var selectedSortOption: TaskSortOption = .dueDate
    
    var body: some View {
        NavigationView {
            List {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            count: viewModel.tasks.count
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.description,
                                isSelected: selectedCategory == category,
                                count: viewModel.tasks.filter { $0.category == category }.count
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Selected Tasks Section
                if !selectedTasks.isEmpty {
                    Section("Selected Tasks") {
                        ForEach(selectedTasks) { task in
                            TaskRow(
                                task: task,
                                isSelected: true,
                                onSelect: {
                                    selectedTasks.removeAll { $0.id == task.id }
                                }
                            )
                        }
                    }
                }
                
                // Available Tasks Section
                Section("Available Tasks") {
                    ForEach(filteredTasks) { task in
                        if !selectedTasks.contains(where: { $0.id == task.id }) {
                            TaskRow(
                                task: task,
                                isSelected: false,
                                onSelect: {
                                    selectedTasks.append(task)
                                }
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tasks")
            .navigationTitle("Select Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $selectedSortOption) {
                            ForEach(TaskSortOption.allCases, id: \.self) { option in
                                Text(option.description).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredTasks: [SmartTask] {
        let tasks = viewModel.tasks
        
        let categoryFiltered = selectedCategory == nil ? tasks : tasks.filter { $0.category == selectedCategory }
        
        let searchFiltered = searchText.isEmpty ? categoryFiltered : categoryFiltered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        
        return searchFiltered.sorted { first, second in
            switch selectedSortOption {
            case .dueDate:
                return (first.dueDate ?? .distantFuture) < (second.dueDate ?? .distantFuture)
            case .priority:
                return first.priority.rawValue > second.priority.rawValue
            case .title:
                return first.title < second.title
            case .status:
                return first.status.rawValue < second.status.rawValue
            }
        }
    }
}

struct TaskRow: View {
    let task: SmartTask
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        if let dueDate = task.dueDate {
                            Label(dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        }
                        
                        if let location = task.location {
                            Label(location.name, systemImage: "location")
                        }
                        
                        ForEach(task.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }
    
    private var statusIcon: String {
        switch task.status {
        case .notStarted: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

class TaskPickerViewModel: ObservableObject {
    @Published private(set) var tasks: [SmartTask] = []
    
    init() {
        loadTasks()
    }
    
    private func loadTasks() {
        // Load tasks from database
        // For now, we'll use dummy data
        tasks = [
            SmartTask(
                id: UUID(),
                title: "Example Task 1",
                description: "This is an example task",
                dueDate: Date().addingTimeInterval(86400),
                priority: .high,
                status: .inProgress,
                category: .work,
                location: nil,
                weatherDependent: false,
                routeInfo: nil,
                linkedDevices: [],
                habitData: nil,
                completionTime: nil,
                tags: ["example", "task"]
            ),
            SmartTask(
                id: UUID(),
                title: "Example Task 2",
                description: "Another example task",
                dueDate: Date().addingTimeInterval(172800),
                priority: .medium,
                status: .notStarted,
                category: .personal,
                location: nil,
                weatherDependent: false,
                routeInfo: nil,
                linkedDevices: [],
                habitData: nil,
                completionTime: nil,
                tags: ["example"]
            )
        ]
    }
} 