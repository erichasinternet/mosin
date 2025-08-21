//
//  MenuBarController.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import SwiftUI
import Cocoa

class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menuBarMenu: NSMenu?
    private var settingsWindow: NSWindow?
    private var overlayController: OverlayController?
    
    @Published var isEnabled = true
    @Published var showingSettings = false
    
    private var modelManager: MLXModelManager!
    private var textProcessor: TextProcessor!
    private var textInputManager: TextInputManager!
    
    init() {
        self.modelManager = MLXModelManager()
        self.textProcessor = TextProcessor(modelManager: modelManager)
        self.textInputManager = TextInputManager()
        self.overlayController = OverlayController(textProcessor: textProcessor)
        
        setupMenuBar()
        setupNotificationObservers()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "Mosin")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        menuBarMenu = NSMenu()
        
        // Status section
        let titleItem = NSMenuItem(title: "Mosin Grammar Checker", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menuBarMenu?.addItem(titleItem)
        
        menuBarMenu?.addItem(NSMenuItem.separator())
        
        // Toggle monitoring
        let toggleItem = NSMenuItem(
            title: isEnabled ? "Disable Monitoring" : "Enable Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menuBarMenu?.addItem(toggleItem)
        
        // Check selected text manually
        let checkTextItem = NSMenuItem(
            title: "Check Selected Text",
            action: #selector(checkSelectedText),
            keyEquivalent: "g"
        )
        checkTextItem.keyEquivalentModifierMask = [.command, .shift]
        checkTextItem.target = self
        menuBarMenu?.addItem(checkTextItem)
        
        menuBarMenu?.addItem(NSMenuItem.separator())
        
        // Model management submenu
        let modelsSubmenu = NSMenu()
        updateModelsSubmenu(modelsSubmenu)
        
        let modelsItem = NSMenuItem(title: "Models", action: nil, keyEquivalent: "")
        modelsItem.submenu = modelsSubmenu
        menuBarMenu?.addItem(modelsItem)
        
        menuBarMenu?.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menuBarMenu?.addItem(settingsItem)
        
        // About
        let aboutItem = NSMenuItem(
            title: "About Mosin",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menuBarMenu?.addItem(aboutItem)
        
        menuBarMenu?.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Mosin",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menuBarMenu?.addItem(quitItem)
        
        statusItem?.menu = menuBarMenu
    }
    
    private func updateModelsSubmenu(_ submenu: NSMenu) {
        submenu.removeAllItems()
        
        let modelStatuses = modelManager.getModelStatus()
        
        for modelType in ModelType.allCases {
            let status = modelStatuses[modelType] ?? "unknown"
            let statusIcon = switch status {
            case "loaded": "● "
            case "downloaded": "○ "
            default: "◯ "
            }
            
            let item = NSMenuItem(
                title: "\(statusIcon)\(modelType.displayName)",
                action: #selector(toggleModel(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = modelType
            item.isEnabled = status != "not_downloaded"
            submenu.addItem(item)
        }
        
        submenu.addItem(NSMenuItem.separator())
        
        let downloadItem = NSMenuItem(
            title: "Download Models...",
            action: #selector(showModelDownloader),
            keyEquivalent: ""
        )
        downloadItem.target = self
        submenu.addItem(downloadItem)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSuggestionsReady(_:)),
            name: .mosinSuggestionsReady,
            object: nil
        )
    }
    
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Right click - show menu immediately
            statusItem?.menu = menuBarMenu
        } else {
            // Left click - toggle quick check
            checkSelectedText()
        }
    }
    
    @objc private func toggleMonitoring() {
        isEnabled.toggle()
        updateMenuItems()
        
        if isEnabled {
            print("✅ Monitoring enabled")
        } else {
            print("⏸️ Monitoring disabled")
            overlayController?.hideAllOverlays()
        }
    }
    
    @objc private func checkSelectedText() {
        guard isEnabled else { return }
        
        // Trigger text capture manually
        textInputManager.captureSelectedText()
    }
    
    @objc private func toggleModel(_ sender: NSMenuItem) {
        guard let modelType = sender.representedObject as? ModelType else { return }
        
        Task {
            do {
                if modelManager.isModelLoaded[modelType] == true {
                    modelManager.unloadModel(modelType)
                } else {
                    try await modelManager.loadModel(modelType)
                }
                
                await MainActor.run {
                    self.updateMenuItems()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to toggle model: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func showModelDownloader() {
        showSettings()
        // TODO: Focus on models tab in settings
    }
    
    @objc private func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                modelManager: modelManager,
                textProcessor: textProcessor
            )
            
            let hostingController = NSHostingController(rootView: settingsView)
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "Mosin Settings"
            settingsWindow?.setContentSize(NSSize(width: 600, height: 400))
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
            settingsWindow?.center()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        showingSettings = true
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Mosin Grammar Checker"
        alert.informativeText = """
        Version 1.0.0
        
        AI-powered spelling and grammar correction for macOS
        Using MLX for local, private language processing
        
        Hotkey: ⌘⇧G to check selected text
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    @objc private func handleSuggestionsReady(_ notification: Notification) {
        guard isEnabled,
              let suggestions = notification.userInfo?["suggestions"] as? [GrammarSuggestion],
              !suggestions.isEmpty else {
            return
        }
        
        overlayController?.showSuggestions(suggestions)
    }
    
    private func updateMenuItems() {
        guard let menu = menuBarMenu else { return }
        
        // Update toggle monitoring item  
        let currentTitle = isEnabled ? "Disable Monitoring" : "Enable Monitoring"
        let targetTitle = isEnabled ? "Enable Monitoring" : "Disable Monitoring"
        if let toggleItem = menu.item(withTitle: currentTitle) {
            toggleItem.title = targetTitle
        }
        
        // Update models submenu
        if let modelsItem = menu.item(withTitle: "Models"),
           let submenu = modelsItem.submenu {
            updateModelsSubmenu(submenu)
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    let modelManager: MLXModelManager
    let textProcessor: TextProcessor
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            ModelsSettingsView(modelManager: modelManager)
                .tabItem {
                    Label("Models", systemImage: "brain")
                }
                .tag(1)
            
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(minWidth: 500, minHeight: 350)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("enableClipboardMonitoring") private var enableClipboardMonitoring = true
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("autoStartOnLogin") private var autoStartOnLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Monitor clipboard for text changes", isOn: $enableClipboardMonitoring)
                Toggle("Show notifications for suggestions", isOn: $enableNotifications)
                Toggle("Start Mosin automatically on login", isOn: $autoStartOnLogin)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Hotkey")
                    .font(.headline)
                
                HStack {
                    Text("⌘⇧G")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text("Check selected text")
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ModelsSettingsView: View {
    @ObservedObject var modelManager: MLXModelManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Models")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(modelManager.availableModels, id: \.name) { model in
                        ModelRowView(model: model, manager: modelManager)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ModelRowView: View {
    let model: MLXModel
    @ObservedObject var manager: MLXModelManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.type.displayName)
                    .font(.headline)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("Size: \(model.sizeString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if manager.isModelLoaded[model.type] == true {
                    Button("Unload") {
                        manager.unloadModel(model.type)
                    }
                    .buttonStyle(.bordered)
                } else if model.isDownloaded {
                    Button("Load") {
                        Task {
                            try? await manager.loadModel(model.type)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Download") {
                        Task {
                            try? await manager.downloadModel(model)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.cursor")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Mosin Grammar Checker")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundColor(.secondary)
            
            Text("AI-powered spelling and grammar correction for macOS using MLX for local, private language processing.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}