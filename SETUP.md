# 🌊 Liquid Glass Setup

Simple setup for a magical productivity app.

## 🎯 Quick Start (15 minutes)

### Step 1: Get the Tools
```bash
# 1. Install Xcode from App Store (if not already installed)
# 2. Install LM Studio from https://lmstudio.ai
# 3. Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Create the Project
```bash
# Create a new macOS SwiftUI project in Xcode
# Name: DayPlanner  
# Language: Swift
# Interface: SwiftUI
# Use Core Data: No
# Include Tests: Yes
```

### Step 3: Setup LM Studio
1. Open LM Studio
2. Download any 7B+ parameter model (e.g., Llama 2, Mistral, Code Llama)
3. Go to "Local Server" tab
4. Start server on port 1234
5. Test: Open http://localhost:1234 in browser

### Step 4: Test Everything
```bash
# Test AI connection
curl http://localhost:1234/v1/models

# Should return JSON with model info
```

## 🏗️ Project Structure

Create this folder structure in Xcode:

```
DayPlanner/
├── App/
│   └── DayPlannerApp.swift
├── Glass/              # Liquid glass effects
│   ├── LiquidGlass.swift
│   ├── RippleEffects.swift  
│   └── GlassShaders.metal
├── Surfaces/           # Three main surfaces
│   ├── TodayGlass.swift
│   ├── AIOrb.swift
│   └── FlowGlass.swift
├── Data/              # Simple data models
│   ├── Models.swift
│   └── Storage.swift
├── AI/                # Local AI integration
│   └── AIService.swift
└── Resources/
    └── Assets.xcassets
```

## 🎨 Required Dependencies

Add these Swift Package Manager dependencies:

1. **No external dependencies needed!** 
   - SwiftUI (built-in)
   - Metal (built-in)
   - Foundation (built-in)

We're keeping it simple - pure SwiftUI + Metal for glass effects.

## 🚀 Development Environment

### Required
- **macOS 14+** (for latest SwiftUI features)
- **Xcode 15+** (for Metal shaders)  
- **Apple Silicon Mac** (M1/M2/M3) preferred for performance
- **LM Studio** with any 7B+ model

### Recommended
- **16GB+ RAM** (8GB for system, 4-8GB for AI model)
- **ProMotion display** (for 120fps glass animations)

## ⚡ Performance Setup

### Xcode Settings
1. **Build Configuration**: 
   - Debug: Enable "Metal API Validation" 
   - Release: Disable validation, enable optimizations

2. **Metal Settings**:
   - Enable "Metal Performance Shaders"
   - Set "Metal Language Revision" to latest

3. **SwiftUI Settings**:
   - Enable "SwiftUI Previews"
   - Use "iOS 17.0 / macOS 14.0" deployment target

### LM Studio Settings  
1. **Model Loading**: 
   - Use GPU acceleration if available
   - Set context length to 4096+ tokens
   - Enable streaming responses

2. **Server Settings**:
   - Port: 1234 (default)
   - Enable CORS for local development
   - Set request timeout to 30 seconds

## 🧪 Testing Setup

### Quick Test Script
Create this test file to verify everything works:

```swift
// QuickTest.swift
import SwiftUI

struct QuickTest: View {
    @State private var aiResponse = "Testing AI connection..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🌊 Liquid Glass Setup Test")
                .font(.title)
            
            // Test glass effect
            Text("Glass Effect Test")
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            
            // Test AI connection
            Text(aiResponse)
                .padding()
            
            Button("Test AI") {
                testAI()
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func testAI() {
        Task {
            do {
                let url = URL(string: "http://localhost:1234/v1/models")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = String(data: data, encoding: .utf8) ?? "No response"
                
                await MainActor.run {
                    aiResponse = response.isEmpty ? "AI Connected ✅" : "AI Connected ✅"
                }
            } catch {
                await MainActor.run {
                    aiResponse = "AI Connection Failed ❌: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

## 🎯 Verification Checklist

Before starting development, verify:

### ✅ Xcode Setup
- [ ] Xcode 15+ installed
- [ ] macOS 14+ target set  
- [ ] Metal shaders enabled
- [ ] SwiftUI previews working

### ✅ LM Studio Setup
- [ ] LM Studio installed and running
- [ ] AI model downloaded (7B+ parameters)
- [ ] Local server running on port 1234
- [ ] Test endpoint responds: `curl http://localhost:1234/v1/models`

### ✅ Project Setup
- [ ] SwiftUI macOS project created
- [ ] Folder structure organized
- [ ] QuickTest runs successfully
- [ ] Glass effects render (even basic ones)

### ✅ Performance Check
- [ ] App launches in <2 seconds
- [ ] Animations run at 60fps minimum
- [ ] AI responses in <3 seconds
- [ ] No memory leaks in basic testing

## 🚧 Common Issues & Fixes

### LM Studio Won't Connect
```bash
# Check if server is actually running
curl http://localhost:1234/health

# Restart LM Studio server
# Make sure no firewall is blocking port 1234
```

### Glass Effects Not Showing
- Verify Metal is enabled in build settings
- Check macOS version is 14+
- Test on actual hardware (not simulator for Metal)

### Slow Performance
- Use Release build configuration for testing
- Ensure AI model fits in available RAM
- Check Activity Monitor for memory pressure

## 🎨 Design Resources

### Colors for Liquid Glass
```swift
// Time-based glass tints
let morningTint = Color(hue: 0.6, saturation: 0.3, brightness: 0.9)   // Cool blue
let afternoonTint = Color(hue: 0.1, saturation: 0.4, brightness: 0.95) // Warm gold  
let eveningTint = Color(hue: 0.8, saturation: 0.5, brightness: 0.8)    // Purple

// Glass materials
let crystalGlass = Material.ultraThinMaterial
let mistGlass = Material.thinMaterial
let waterGlass = Material.regularMaterial
```

### Animation Presets
```swift
// Liquid glass animations
let rippleAnimation = Animation.easeOut(duration: 0.8)
let flowAnimation = Animation.spring(response: 0.6, dampingFraction: 0.8)
let settleAnimation = Animation.spring(response: 1.2, dampingFraction: 0.7)
```

## 🚀 Ready to Build!

Once setup is complete:

1. **Start with Glass Foundation** (Week 1)
2. **Build Today View** (Week 1-2)  
3. **Add AI Orb** (Week 2-3)
4. **Create Flow Panel** (Week 3-4)

See [BUILD_PROGRESS.md](./BUILD_PROGRESS.md) for detailed development timeline.

---

*Setup time: ~15 minutes*  
*First working prototype: ~2 hours*  
*Magic productivity app: ~8 weeks* ✨
