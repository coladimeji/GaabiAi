import SwiftUI

struct VoiceNotesView: View {
    @StateObject private var viewModel = VoiceNoteViewModel(
        aiService: AIService(),
        weatherService: WeatherService(),
        trafficService: TrafficService()
    )
    @State private var showingRecorder = false
    @State private var selectedNote: VoiceNote?
    @State private var searchText = ""
    
    var filteredNotes: [VoiceNote] {
        if searchText.isEmpty {
            return viewModel.voiceNotes
        }
        return viewModel.voiceNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.transcript?.localizedCaseInsensitiveContains(searchText) == true ||
            note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding()
                
                // Voice Notes List
                List {
                    ForEach(filteredNotes) { note in
                        VoiceNoteRow(note: note)
                            .onTapGesture {
                                selectedNote = note
                            }
                    }
                }
                
                // Recording Button
                RecordingButton(isRecording: viewModel.isRecording) {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }
                .padding()
            }
            .navigationBarTitle("Voice Notes", displayMode: .large)
            .sheet(item: $selectedNote) { note in
                VoiceNoteDetailView(note: note, viewModel: viewModel)
            }
            .overlay(
                ProcessingOverlay(status: viewModel.transcriptionStatus)
            )
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search voice notes", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct VoiceNoteRow: View {
    let note: VoiceNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title)
                    .font(.headline)
                
                Spacer()
                
                Text(timeString(from: note.duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if let transcript = note.transcript {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            if let analysis = note.aiAnalysis {
                HStack(spacing: 8) {
                    if !analysis.actionItems.isEmpty {
                        Label("\(analysis.actionItems.count)", systemImage: "checklist")
                            .font(.caption)
                    }
                    
                    if analysis.weatherContext != nil {
                        Image(systemName: "cloud.sun.fill")
                            .foregroundColor(.orange)
                    }
                    
                    if analysis.trafficContext != nil {
                        Image(systemName: "car.fill")
                            .foregroundColor(.red)
                    }
                    
                    ForEach(Array(analysis.keywords.prefix(3)), id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            
            HStack {
                Text(dateFormatter.string(from: note.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    ForEach(Array(note.tags.prefix(2)), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct RecordingButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 4)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }
}

struct ProcessingOverlay: View {
    let status: VoiceNoteViewModel.TranscriptionStatus
    
    var body: some View {
        switch status {
        case .transcribing:
            processingView(message: "Transcribing...")
        case .analyzing:
            processingView(message: "Analyzing with AI...")
        case .error(let message):
            processingView(message: "Error: \(message)", isError: true)
        default:
            EmptyView()
        }
    }
    
    private func processingView(message: String, isError: Bool = false) -> some View {
        VStack(spacing: 16) {
            if !isError {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(isError ? .red : .primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.9))
    }
} 