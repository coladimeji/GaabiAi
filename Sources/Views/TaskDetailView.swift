import SwiftUI
import CoreLocation
import MapKit

struct TaskDetailView: View {
    let task: SmartTask
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedTask: SmartTask
    @State private var showingLocationPicker = false
    @State private var showingDevicePicker = false
    @State private var showingHabitPicker = false
    @State private var region: MKCoordinateRegion?
    
    init(task: SmartTask, viewModel: DashboardViewModel) {
        self.task = task
        self.viewModel = viewModel
        _editedTask = State(initialValue: task)
        
        if let location = task.location {
            _region = State(initialValue: MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Basic Info Section
                Section {
                    if isEditing {
                        TextField("Title", text: $editedTask.title)
                        TextField("Description", text: $editedTask.description, axis: .vertical)
                        DatePicker("Due Date", selection: $editedTask.dueDate)
                    } else {
                        Text(task.title)
                            .font(.headline)
                        Text(task.description)
                        Text("Due: \(formatDate(task.dueDate))")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status & Priority Section
                Section("Status & Priority") {
                    if isEditing {
                        Picker("Status", selection: $editedTask.status) {
                            ForEach(TaskStatus.allCases, id: \.self) { status in
                                Text(status.rawValue.capitalized).tag(status)
                            }
                        }
                        
                        Picker("Priority", selection: $editedTask.priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                Text(priority.rawValue.capitalized).tag(priority)
                            }
                        }
                    } else {
                        HStack {
                            Label("Status", systemImage: statusIcon)
                                .foregroundColor(statusColor)
                            Spacer()
                            Text(task.status.rawValue.capitalized)
                        }
                        
                        HStack {
                            Label("Priority", systemImage: "exclamationmark.circle")
                            Spacer()
                            Text(task.priority.rawValue.capitalized)
                                .foregroundColor(priorityColor)
                        }
                    }
                }
                
                // Location Section
                if let location = task.location {
                    Section("Location") {
                        if let region = region {
                            Map(coordinateRegion: .constant(region), annotationItems: [location]) { loc in
                                MapMarker(coordinate: loc.coordinate)
                            }
                            .frame(height: 200)
                            .cornerRadius(8)
                        }
                        
                        Text(location.address)
                            .font(.subheadline)
                        
                        if let routeInfo = task.routeInfo {
                            HStack {
                                Label(
                                    "\(Int(routeInfo.estimatedDuration / 60)) min",
                                    systemImage: "car"
                                )
                                Spacer()
                                Text(routeInfo.preferredTransportMode.rawValue.capitalized)
                            }
                        }
                    }
                }
                
                // Weather Section
                if task.weatherDependent {
                    Section("Weather") {
                        if let weather = viewModel.currentWeather {
                            WeatherSummaryView(weather: weather)
                        }
                        
                        if isEditing {
                            Toggle("Weather Dependent", isOn: $editedTask.weatherDependent)
                        }
                    }
                }
                
                // Connected Devices Section
                if !task.linkedDevices.isEmpty {
                    Section("Connected Devices") {
                        ForEach(task.linkedDevices) { device in
                            SmartDeviceRow(device: device)
                        }
                        
                        if isEditing {
                            Button {
                                showingDevicePicker = true
                            } label: {
                                Label("Add Device", systemImage: "plus")
                            }
                        }
                    }
                }
                
                // Linked Habits Section
                if let habitData = task.habitData {
                    Section("Linked Habits") {
                        VStack(alignment: .leading) {
                            Text("Frequency: \(habitData.frequency.description)")
                            Text("Streak: \(habitData.streak) days")
                            Text("Best Streak: \(habitData.bestStreak) days")
                        }
                        
                        if isEditing {
                            Button {
                                showingHabitPicker = true
                            } label: {
                                Label("Link Habit", systemImage: "plus")
                            }
                        }
                    }
                }
                
                // Tags Section
                Section("Tags") {
                    if isEditing {
                        TagEditView(tags: $editedTask.tags)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(task.tags), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            // TODO: Save changes
                            isEditing = false
                        } else {
                            isEditing = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(location: $editedTask.location)
        }
        .sheet(isPresented: $showingDevicePicker) {
            DevicePickerView(selectedDevices: $editedTask.linkedDevices)
        }
        .sheet(isPresented: $showingHabitPicker) {
            HabitPickerView(habitData: $editedTask.habitData)
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
    
    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TagEditView: View {
    @Binding var tags: Set<String>
    @State private var newTag = ""
    
    var body: some View {
        VStack {
            HStack {
                TextField("Add Tag", text: $newTag)
                Button("Add") {
                    if !newTag.isEmpty {
                        tags.insert(newTag)
                        newTag = ""
                    }
                }
            }
            
            FlowLayout(spacing: 8) {
                ForEach(Array(tags), id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Button {
                            tags.remove(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var width: CGFloat = 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        for size in sizes {
            if x + size.width > proposal.width ?? 0 {
                x = 0
                y += size.height + spacing
            }
            
            width = max(width, x + size.width)
            height = max(height, y + size.height)
            x += size.width + spacing
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += size.height + spacing
            }
            
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            
            x += size.width + spacing
        }
    }
} 