import SwiftUI
import AVKit
import MapKit

struct VoiceNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VoiceNoteDetailViewModel
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLocationPicker = false
    @State private var showingTaskPicker = false
    
    init(note: VoiceNote) {
        _viewModel = StateObject(wrappedValue: VoiceNoteDetailViewModel(note: note))
    }
    
    var body: some View {
        List {
            // Player Section
            Section {
                VStack(spacing: 16) {
                    // Waveform
                    AudioWaveform(samples: viewModel.audioSamples)
                        .frame(height: 60)
                        .padding(.vertical)
                    
                    // Player Controls
                    HStack {
                        Button {
                            viewModel.seekBackward()
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                        } label: {
                            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.seekForward()
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.title2)
                        }
                    }
                    .foregroundColor(.blue)
                    
                    // Progress Bar
                    VStack(spacing: 4) {
                        Slider(value: $viewModel.progress) { isEditing in
                            if isEditing {
                                viewModel.pause()
                            } else {
                                viewModel.seek(to: viewModel.progress)
                            }
                        }
                        
                        HStack {
                            Text(viewModel.currentTime.formattedDuration)
                            Spacer()
                            Text(viewModel.duration.formattedDuration)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding()
            }
            
            // Basic Info Section
            Section {
                if isEditing {
                    TextField("Title", text: $viewModel.title)
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(VoiceNoteCategory.allCases, id: \.self) { category in
                            Text(category.description).tag(category)
                        }
                    }
                } else {
                    LabeledContent("Title", value: viewModel.title)
                    LabeledContent("Category", value: viewModel.category.description)
                    LabeledContent("Duration", value: viewModel.duration.formattedDuration)
                    LabeledContent("Date", value: viewModel.recordingDate.formatted())
                }
            }
            
            // Transcription Section
            if let transcription = viewModel.transcription {
                Section("Transcription") {
                    Text(transcription)
                        .font(.body)
                }
            }
            
            // Location Section
            Section("Location") {
                if isEditing {
                    Toggle("Location Based", isOn: $viewModel.isLocationBased)
                    
                    if viewModel.isLocationBased {
                        Button {
                            showingLocationPicker = true
                        } label: {
                            if let location = viewModel.location {
                                Text(location.name)
                            } else {
                                Text("Select Location")
                            }
                        }
                    }
                } else if let location = viewModel.location {
                    LabeledContent("Location", value: location.name)
                    
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )))
                    .frame(height: 150)
                    .cornerRadius(10)
                }
            }
            
            // Tags Section
            Section("Tags") {
                if isEditing {
                    TagInputField(tags: $viewModel.tags)
                } else if !viewModel.tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Linked Tasks Section
            Section("Linked Tasks") {
                ForEach(viewModel.linkedTasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task)
                    } label: {
                        TaskRow(task: task)
                    }
                }
                
                Button {
                    showingTaskPicker = true
                } label: {
                    Label("Link Task", systemImage: "link")
                }
            }
            
            if !isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Voice Note", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Voice Note" : "Voice Note")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if isEditing {
                        viewModel.saveChanges()
                    }
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.shareAudioFile()
                    } label: {
                        Label("Share Audio", systemImage: "square.and.arrow.up")
                    }
                    
                    if let transcription = viewModel.transcription {
                        Button {
                            viewModel.shareTranscription(transcription)
                        } label: {
                            Label("Share Transcription", systemImage: "doc.text")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: $viewModel.location)
        }
        .sheet(isPresented: $showingTaskPicker) {
            TaskPickerView(selectedTasks: $viewModel.linkedTasks)
        }
        .alert("Delete Voice Note", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteVoiceNote()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this voice note? This action cannot be undone.")
        }
    }
}

struct AudioWaveform: View {
    let samples: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let middle = height / 2
                let sampleWidth = width / CGFloat(samples.count)
                
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * sampleWidth
                    let sampleHeight = CGFloat(sample) * middle
                    
                    path.move(to: CGPoint(x: x, y: middle - sampleHeight))
                    path.addLine(to: CGPoint(x: x, y: middle + sampleHeight))
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}

class VoiceNoteDetailViewModel: ObservableObject {
    @Published var title: String
    @Published var category: VoiceNoteCategory
    @Published var tags: [String]
    @Published var isLocationBased: Bool
    @Published var location: TaskLocation?
    @Published var linkedTasks: [SmartTask]
    @Published var audioSamples: [Float] = []
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    
    private let note: VoiceNote
    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    
    var duration: TimeInterval {
        note.duration
    }
    
    var recordingDate: Date {
        note.recordingDate
    }
    
    var transcription: String? {
        note.transcription
    }
    
    init(note: VoiceNote) {
        self.note = note
        self.title = note.title
        self.category = note.category
        self.tags = note.tags
        self.isLocationBased = note.location != nil
        self.location = note.location
        self.linkedTasks = note.associatedTasks
        
        setupAudioPlayer()
        loadAudioSamples()
    }
    
    private func setupAudioPlayer() {
        do {
            player = try AVAudioPlayer(contentsOf: note.fileURL)
            player?.prepareToPlay()
        } catch {
            print("Audio player setup error: \(error)")
        }
    }
    
    private func loadAudioSamples() {
        // Load audio samples for waveform visualization
        // This would typically involve processing the audio file
        // For now, we'll use dummy data
        audioSamples = (0..<100).map { _ in Float.random(in: 0.1...1.0) }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        startDisplayLink()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopDisplayLink()
    }
    
    func seek(to progress: Double) {
        let time = duration * progress
        player?.currentTime = time
        currentTime = time
        if isPlaying {
            player?.play()
        }
    }
    
    func seekForward() {
        guard let player = player else { return }
        let newTime = min(player.duration, player.currentTime + 15)
        player.currentTime = newTime
        currentTime = newTime
        progress = newTime / duration
    }
    
    func seekBackward() {
        guard let player = player else { return }
        let newTime = max(0, player.currentTime - 15)
        player.currentTime = newTime
        currentTime = newTime
        progress = newTime / duration
    }
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgress))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateProgress() {
        guard let player = player else { return }
        currentTime = player.currentTime
        progress = player.currentTime / duration
        
        if !player.isPlaying {
            pause()
        }
    }
    
    func saveChanges() {
        // Update voice note in database
    }
    
    func deleteVoiceNote() {
        pause()
        // Delete voice note from database and file system
    }
    
    func shareAudioFile() {
        // Share audio file
    }
    
    func shareTranscription(_ transcription: String) {
        // Share transcription text
    }
    
    deinit {
        pause()
    }
} 