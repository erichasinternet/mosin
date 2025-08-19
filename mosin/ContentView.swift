//
//  ContentView.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var accessibilityService = AccessibilityService()
    @StateObject private var grammarService = GrammarService()
    @StateObject private var mlxWrapper = MLXWrapper()
    
    @State private var isMonitoring = false
    @State private var showingPermissionAlert = false

    var body: some View {
        VStack(spacing: 20) {
            HeaderView(
                isMonitoring: $isMonitoring,
                accessibilityEnabled: accessibilityService.isEnabled,
                onToggleMonitoring: toggleMonitoring,
                onRequestPermissions: requestPermissions
            )
            
            if mlxWrapper.isModelLoaded {
                SuggestionsView(suggestions: grammarService.suggestions)
            } else {
                ModelLoadingView(progress: mlxWrapper.modelLoadingProgress)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .alert("Accessibility Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open System Preferences") {
                openAccessibilityPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Mosin needs accessibility permissions to monitor text across all applications. Please enable it in System Preferences > Privacy & Security > Accessibility.")
        }
    }
    
    private func toggleMonitoring() {
        if accessibilityService.isEnabled {
            if isMonitoring {
                accessibilityService.stopMonitoring()
            } else {
                accessibilityService.startMonitoring()
            }
            isMonitoring.toggle()
        } else {
            showingPermissionAlert = true
        }
    }
    
    private func requestPermissions() {
        if !accessibilityService.checkAccessibilityPermissions() {
            showingPermissionAlert = true
        }
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

struct HeaderView: View {
    @Binding var isMonitoring: Bool
    let accessibilityEnabled: Bool
    let onToggleMonitoring: () -> Void
    let onRequestPermissions: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "text.cursor")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Mosin Grammar Checker")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("AI-powered spelling and grammar correction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(accessibilityEnabled ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text("Accessibility: \(accessibilityEnabled ? "Enabled" : "Disabled")")
                            .font(.caption)
                    }
                    
                    HStack {
                        Circle()
                            .fill(isMonitoring ? .green : .gray)
                            .frame(width: 8, height: 8)
                        
                        Text("Monitoring: \(isMonitoring ? "Active" : "Inactive")")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                if accessibilityEnabled {
                    Button(isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                        onToggleMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Enable Accessibility") {
                        onRequestPermissions()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ModelLoadingView: View {
    let progress: Float
    
    var body: some View {
        VStack(spacing: 15) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("Loading MLX Grammar Model...")
                .font(.headline)
            
            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SuggestionsView: View {
    let suggestions: [GrammarSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Grammar Suggestions")
                    .font(.headline)
                
                Spacer()
                
                Text("\(suggestions.count) issues found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if suggestions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("No issues found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start typing in any application to see suggestions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                            SuggestionRow(suggestion: suggestion)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SuggestionRow: View {
    let suggestion: GrammarSuggestion
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    suggestionTypeIcon
                    
                    Text(suggestion.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(suggestion.originalText)
                        .strikethrough()
                        .foregroundColor(.red)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.suggestedText)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .font(.system(.body, design: .monospaced))
            }
            
            Spacer()
            
            Button("Apply") {
                // TODO: Implement suggestion application
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
    
    private var suggestionTypeIcon: some View {
        let (icon, color) = suggestion.type.iconAndColor
        return Image(systemName: icon)
            .foregroundColor(color)
            .font(.caption)
    }
}

extension SuggestionType {
    var displayName: String {
        switch self {
        case .spelling: return "Spelling"
        case .grammar: return "Grammar"
        case .style: return "Style"
        case .clarity: return "Clarity"
        }
    }
    
    var iconAndColor: (String, Color) {
        switch self {
        case .spelling: return ("textformat.abc", .red)
        case .grammar: return ("textformat.alt", .orange)
        case .style: return ("paintbrush", .blue)
        case .clarity: return ("lightbulb", .yellow)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
