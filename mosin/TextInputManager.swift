//
//  TextInputManager.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation
import Cocoa
import Carbon

class TextInputManager: ObservableObject {
    @Published var capturedText: String = ""
    @Published var textSource: TextSource = .none
    
    private var hotkeyID: EventHotKeyID
    private var hotkeyRef: EventHotKeyRef?
    private var clipboardMonitor: Timer?
    private var lastClipboardContent: String = ""
    
    enum TextSource {
        case none
        case hotkey
        case clipboard
        case manual
    }
    
    init() {
        self.hotkeyID = EventHotKeyID(signature: 0x4D4F534E, id: 1) // 'MOSN'
        setupHotkey()
        startClipboardMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupHotkey() {
        // TODO: Implement hotkey registration when needed
        // For now, we'll use clipboard monitoring and manual text processing
        print("⚠️ Hotkey registration not implemented yet - use clipboard monitoring instead")
    }
    
    private func handleHotkeyPress() {
        print("🔥 Hotkey pressed - capturing selected text")
        captureSelectedText()
    }
    
    func captureSelectedText() {
        // For now, just capture current clipboard content
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            DispatchQueue.main.async {
                self.capturedText = text
                self.textSource = .manual
                self.notifyTextCaptured(text, source: .manual)
            }
        } else {
            print("⚠️ No text in clipboard to capture")
        }
    }
    
    private func startClipboardMonitoring() {
        lastClipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
        
        clipboardMonitor = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard let newContent = pasteboard.string(forType: .string),
              !newContent.isEmpty,
              newContent != lastClipboardContent,
              newContent.count > 10, // Only check substantial text
              self.isTextWorthChecking(newContent) else {
            return
        }
        
        lastClipboardContent = newContent
        print("📋 Clipboard changed: \(newContent.prefix(50))...")
        
        DispatchQueue.main.async {
            self.capturedText = newContent
            self.textSource = .clipboard
            self.notifyTextCaptured(newContent, source: .clipboard)
            print("📨 Posted textCaptured notification")
        }
    }
    
    private func isTextWorthChecking(_ text: String) -> Bool {
        // Skip URLs, file paths, code, etc.
        if text.hasPrefix("http") || 
           text.hasPrefix("/") ||
           text.contains("://") ||
           text.contains("{") ||
           text.contains("$(") {
            return false
        }
        
        // Check if it looks like natural language
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        return wordCount >= 3 && text.count >= 20
    }
    
    func processManualText(_ text: String) {
        guard !text.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.capturedText = text
            self.textSource = .manual
            self.notifyTextCaptured(text, source: .manual)
        }
    }
    
    private func notifyTextCaptured(_ text: String, source: TextSource) {
        NotificationCenter.default.post(
            name: .textCaptured,
            object: nil,
            userInfo: [
                "text": text,
                "source": source,
                "timestamp": Date()
            ]
        )
    }
    
    private func cleanup() {
        clipboardMonitor?.invalidate()
        
        if let hotKeyRef = hotkeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}

