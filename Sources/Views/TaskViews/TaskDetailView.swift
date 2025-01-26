import SwiftUI

struct TaskDetailView: View {
    let task: Task
    @ObservedObject var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var editedTask: Task
    @State private var showingDeleteAlert = false
    @State private var showingVoiceNote = false
    
    init(task: Task, viewModel: TaskViewModel) {
        self.task = task
        self.viewModel = viewModel
        _editedTask = State(initialValue: task)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    if isEditing {
                        TextField("Title", text: $editedTask.title)
                        TextField("Description", text: $editedTask.description)
                        DatePicker("Date", selection: $editedTask.date, displayedComponents: [.date])
                    } else {
                        Text(task.title)
                            .font(.headline)
                        Text(task.description)
                            .foregroundColor(.gray)
                        Text(dateFormatter.string(from: task.date))
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Reminders")) {
                    if isEditing {
                        Toggle("Set Reminder", isOn: $editedTask.hasReminder)
                        if editedTask.hasReminder {
                            DatePicker("Time", selection: Binding(
                                get: { editedTask.reminderTime ?? editedTask.date },
                                set: { editedTask.reminderTime = $0 }
                            ), displayedComponents: [.hourAndMinute])
                        }
                    } else if task.hasReminder, let reminderTime = task.reminderTime {
                        Text("Reminder set for \(timeFormatter.string(from: reminderTime))")
                    }
                }
                
                Section(header: Text("Alerts")) {
                    if isEditing {
                        Toggle("Weather Alert", isOn: $editedTask.weatherAlert)
                        Toggle("Traffic Alert", isOn: $editedTask.trafficAlert)
                        if editedTask.trafficAlert {
                            Toggle("Alternative Routes", isOn: $editedTask.alternativeRoutes)
                        }
                    } else {
                        if task.weatherAlert {
                            WeatherAlertView(task: task)
                        }
                        if task.trafficAlert {
                            TrafficAlertView(task: task, showAlternatives: task.alternativeRoutes)
                        }
                    }
                }
                
                if let voiceNote = task.voiceNote {
                    Section(header: Text("Voice Note")) {
                        VoiceNotePlayerView(voiceNote: voiceNote)
                    }
                }
                
                if !isEditing {
                    Section {
                        Button(action: { showingDeleteAlert = true }) {
                            Text("Delete Task")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationBarTitle(isEditing ? "Edit Task" : "Task Details", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Done") {
                    if isEditing {
                        viewModel.updateTask(editedTask)
                    }
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        viewModel.updateTask(editedTask)
                    }
                    isEditing.toggle()
                }
            )
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Task"),
                    message: Text("Are you sure you want to delete this task?"),
                    primaryButton: .destructive(Text("Delete")) {
                        viewModel.deleteTask(task)
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct WeatherAlertView: View {
    let task: Task
    @State private var weather: WeatherContext?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let weather = weather {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundColor(.orange)
                    Text("\(Int(weather.temperature))°")
                    Text(weather.condition)
                }
                if let forecast = weather.forecast {
                    Text(forecast)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text("Loading weather...")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct TrafficAlertView: View {
    let task: Task
    let showAlternatives: Bool
    @State private var traffic: TrafficContext?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let traffic = traffic {
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundColor(trafficColor(for: traffic))
                    Text(traffic.currentConditions)
                }
                
                if showAlternatives {
                    ForEach(traffic.alternativeRoutes, id: \.name) { route in
                        HStack {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(route.name)
                                Text("\(Int(route.duration / 60)) min • \(String(format: "%.1f", route.distance)) km")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.leading)
                    }
                }
            } else {
                Text("Loading traffic...")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func trafficColor(for traffic: TrafficContext) -> Color {
        if traffic.alternativeRoutes.contains(where: { $0.trafficLevel == .severe }) {
            return .red
        } else if traffic.alternativeRoutes.contains(where: { $0.trafficLevel == .heavy }) {
            return .orange
        }
        return .green
    }
}

struct VoiceNotePlayerView: View {
    let voiceNote: VoiceNote
    @State private var isPlaying = false
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading) {
                    Text(voiceNote.title)
                        .font(.headline)
                    Text(timeString(from: voiceNote.duration))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if let transcript = voiceNote.transcript {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let analysis = voiceNote.aiAnalysis {
                if !analysis.actionItems.isEmpty {
                    Text("Action Items:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(analysis.actionItems, id: \.self) { item in
                        Text("• \(item)")
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        // Implement audio playback
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 