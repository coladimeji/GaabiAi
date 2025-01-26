import SwiftUI
import AVFoundation

struct VoiceNoteListView: View {
    @EnvironmentObject var voiceManager: VoiceManager
    @State private var currentlyPlayingId: UUID?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Group {
            if voiceManager.permissionGranted {
                if voiceManager.recordings.isEmpty {
                    emptyStateView
                } else {
                    recordingsList
                }
            } else {
                permissionView
            }
        }
        .navigationTitle("Voice Notes")
        .toolbar {
            if voiceManager.permissionGranted {
                ToolbarItem(placement: .navigationBarTrailing) {
                    recordButton
                }
            }
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record voice notes.")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Voice Notes")
                .font(.title2)
            
            Text("Tap the record button to create your first voice note")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var recordingsList: some View {
        List {
            ForEach(voiceManager.recordings.sorted(by: { $0.createdAt > $1.createdAt })) { recording in
                RecordingRow(
                    recording: recording,
                    isPlaying: currentlyPlayingId == recording.id,
                    onPlay: { playRecording(recording) },
                    onStop: stopPlayback
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        voiceManager.deleteRecording(recording)
                        if currentlyPlayingId == recording.id {
                            stopPlayback()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var recordButton: some View {
        Button {
            if voiceManager.isRecording {
                voiceManager.stopRecording()
            } else {
                voiceManager.startRecording()
            }
        } label: {
            Image(systemName: voiceManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title2)
                .foregroundColor(voiceManager.isRecording ? .red : .blue)
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Microphone Access Required")
                .font(.title2)
            
            Text("Please enable microphone access to record voice notes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingPermissionAlert = true
            } label: {
                Text("Enable Microphone Access")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func playRecording(_ recording: Recording) {
        guard let url = recording.fileURL else { return }
        
        do {
            stopPlayback()
            
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = voiceManager
            audioPlayer = player
            currentlyPlayingId = recording.id
            player.play()
        } catch {
            print("Failed to play recording: \(error.localizedDescription)")
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlayingId = nil
    }
}

struct RecordingRow: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    
                    if let transcription = recording.transcription {
                        Text(transcription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    if isPlaying {
                        onStop()
                    } else {
                        onPlay()
                    }
                } label: {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(isPlaying ? .red : .blue)
                }
            }
            
            HStack {
                Label(recording.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if recording.transcription == nil {
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VoiceNoteListView()
        .environmentObject(VoiceManager())
} 