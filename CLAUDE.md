# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mosin is a macOS grammar checker application that provides AI-powered spelling and grammar correction using MLX for local, private language processing. The app runs as a menu bar utility that monitors text input across all applications and provides real-time suggestions.

## Build and Development Commands

### Building
```bash
# Build the project
xcodebuild -project mosin.xcodeproj -scheme mosin -configuration Debug build

# Build for release
xcodebuild -project mosin.xcodeproj -scheme mosin -configuration Release build

# Clean build
xcodebuild -project mosin.xcodeproj -scheme mosin clean
```

### Running Tests
```bash
# Run unit tests
xcodebuild test -project mosin.xcodeproj -scheme mosin -destination 'platform=macOS'

# Run specific test target
xcodebuild test -project mosin.xcodeproj -scheme mosinTests -destination 'platform=macOS'

# Run UI tests
xcodebuild test -project mosin.xcodeproj -scheme mosinUITests -destination 'platform=macOS'
```

### Development Workflow
- The app requires accessibility permissions to monitor text across applications
- Code signing is configured with development team ID `63WNBHK932`
- Target deployment: macOS 14.0+
- Swift version: 5.0

## Architecture Overview

### Core Components

1. **MenuBarController** - Main application controller that manages the menu bar interface and coordinates all services
2. **AccessibilityService** - Handles macOS accessibility permissions and monitors text changes across applications
3. **TextProcessor** - Processes captured text through ML models with chunking, caching, and concurrent processing
4. **MLXModelManager** - Manages downloading, loading, and running MLX grammar models
5. **GrammarService** - Legacy service (being replaced by TextProcessor + MLXModelManager)
6. **OverlayController** - Manages UI overlays for displaying suggestions

### Text Processing Pipeline

1. **Text Capture**: AccessibilityService monitors system-wide text changes
2. **Text Processing**: TextProcessor chunks text and processes through available models
3. **Model Inference**: MLXModelManager runs grammar/style/clarity models 
4. **Caching**: Results are cached to improve performance
5. **UI Display**: Suggestions shown via overlays or menu bar interface

### Model Types
- **Grammar**: Primary correction model (T5-small, ~242MB)
- **Style**: Style enhancement (FLAN-T5-base, ~990MB) 
- **Clarity**: Readability improvement (DistilBERT, ~268MB)

### Key Data Structures
- `GrammarSuggestion`: Represents a grammar/style correction with range, confidence, and type
- `TextChunk`: Represents a piece of text to be processed with priority
- `MLXModel`: Represents an available model with download info and local storage

### Notification System
The app uses NotificationCenter for communication between components:
- `.textCaptured`: Text captured from accessibility system
- `.mosinTextCaptured`: Processed text ready for grammar checking
- `.mosinSuggestionsReady`: Grammar suggestions available for display

### Accessibility & Permissions
- Requires accessibility permissions for system-wide text monitoring
- Uses Apple Events for certain operations
- Runs outside sandbox (`com.apple.security.app-sandbox = false`)

## Important Implementation Details

### MLX Integration
- Models are stored in `~/Documents/MosinModels/`
- Currently uses simulated MLX inference (real MLX integration planned)
- Supports int4/int8 quantized models for performance

### Text Processing Strategy
- Text is chunked into ~1000 character segments for efficient processing
- Concurrent processing limited to 3 tasks to manage memory
- Results cached using SHA256 hashes of normalized text
- Debouncing prevents excessive processing during rapid text changes

### Menu Bar Interface
- Left click: Quick check of selected text
- Right click: Show full menu with options
- Hotkey: ⌘⇧G for manual text checking
- Dynamic model status indicators in submenu

### Testing Strategy
- Unit tests in `mosinTests/`
- UI tests in `mosinUITests/`
- Test both individual components and integration scenarios
- Mock MLX models for testing without actual model files