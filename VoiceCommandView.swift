import SwiftUI
import Speech

struct VoiceCommandView: View {
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var aiManager: AIManager
    @State private var isProcessing = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Transcription Display
                ScrollView {
                    Text(voiceManager.transcribedText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding()
                
                // Recording Button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(voiceManager.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: voiceManager.isRecording ? "stop.fill" : "mic.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                }
                .padding()
                
                // Process Button
                if !voiceManager.transcribedText.isEmpty {
                    Button(action: processVoiceCommand) {
                        HStack {
                            Text("Process Command")
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                }
            }
            .navigationTitle("Voice Commands")
            .alert(isPresented: $showingPermissionAlert) {
                Alert(
                    title: Text("Permission Required"),
                    message: Text("Please enable microphone access in Settings to use voice commands."),
                    primaryButton: .default(Text("Settings"), action: openSettings),
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func toggleRecording() {
        if voiceManager.isRecording {
            voiceManager.stopRecording()
        } else {
            checkMicrophonePermission()
        }
    }
    
    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            voiceManager.startRecording()
        case .denied:
            showingPermissionAlert = true
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    DispatchQueue.main.async {
                        voiceManager.startRecording()
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func processVoiceCommand() {
        isProcessing = true
        Task {
            let result = await aiManager.processTask(voiceManager.transcribedText)
            // Handle the AI processing result
            isProcessing = false
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// Preview Provider
struct VoiceCommandView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCommandView()
            .environmentObject(VoiceManager())
            .environmentObject(AIManager())
    }
} 