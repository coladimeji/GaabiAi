import SwiftUI

struct NewTaskView: View {
    @ObservedObject var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let selectedDate: Date
    
    @State private var title = ""
    @State private var description = ""
    @State private var date: Date
    @State private var hasReminder = false
    @State private var reminderTime: Date
    @State private var weatherAlert = false
    @State private var trafficAlert = false
    @State private var alternativeRoutes = false
    @State private var recurrence: TaskRecurrence = .none
    @State private var showingVoiceNote = false
    @State private var voiceNote: VoiceNote?
    
    init(viewModel: TaskViewModel, selectedDate: Date) {
        self.viewModel = viewModel
        self.selectedDate = selectedDate
        _date = State(initialValue: selectedDate)
        _reminderTime = State(initialValue: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }
                
                Section(header: Text("Reminders")) {
                    Toggle("Set Reminder", isOn: $hasReminder)
                    
                    if hasReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                    }
                }
                
                Section(header: Text("Alerts")) {
                    Toggle("Weather Alert", isOn: $weatherAlert)
                    Toggle("Traffic Alert", isOn: $trafficAlert)
                    
                    if trafficAlert {
                        Toggle("Alternative Routes", isOn: $alternativeRoutes)
                    }
                }
                
                Section(header: Text("Recurrence")) {
                    Picker("Repeat", selection: $recurrence) {
                        Text("Never").tag(TaskRecurrence.none)
                        Text("Daily").tag(TaskRecurrence.daily)
                        Text("Weekly").tag(TaskRecurrence.weekly)
                        Text("Monthly").tag(TaskRecurrence.monthly)
                        Text("Yearly").tag(TaskRecurrence.yearly)
                    }
                }
                
                Section(header: Text("Voice Note")) {
                    Button(action: { showingVoiceNote = true }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text(voiceNote == nil ? "Add Voice Note" : "Edit Voice Note")
                        }
                    }
                    
                    if let voiceNote = voiceNote {
                        VStack(alignment: .leading) {
                            Text("Voice Note Added")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(voiceNote.title)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationBarTitle("New Task", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    addTask()
                }
                .disabled(title.isEmpty)
            )
            .sheet(isPresented: $showingVoiceNote) {
                VoiceNoteRecorderView(voiceNote: $voiceNote)
            }
        }
    }
    
    private func addTask() {
        let task = Task(
            title: title,
            description: description,
            date: date,
            hasReminder: hasReminder,
            reminderTime: hasReminder ? reminderTime : nil,
            weatherAlert: weatherAlert,
            trafficAlert: trafficAlert,
            alternativeRoutes: alternativeRoutes,
            voiceNote: voiceNote,
            recurrence: recurrence
        )
        
        viewModel.addTask(task)
        presentationMode.wrappedValue.dismiss()
    }
}

struct VoiceNoteRecorderView: View {
    @Binding var voiceNote: VoiceNote?
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var voiceViewModel = VoiceNoteViewModel(
        aiService: AIService(),
        weatherService: WeatherService(),
        trafficService: TrafficService()
    )
    
    var body: some View {
        NavigationView {
            VStack {
                if voiceViewModel.isRecording {
                    Text(timeString(from: voiceViewModel.recordingTime))
                        .font(.system(size: 54, weight: .thin))
                        .padding()
                    
                    Button(action: voiceViewModel.stopRecording) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                    }
                } else {
                    Button(action: voiceViewModel.startRecording) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                    }
                }
                
                if case .transcribing = voiceViewModel.transcriptionStatus {
                    ProgressView("Transcribing...")
                } else if case .analyzing = voiceViewModel.transcriptionStatus {
                    ProgressView("Analyzing...")
                }
            }
            .navigationBarTitle("Record Voice Note", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    if let lastNote = voiceViewModel.voiceNotes.last {
                        voiceNote = lastNote
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 