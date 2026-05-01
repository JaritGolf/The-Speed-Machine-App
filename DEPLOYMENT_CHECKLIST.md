# Speed Machine App - Deployment Checklist

## ✅ Files Ready - Status: COMPLETE

All Swift files, resources, and configuration files have been copied into your Xcode project at:
```
/Users/jaritgolf/Desktop/Traning Program App/SpeedMachineApp/SpeedMachineApp/
```

---

## 📋 Step-by-Step Deployment Instructions

### Step 1: Open the Project in Xcode
1. Navigate to: `/Users/jaritgolf/Desktop/Traning Program App/SpeedMachineApp/SpeedMachineApp/`
2. Double-click `SpeedMachineApp.xcodeproj` to open in Xcode

### Step 2: Add Files to Xcode Target

**IMPORTANT:** The files are in your project folder but need to be added to the Xcode project.

1. In Xcode, **right-click** on the `SpeedMachineApp` folder in the Project Navigator (left sidebar)
2. Select **"Add Files to SpeedMachineApp..."**
3. Navigate to `/Users/jaritgolf/Desktop/Traning Program App/SpeedMachineApp/SpeedMachineApp/SpeedMachineApp/`
4. Select **ALL** of these folders:
   - ✅ App
   - ✅ Models
   - ✅ Views
   - ✅ ViewModels
   - ✅ Services
   - ✅ CoreData
   - ✅ Resources
   - ✅ Utilities
   - ✅ Info.plist (if not already added)

5. **Make sure these options are checked:**
   - ✅ "Copy items if needed" (uncheck, files are already in place)
   - ✅ "Create groups" (selected)
   - ✅ "Add to targets: SpeedMachineApp" (checked)

6. Click **"Add"**

### Step 3: Remove Default Template Files

Delete these files from the project (they're not needed):
1. Right-click `ContentView.swift` → Delete → Move to Trash
2. Right-click `SpeedMachineAppApp.swift` → Delete → Move to Trash

(The new `SpeedMachineApp.swift` in the `App` folder replaces these)

### Step 4: Configure Project Settings

1. Click on the **blue SpeedMachineApp project** at the top of the Project Navigator
2. Select the **SpeedMachineApp target** (under TARGETS)
3. Go to the **"General"** tab:
   - **Display Name:** Speed Machine
   - **Bundle Identifier:** com.jaritgolf.SpeedMachine (or your preferred identifier)
   - **Minimum Deployments:** iOS 15.0
   - **iPhone Orientation:** Portrait only

4. Go to the **"Signing & Capabilities"** tab:
   - Check **"Automatically manage signing"**
   - Select your **Team** (Apple Developer account)
   - Xcode will generate a provisioning profile

5. Add **Background Modes** capability:
   - Click **"+ Capability"** button
   - Search for and add **"Background Modes"**
   - Check **"Uses Bluetooth LE accessories"**

### Step 5: Verify Info.plist

1. Click on `Info.plist` in the Project Navigator
2. Verify these keys exist:
   - ✅ `NSBluetoothAlwaysUsageDescription`
   - ✅ `NSBluetoothPeripheralUsageDescription`
   - ✅ `UIBackgroundModes` with `bluetooth-central`

If Xcode asks to use the new Info.plist, choose **"Replace"**

### Step 6: Verify Resource Files

1. Click on `speed-machine-training-program.json` in Project Navigator
2. In the **File Inspector** (right sidebar), verify:
   - ✅ **Target Membership:** SpeedMachineApp is checked

### Step 7: Configure the Scheme

1. Click the scheme dropdown next to the Run button (says "SpeedMachineApp")
2. Select **"Edit Scheme..."**
3. Under **Run → Info**:
   - Build Configuration: **Debug**
   - Executable: **SpeedMachineApp.app**

### Step 8: Build the Project

1. Select a **Simulator** or connect your **iPhone**
   - Recommended: iPhone 15 Pro simulator for testing

2. Press **⌘B** (or Product → Build)

3. Fix any build errors:
   - If you see "Cannot find 'ContentView' in scope", you successfully removed the old file
   - If you see import errors, make sure all files are added to the target
   - If Core Data errors appear, verify the `.xcdatamodeld` folder was added

### Step 9: Run the App

1. Press **⌘R** (or click the Play button)
2. App should launch in the simulator/device

---

## 🔍 Expected First Launch

When the app launches for the first time:

1. **Home Screen** should appear with:
   - Device Status card (showing "Disconnected")
   - Training Program card (showing "Day 1 of 30")
   - Combine Mode card
   - Progress card

2. **No BLE device will connect** in the simulator (Bluetooth doesn't work in simulator)

3. To test **BLE connection**:
   - Deploy to a **real iPhone**
   - Make sure Bluetooth is enabled
   - Have your Speed Machine device ready with Bluetooth enabled

---

## 🧪 Testing Checklist

### Test on Simulator (No BLE)
- [ ] App launches without crashes
- [ ] Home screen displays correctly
- [ ] Can navigate to Day Selection
- [ ] Can view day details and blocks
- [ ] Can navigate to Settings
- [ ] Can navigate to Progress view
- [ ] UI follows Jarit Golf branding (black/white/green)

### Test on Real Device (With BLE)
- [ ] App requests Bluetooth permission
- [ ] Can scan for devices
- [ ] Can connect to "Speed Machine"
- [ ] Connection indicator shows blue ring
- [ ] Can start a training session
- [ ] Speed data appears when device sends data
- [ ] Can complete a training block
- [ ] Progress is saved
- [ ] Can play Combine mode
- [ ] Battery level displays

---

## 🐛 Common Issues & Fixes

### Issue: Build fails with "Cannot find type 'UserProgressData'"
**Fix:** Make sure `SpeedMachine.xcdatamodeld` is added to the target
- Select the `.xcdatamodeld` folder in Project Navigator
- Check the File Inspector → Target Membership → SpeedMachineApp (checked)

### Issue: "speed-machine-training-program.json not found"
**Fix:** Ensure JSON file is in the app bundle
- Select `speed-machine-training-program.json`
- Check Target Membership → SpeedMachineApp (checked)

### Issue: Multiple "ContentView" errors
**Fix:** Delete the old template ContentView.swift file
- Find and delete the default `ContentView.swift`
- Our new `SpeedMachineApp.swift` has its own ContentView

### Issue: Bluetooth permission alert doesn't appear
**Fix:** Reset simulator/device
- iOS Simulator: Device → Erase All Content and Settings
- Real device: Settings → General → Reset → Reset Location & Privacy

### Issue: App crashes on launch
**Fix:** Check the Console for errors
- Common causes:
  - Core Data model not loaded
  - JSON file not found in bundle
  - Missing environment objects

---

## 📱 TestFlight Deployment (Optional)

Once the app is working on your device:

1. **Archive the app:**
   - Product → Archive
   - Wait for archive to complete

2. **Upload to App Store Connect:**
   - Window → Organizer
   - Select the archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Follow the wizard

3. **Create a TestFlight build:**
   - Go to App Store Connect
   - Add internal/external testers
   - Submit for beta review (external only)

---

## 📊 Project File Count

**Total Swift Files:** 18
- App: 1
- Models: 2
- Views: 7
- ViewModels: 2
- Services: 2
- Utilities: 2
- Core Data Entities: Defined in DataService.swift
- Tests: 2 (default template)

**Resources:**
- Training program JSON: 1
- Core Data model: 1
- Info.plist: 1

---

## ✅ Final Checklist Before First Build

- [ ] Xcode project opened
- [ ] All folders added to project
- [ ] Files show in Project Navigator with folder structure
- [ ] Target membership set for all Swift files
- [ ] JSON file added to target
- [ ] Core Data model added to target
- [ ] Info.plist configured with Bluetooth permissions
- [ ] Background Modes capability added
- [ ] Signing configured with your team
- [ ] Minimum deployment set to iOS 15.0
- [ ] Old template files (ContentView.swift, SpeedMachineAppApp.swift) deleted

---

## 🎉 Success Criteria

Your app is ready to deploy when:
✅ Builds without errors
✅ Runs in simulator
✅ Home screen displays correctly
✅ Navigation works between screens
✅ Can view training program days
✅ Settings screen accessible
✅ No runtime crashes

---

## 📞 Next Steps After Deployment

1. **Test with real device + Speed Machine hardware**
2. **Verify BLE connection works**
3. **Complete a training session**
4. **Test Combine mode**
5. **Share feedback or report issues**

---

**Project Status:** ✅ READY TO BUILD
**Last Updated:** January 25, 2026
**Created by:** Claude for Jarit Golf
