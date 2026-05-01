# Speed Machine App - Quick Start Guide

## 🚀 Get Running in 5 Minutes

### 1. Open Xcode Project
```bash
open "/Users/jaritgolf/Desktop/Traning Program App/SpeedMachineApp/SpeedMachineApp/SpeedMachineApp.xcodeproj"
```

Or:
- Navigate to: `Desktop/Traning Program App/SpeedMachineApp/SpeedMachineApp/`
- Double-click `SpeedMachineApp.xcodeproj`

---

### 2. Add Files to Project (CRITICAL STEP!)

The files are in your project folder but need to be added to Xcode:

**In Xcode:**
1. Right-click on `SpeedMachineApp` folder (blue icon) in left sidebar
2. Choose **"Add Files to SpeedMachineApp..."**
3. Navigate to and select these folders:
   - App
   - Models
   - Views
   - ViewModels
   - Services
   - CoreData
   - Resources
   - Utilities
   - Info.plist

4. **IMPORTANT:** Check these options:
   - ✅ "Create groups" (not references)
   - ✅ "Add to targets: SpeedMachineApp"
   - ❌ "Copy items if needed" (UNCHECK - files are already there)

5. Click **Add**

---

### 3. Delete Old Template Files

Right-click and delete these (they're replaced by new files):
- `ContentView.swift` → Delete → Move to Trash
- `SpeedMachineAppApp.swift` → Delete → Move to Trash

---

### 4. Configure Project

Click the blue **SpeedMachineApp** project → Select **SpeedMachineApp** target:

**General Tab:**
- Minimum Deployments: **iOS 15.0**
- Display Name: **Speed Machine**

**Signing & Capabilities Tab:**
- ✅ Automatically manage signing
- Select your **Team**
- Click **+ Capability** → Add **Background Modes**
- Check: **Uses Bluetooth LE accessories**

---

### 5. Build & Run

1. Select **iPhone 15 Pro** simulator (or any iPhone)
2. Press **⌘B** to build
3. Press **⌘R** to run

**Expected:** App launches with Home screen showing:
- Device Status: Disconnected
- Training Program: Day 1 of 30
- Combine Mode card
- Progress card

---

## ✅ You're Done!

The app should now be running. Bluetooth won't work in the simulator (that's normal).

To test Bluetooth:
- Deploy to a **real iPhone**
- Enable Bluetooth
- Connect to your Speed Machine device

---

## 📁 What You Should See in Xcode

After adding files, your Project Navigator should look like:

```
SpeedMachineApp
├── App
│   └── SpeedMachineApp.swift
├── Models
│   ├── CombineGame.swift
│   └── TrainingProgram.swift
├── Views
│   ├── Home
│   │   └── HomeView.swift
│   ├── Training
│   │   ├── DaySelectionView.swift
│   │   └── TrainingSessionView.swift
│   ├── Combine
│   │   └── CombineModeView.swift
│   ├── Progress
│   │   └── ProgressView.swift
│   ├── Settings
│   │   └── SettingsView.swift
│   └── Connection
│       └── ConnectionView.swift
├── ViewModels
│   ├── TrainingViewModel.swift
│   └── CombineViewModel.swift
├── Services
│   ├── BluetoothService.swift
│   └── DataService.swift
├── CoreData
│   └── SpeedMachine.xcdatamodeld
├── Resources
│   └── speed-machine-training-program.json
├── Utilities
│   ├── Constants.swift
│   └── Extensions.swift
├── Assets.xcassets
└── Info.plist
```

---

## 🐛 Quick Troubleshooting

**"Cannot find ContentView in scope"**
→ Good! You deleted the old template file. Just build again.

**"No such module 'CoreData'"**
→ Make sure you added the `.xcdatamodeld` folder to the target

**"speed-machine-training-program.json not found"**
→ Select the JSON file → File Inspector → Check "SpeedMachineApp" under Target Membership

**Build succeeds but app crashes**
→ Check Console for errors. Usually means Core Data model or JSON not loaded.

---

## 📞 Need Help?

See the full **DEPLOYMENT_CHECKLIST.md** for detailed troubleshooting and TestFlight deployment instructions.

---

**Ready to build?** Just press **⌘R** and you're off! 🚀
