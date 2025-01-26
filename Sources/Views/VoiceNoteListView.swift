import SwiftUI
import AVFoundation

struct VoiceNoteListView: View {
    @StateObject private var viewModel = VoiceNoteListViewModel()
    @State private var searchText = ""
    @State private var selectedSortOption: VoiceNoteSortOption = .date
    @State private var selectedCategory: VoiceNoteCategory?
    @State private var showingRecorder = false
    
    var body: some View {
        NavigationView {
            List {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            count: viewModel.voiceNotes.count
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(VoiceNoteCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.description,
                                isSelected: selectedCategory == category,
                                count: viewModel.voiceNotes.filter { $0.category == category }.count
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Voice Notes
                ForEach(filteredNotes) { note in
                    NavigationLink {
                        VoiceNoteDetailView(note: note)
                    } label: {
                        VoiceNoteRow(note: note)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search voice notes")
            .navigationTitle("Voice Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $selectedSortOption) {
                            ForEach(VoiceNoteSortOption.allCases, id: \.self) { option in
                                Text(option.description).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingRecorder = true
                    } label: {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingRecorder) {
                VoiceRecorderView { note in
                    viewModel.addVoiceNote(note)
                }
            }
        }
    }
    
    private var filteredNotes: [VoiceNote] {
        let notes = viewModel.voiceNotes
        
        let categoryFiltered = selectedCategory == nil ? notes : notes.filter { $0.category == selectedCategory }
        
        let searchFiltered = searchText.isEmpty ? categoryFiltered : categoryFiltered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        return searchFiltered.sorted { first, second in
            switch selectedSortOption {
            case .date:
                return first.recordingDate > second.recordingDate
            case .duration:
                return first.duration > second.duration
            case .title:
                return first.title < second.title
            }
        }
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
        }
    }
}

struct VoiceNoteRow: View {
    let note: VoiceNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title)
                    .font(.headline)
                
                Spacer()
                
                Text(note.duration.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let transcription = note.transcription {
                Text(transcription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label(note.recordingDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                
                if let location = note.location {
                    Label(location.name, systemImage: "location")
                }
                
                ForEach(note.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VoiceRecorderViewModel()
    let onRecordingComplete: (VoiceNote) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Waveform Visualization
                ZStack {
                    ForEach(0..<viewModel.audioLevels.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: 4, height: viewModel.audioLevels[index] * 100)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevels[index])
                    }
                }
                .frame(height: 100)
                .padding()
                
                // Timer
                Text(viewModel.recordingDuration.formattedDuration)
                    .font(.system(size: 64, weight: .thin))
                    .monospacedDigit()
                
                // Record Button
                Button {
                    viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 80, height: 80)
                        
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                
                if viewModel.isRecordingComplete {
                    VStack(spacing: 16) {
                        TextField("Title", text: $viewModel.title)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("Category", selection: $viewModel.category) {
                            ForEach(VoiceNoteCategory.allCases, id: \.self) { category in
                                Text(category.description).tag(category)
                            }
                        }
                        
                        TagInputField(tags: $viewModel.tags)
                        
                        Button {
                            Task {
                                if let note = await viewModel.createVoiceNote() {
                                    onRecordingComplete(note)
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Save Recording")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.title.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TagInputField: View {
    @Binding var tags: [String]
    @State private var tagInput = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Add tags (press return)", text: $tagInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    addTag()
                }
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagView(tag: tag) {
                        tags.removeAll { $0 == tag }
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
        }
        tagInput = ""
    }
}

struct TagView: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.reduce(CGSize.zero) { size, row in
            CGSize(
                width: max(size.width, row.width),
                height: size.height + row.height + (size.height > 0 ? spacing : 0)
            )
        }
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > (proposal.width ?? .infinity) {
                rows.append(currentRow)
                currentRow = Row()
                x = size.width + spacing
                currentRow.add(subview)
            } else {
                x += size.width + spacing
                currentRow.add(subview)
            }
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct Row {
        var subviews: [LayoutSubview] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        mutating func add(_ subview: LayoutSubview) {
            let size = subview.sizeThatFits(.unspecified)
            subviews.append(subview)
            width += size.width
            height = max(height, size.height)
        }
    }
}

enum VoiceNoteSortOption: String, CaseIterable {
    case date
    case duration
    case title
    
    var description: String {
        switch self {
        case .date: return "Date"
        case .duration: return "Duration"
        case .title: return "Title"
        }
    }
}

class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isRecordingComplete = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.2, count: 30)
    @Published var title = ""
    @Published var category: VoiceNoteCategory = .general
    @Published var tags: [String] = []
    
    private let recordingManager = VoiceRecordingManager()
    private var recordingURL: URL?
    private var timer: Timer?
    
    func startRecording() {
        Task {
            do {
                recordingURL = try await recordingManager.startRecording()
                await MainActor.run {
                    isRecording = true
                    startTimer()
                }
            } catch {
                print("Recording error: \(error)")
            }
        }
    }
    
    func stopRecording() {
        Task {
            do {
                try await recordingManager.stopRecording()
                await MainActor.run {
                    isRecording = false
                    isRecordingComplete = true
                    stopTimer()
                }
            } catch {
                print("Stop recording error: \(error)")
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.1
            self.updateAudioLevels()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateAudioLevels() {
        // Simulate audio levels for visualization
        audioLevels.removeFirst()
        audioLevels.append(CGFloat.random(in: 0.1...1.0))
    }
    
    func createVoiceNote() async -> VoiceNote? {
        guard let url = recordingURL else { return nil }
        
        let note = VoiceNote(
            id: UUID(),
            title: title,
            recordingDate: Date(),
            duration: recordingDuration,
            transcription: nil,
            tags: tags,
            category: category,
            location: nil,
            fileURL: url,
            isProcessed: false,
            associatedTasks: []
        )
        
        // Start transcription in background
        Task {
            if let transcription = try? await recordingManager.transcribeAudio(for: note) {
                print("Transcription complete: \(transcription)")
            }
        }
        
        return note
    }
}

class VoiceNoteListViewModel: ObservableObject {
    @Published private(set) var voiceNotes: [VoiceNote] = []
    
    func addVoiceNote(_ note: VoiceNote) {
        voiceNotes.append(note)
    }
    
    func deleteVoiceNote(_ note: VoiceNote) {
        voiceNotes.removeAll { $0.id == note.id }
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 