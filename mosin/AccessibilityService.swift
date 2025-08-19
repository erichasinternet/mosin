//
//  AccessibilityService.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation
import ApplicationServices
import Cocoa

class AccessibilityService: ObservableObject {
    @Published var isEnabled = false
    private var observer: AXObserver?
    
    init() {
        checkAccessibilityPermissions()
    }
    
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.isEnabled = accessEnabled
        }
        
        return accessEnabled
    }
    
    func startMonitoring() {
        guard checkAccessibilityPermissions() else {
            print("Accessibility permissions not granted")
            return
        }
        
        setupGlobalTextMonitoring()
    }
    
    func stopMonitoring() {
        if let observer = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                CFRunLoopMode.defaultMode
            )
            self.observer = nil
        }
    }
    
    private func setupGlobalTextMonitoring() {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var observer: AXObserver?
        let observerCallback: AXObserverCallback = { observer, element, notification, refcon in
            let service = Unmanaged<AccessibilityService>.fromOpaque(refcon!).takeUnretainedValue()
            service.handleTextChange(element: element, notification: notification)
        }
        
        let result = AXObserverCreate(getpid(), observerCallback, &observer)
        guard result == .success, let observer = observer else {
            print("Failed to create AX observer")
            return
        }
        
        self.observer = observer
        
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        AXObserverAddNotification(
            observer,
            systemWideElement,
            kAXValueChangedNotification as CFString,
            refcon
        )
        
        AXObserverAddNotification(
            observer,
            systemWideElement,
            kAXSelectedTextChangedNotification as CFString,
            refcon
        )
        
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            CFRunLoopMode.defaultMode
        )
    }
    
    private func handleTextChange(element: AXUIElement, notification: CFString) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.processTextElement(element)
        }
    }
    
    private func processTextElement(_ element: AXUIElement) {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success,
              let text = value as? String,
              !text.isEmpty,
              text.count > 3 else {
            return
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .textCaptured,
                object: nil,
                userInfo: ["text": text, "element": element]
            )
        }
    }
}

extension Notification.Name {
    static let textCaptured = Notification.Name("textCaptured")
    static let accessibilityPermissionChanged = Notification.Name("accessibilityPermissionChanged")
}