import SwiftUI

struct SettingsView: View {
    @AppStorage("idle_aspect_mode") private var aspectMode = "fill"
    @AppStorage("idle_auto_clear_queue") private var autoClearQueue = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.idleSurface.ignoresSafeArea()

                Form {
                    Section("Video") {
                        Picker("Aspect Ratio", selection: $aspectMode) {
                            Text("Fill (crop to fit)").tag("fill")
                            Text("Fit (letterbox)").tag("fit")
                        }
                    }

                    Section("Queue") {
                        Toggle("Auto-clear played items", isOn: $autoClearQueue)
                            .tint(.idleAmber)
                    }

                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.gray)
                        }

                        HStack {
                            Text("CarPlay Status")
                            Spacer()
                            Text(CarPlaySceneDelegate.isConnected ? "Connected" : "Not connected")
                                .foregroundColor(CarPlaySceneDelegate.isConnected ? .idleAmber : .gray)
                        }

                        HStack {
                            Text("Vehicle Status")
                            Spacer()
                            Text(IdleDetector.shared.isIdle ? "Idle" : "In motion")
                                .foregroundColor(IdleDetector.shared.isIdle ? .idleAmber : .orange)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }
}
