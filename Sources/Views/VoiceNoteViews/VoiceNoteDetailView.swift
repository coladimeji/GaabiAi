import SwiftUI
import AVFoundation

struct VoiceNoteDetailView: View {
    let note: VoiceNote
    @ObservedObject var viewModel: VoiceNoteViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var selectedTab = 0
    
    private let audioPlayer = AVPlayer()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Player Card
                    PlayerCard(
                        isPlaying: $isPlaying,
                        progress: $progress,
                        duration: note.duration,
                        onPlayPause: togglePlayback,
                        onSeek: seek
                    )
                    
                    // Content Tabs
                    Picker("Content", selection: $selectedTab) {
                        Text("Transcript").tag(0)
                        Text("Analysis").tag(1)
                        Text("Links").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Tab Content
                    Group {
                        switch selectedTab {
                        case 0:
                            TranscriptView(transcript: note.transcript)
                        case 1:
                            AnalysisView(analysis: note.aiAnalysis)
                        case 2:
                            LinkedItemsView(items: note.linkedItems)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tags
                    if !note.tags.isEmpty {
                        TagsView(tags: note.tags)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitle(note.title, displayMode: .inline)
            .navigationBarItems(
                trailing: HStack {
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil")
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                    }
                }
            )
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Voice Note"),
                    message: Text("Are you sure you want to delete this voice note?"),
                    primaryButton: .destructive(Text("Delete")) {
                        // Implement delete
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onDisappear {
            audioPlayer.pause()
        }
        .onReceive(timer) { _ in
            if isPlaying {
                progress = CMTimeGetSeconds(audioPlayer.currentTime()) / note.duration
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer.pause()
        } else {
            if progress == 0 {
                let item = AVPlayerItem(url: note.audioURL)
                audioPlayer.replaceCurrentItem(with: item)
            }
            audioPlayer.play()
        }
        isPlaying.toggle()
    }
    
    private func seek(to value: Double) {
        let time = CMTime(seconds: value * note.duration, preferredTimescale: 600)
        audioPlayer.seek(to: time)
    }
}

struct PlayerCard: View {
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    let duration: TimeInterval
    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Waveform Visualization (placeholder)
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 60)
                .overlay(
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: UIScreen.main.bounds.width * CGFloat(progress))
                )
            
            // Progress Slider
            Slider(value: $progress, in: 0...1) { editing in
                if !editing {
                    onSeek(progress)
                }
            }
            
            // Controls
            HStack {
                Text(timeString(from: progress * duration))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(timeString(from: duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TranscriptView: View {
    let transcript: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let transcript = transcript {
                Text(transcript)
                    .font(.body)
            } else {
                Text("No transcript available")
                    .font(.body)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct AnalysisView: View {
    let analysis: AIAnalysis?
    
    var body: some View {
        VStack(spacing: 16) {
            if let analysis = analysis {
                // Summary
                if let summary = analysis.summary {
                    AnalysisCard(title: "Summary", content: summary)
                }
                
                // Action Items
                if !analysis.actionItems.isEmpty {
                    AnalysisCard(title: "Action Items") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(analysis.actionItems, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle")
                            }
                        }
                    }
                }
                
                // Context
                if analysis.weatherContext != nil || analysis.trafficContext != nil {
                    ContextCard(
                        weather: analysis.weatherContext,
                        traffic: analysis.trafficContext
                    )
                }
                
                // Keywords
                if !analysis.keywords.isEmpty {
                    AnalysisCard(title: "Keywords") {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(analysis.keywords), id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            } else {
                Text("No analysis available")
                    .font(.body)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct AnalysisCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, content: Content) {
        self.title = title
        self.content = content
    }
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct ContextCard: View {
    let weather: WeatherContext?
    let traffic: TrafficContext?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context")
                .font(.headline)
            
            if let weather = weather {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("\(Int(weather.temperature))° - \(weather.condition)")
                        if let forecast = weather.forecast {
                            Text(forecast)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            if let traffic = traffic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.red)
                        Text(traffic.currentConditions)
                    }
                    
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
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct LinkedItemsView: View {
    let items: LinkedItems
    
    var body: some View {
        VStack(spacing: 16) {
            if !items.tasks.isEmpty {
                LinkedItemsCard(title: "Tasks", items: items.tasks)
            }
            
            if !items.habits.isEmpty {
                LinkedItemsCard(title: "Habits", items: items.habits)
            }
            
            if !items.smartDevices.isEmpty {
                LinkedItemsCard(title: "Smart Devices", items: items.smartDevices)
            }
            
            if !items.schedules.isEmpty {
                LinkedItemsCard(title: "Schedules", items: items.schedules)
            }
            
            if items.tasks.isEmpty && items.habits.isEmpty &&
               items.smartDevices.isEmpty && items.schedules.isEmpty {
                Text("No linked items")
                    .font(.body)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct LinkedItemsCard: View {
    let title: String
    let items: [UUID]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item.uuidString)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct TagsView: View {
    let tags: Set<String>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.reduce(CGSize.zero) { size, row in
            CGSize(
                width: max(size.width, row.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(row.count - 1) * spacing),
                height: size.height + row.first?.sizeThatFits(.unspecified).height ?? 0
            )
        }
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let rowWidth = row.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(row.count - 1) * spacing
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            
            y += rowHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentRow = 0
        var remainingWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if remainingWidth >= size.width || rows[currentRow].isEmpty {
                rows[currentRow].append(subview)
                remainingWidth -= size.width + spacing
            } else {
                currentRow += 1
                rows.append([subview])
                remainingWidth = (proposal.width ?? .infinity) - size.width - spacing
            }
        }
        
        return rows
    }
} 