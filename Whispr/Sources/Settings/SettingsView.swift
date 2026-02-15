import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            APISettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("API Keys", systemImage: "key.fill")
                }

            FormattingSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Formatting", systemImage: "text.quote")
                }

            ExamplesSettingsView()
                .tabItem {
                    Label("Examples", systemImage: "list.bullet.rectangle")
                }
        }
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                Toggle("Auto-paste after transcription", isOn: $appState.autoPasteEnabled)
                    .help("Automatically pastes formatted text into the focused input field")
            } header: {
                Text("Behavior")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to use:")
                        .font(.headline)
                    Text("1. Press **⌥Space** (Option+Space) to start recording")
                    Text("2. Speak into your microphone")
                    Text("3. Press **⌥Space** again to stop and process")
                    Text("4. Formatted text is copied to clipboard and pasted")

                    Divider()

                    Text("Required Permissions:")
                        .font(.headline)
                    Text("• **Accessibility** — for fn key detection and auto-paste")
                    Text("• **Microphone** — for audio recording")
                    Text("")
                    Text("Go to **System Settings → Privacy & Security** to grant these.")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Instructions")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - API Settings

struct APISettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                SecureField("OpenAI API Key", text: $appState.openAIAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .help("Required for Whisper transcription and optional GPT formatting")

                Text("Used for transcription (Whisper) and formatting (GPT-4o-mini)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("OpenAI")
            }

            Section {
                SecureField("Anthropic API Key", text: $appState.anthropicAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .help("Optional — for Claude-based formatting")

                Text("Optional. Used for formatting if selected below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Anthropic (Optional)")
            }

            Section {
                Picker("Formatting Provider", selection: $appState.formattingProvider) {
                    Text("OpenAI (GPT-4o-mini)").tag("openai")
                    Text("Anthropic (Claude)").tag("anthropic")
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Formatting Engine")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Formatting Settings

struct FormattingSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                TextEditor(text: $appState.formattingSystemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            } header: {
                HStack {
                    Text("System Prompt")
                    Spacer()
                    Button("Reset to Default") {
                        appState.formattingSystemPrompt = AppState.defaultSystemPrompt
                    }
                    .buttonStyle(.link)
                }
            }

            Section {
                Text("The system prompt tells the AI how to format your transcribed speech. Customize it to match your style.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Tips")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Examples Settings

struct ExamplesSettingsView: View {
    @State private var examples: [FormattingExample] = []
    @State private var newInput = ""
    @State private var newOutput = ""

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Add Correction Example") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input (raw transcription):")
                        .font(.caption)
                    TextField("e.g., um so like I was thinking we should uh meet tomorrow", text: $newInput)
                        .textFieldStyle(.roundedBorder)

                    Text("Output (desired formatting):")
                        .font(.caption)
                    TextField("e.g., I was thinking we should meet tomorrow.", text: $newOutput)
                        .textFieldStyle(.roundedBorder)

                    Button("Add Example") {
                        guard !newInput.isEmpty && !newOutput.isEmpty else { return }
                        ExamplesStore.shared.addExample(input: newInput, output: newOutput)
                        examples = ExamplesStore.shared.loadExamples()
                        newInput = ""
                        newOutput = ""
                    }
                    .disabled(newInput.isEmpty || newOutput.isEmpty)
                }
                .padding(8)
            }

            GroupBox("Saved Examples (\(examples.count))") {
                if examples.isEmpty {
                    Text("No examples yet. Add corrections to teach the formatter your preferences.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(examples) { example in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("In:").bold().frame(width: 30, alignment: .leading)
                                        Text(example.input).lineLimit(2)
                                    }
                                    HStack {
                                        Text("Out:").bold().frame(width: 30, alignment: .leading)
                                        Text(example.output).lineLimit(2)
                                    }
                                    HStack {
                                        Spacer()
                                        Button("Remove") {
                                            ExamplesStore.shared.removeExample(id: example.id)
                                            examples = ExamplesStore.shared.loadExamples()
                                        }
                                        .buttonStyle(.link)
                                        .foregroundColor(.red)
                                    }
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                        .padding(4)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            examples = ExamplesStore.shared.loadExamples()
        }
    }
}
