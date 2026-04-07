// VoiceInputManager.swift
// Ember — Voice Input via SpeechKit

import Foundation
import Speech
import AVFoundation
import Combine

final class VoiceInputManager: ObservableObject {

    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String = ""

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                guard authStatus == .authorized else {
                    completion(false)
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            }
        }
    }

    func startListening() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available."
            return
        }

        stopListening()
        transcribedText = ""

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false

            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                if let result = result {
                    DispatchQueue.main.async {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                }
                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async {
                        self.stopListening()
                    }
                }
            }

            let inputNode = audioEngine.inputNode
            let nativeFormat = inputNode.inputFormat(forBus: 0)
            let recordingFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: nativeFormat.sampleRate,
                channels: 1,
                interleaved: false
            )!

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.isListening = true
                self.errorMessage = ""
            }

        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Could not start recording."
                self.isListening = false
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isListening = false
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggle() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
}
