//
//  OverlayController.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import SwiftUI
import Cocoa

class OverlayController: ObservableObject {
    private var overlayWindows: [UUID: NSWindow] = [:]
    private var currentSuggestions: [GrammarSuggestion] = []
    private let textProcessor: TextProcessor
    
    // Configuration
    private let overlayDisplayDuration: TimeInterval = 8.0
    private let maxSimultaneousOverlays = 3
    
    init(textProcessor: TextProcessor) {
        self.textProcessor = textProcessor
    }
    
    func showSuggestions(_ suggestions: [GrammarSuggestion]) {
        currentSuggestions = suggestions
        
        // Group suggestions by priority and limit display
        let prioritizedSuggestions = suggestions
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxSimultaneousOverlays)
        
        hideAllOverlays()
        
        for (index, suggestion) in prioritizedSuggestions.enumerated() {
            showSuggestionOverlay(suggestion, index: index)
        }
    }
    
    private func showSuggestionOverlay(_ suggestion: GrammarSuggestion, index: Int) {
        let overlayId = UUID()
        
        // Calculate position for overlay
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        
        // Offset overlays to avoid overlap
        let offsetX: CGFloat = CGFloat(index * 20)
        let offsetY: CGFloat = CGFloat(index * -60)
        
        let overlayFrame = NSRect(
            x: min(mouseLocation.x + offsetX, screenFrame.maxX - 320),
            y: min(mouseLocation.y + offsetY - 100, screenFrame.maxY - 150),
            width: 300,
            height: 120
        )
        
        let overlayView = SuggestionOverlayView(
            suggestion: suggestion,
            onAccept: { [weak self] in
                self?.acceptSuggestion(suggestion, overlayId: overlayId)
            },
            onReject: { [weak self] in
                self?.rejectSuggestion(overlayId: overlayId)
            },
            onDismiss: { [weak self] in
                self?.dismissOverlay(overlayId)
            }
        )
        
        let hostingController = NSHostingController(rootView: overlayView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.setFrame(overlayFrame, display: true)
        window.styleMask = [.borderless]
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)
        
        // Add subtle animation
        window.animator().alphaValue = 0.0
        window.alphaValue = 1.0
        
        overlayWindows[overlayId] = window
        
        // Auto-dismiss after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + overlayDisplayDuration) {
            self.dismissOverlay(overlayId)
        }
    }
    
    private func acceptSuggestion(_ suggestion: GrammarSuggestion, overlayId: UUID) {
        // Apply the suggestion (would integrate with the active app)
        applySuggestionToActiveApp(suggestion)
        
        dismissOverlay(overlayId)
        
        // Show brief confirmation
        showConfirmationMessage("Applied: \(suggestion.suggestedText)")
        
        print("✅ Applied suggestion: \(suggestion.originalText) → \(suggestion.suggestedText)")
    }
    
    private func rejectSuggestion(overlayId: UUID) {
        dismissOverlay(overlayId)
        print("❌ Rejected suggestion")
    }
    
    private func dismissOverlay(_ overlayId: UUID) {
        guard let window = overlayWindows[overlayId] else { return }
        
        // Animate out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 0.0
        } completionHandler: {
            window.close()
        }
        
        overlayWindows.removeValue(forKey: overlayId)
    }
    
    func hideAllOverlays() {
        for overlayId in overlayWindows.keys {
            dismissOverlay(overlayId)
        }
    }
    
    private func applySuggestionToActiveApp(_ suggestion: GrammarSuggestion) {
        // This would implement the actual text replacement in the active application
        // For now, copy the corrected text to clipboard as a fallback
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(suggestion.suggestedText, forType: .string)
        
        // Show user instruction
        showConfirmationMessage("Copied '\(suggestion.suggestedText)' to clipboard")
    }
    
    private func showConfirmationMessage(_ message: String) {
        let overlayId = UUID()
        
        let mouseLocation = NSEvent.mouseLocation
        let overlayFrame = NSRect(
            x: mouseLocation.x - 100,
            y: mouseLocation.y - 60,
            width: 200,
            height: 40
        )
        
        let confirmationView = ConfirmationOverlayView(message: message)
        let hostingController = NSHostingController(rootView: confirmationView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.setFrame(overlayFrame, display: true)
        window.styleMask = [.borderless]
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.makeKeyAndOrderFront(nil)
        
        overlayWindows[overlayId] = window
        
        // Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.dismissOverlay(overlayId)
        }
    }
}

// MARK: - Suggestion Overlay View

struct SuggestionOverlayView: View {
    let suggestion: GrammarSuggestion
    let onAccept: () -> Void
    let onReject: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                suggestionTypeIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(suggestion.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(suggestion.originalText)
                        .strikethrough()
                        .foregroundColor(.red)
                        .font(.system(.body, design: .monospaced))
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.suggestedText)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                        .font(.system(.body, design: .monospaced))
                    
                    Spacer()
                }
            }
            
            HStack {
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return)
                
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.escape)
                
                Spacer()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var suggestionTypeIcon: some View {
        let (icon, color) = suggestion.type.iconAndColor
        return Image(systemName: icon)
            .foregroundColor(color)
            .font(.title3)
    }
}

// MARK: - Confirmation Overlay View

struct ConfirmationOverlayView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .shadow(radius: 4)
        }
    }
}

