import SwiftUI
import AVFoundation

struct VoiceNoteListView: View {
    @EnvironmentObject var voiceManager: VoiceManager
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingRecordingId: UUID?
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if voiceManager.permissionGranted {
                    if voiceManager.recordings.isEmpty {
                        emptyStateView
                    } else {
                        recordingsList
                    }
                    
                    recordButton
                } else {
                    permissionView
                }
            }
            .navigationTitle("Voice Notes")
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Microphone access is required to record voice notes.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Voice Notes")
                .font(.title2)
            Text("Tap the record button to create your first voice note")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var recordingsList: some View {
        List {
            ForEach(voiceManager.recordings.sorted(by: { $0.createdAt > $1.createdAt })) { recording in
                RecordingRow(recording: recording,
                           isPlaying: playingRecordingId == recording.id,
                           onPlay: { playRecording(recording) },
                           onStop: stopPlayback)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            voiceManager.deleteRecording(recording)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
    
    private var recordButton: some View {
        Button(action: {
            if voiceManager.isRecording {
                voiceManager.stopRecording()
            } else {
                voiceManager.startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(voiceManager.isRecording ? Color.red : Color.blue)
                    .frame(width: 70, height: 70)
                
                Image(systemName: voiceManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .padding(.bottom)
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Microphone Access Required")
                .font(.title2)
            
            Text("Please grant access to your microphone to record voice notes.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Grant Access") {
                showingPermissionAlert = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func playRecording(_ recording: Recording) {
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            playingRecordingId = recording.id
        } catch {
            print("Failed to play recording: \(error)")
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingRecordingId = nil
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
                Button(action: isPlaying ? onStop : onPlay) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(isPlaying ? .red : .blue)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading) {
                    Text(recording.createdAt, style: .date)
                        .font(.subheadline)
                    Text(recording.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if recording.transcription == nil {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AVAudioPlayerDelegate
extension VoiceNoteListView: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
}

#Preview {
    VoiceNoteListView()
        .environmentObject(VoiceManager())
} 