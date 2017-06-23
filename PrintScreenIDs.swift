// Part of Display Menu, Copyright © 2017 Chris Warrick. License: 3-clause BSD.

import Quartz

let maxDisplays: UInt32 = 16
var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0
CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)

func modeString(_ mode: CGDisplayMode) -> String {
    return "\(mode.width) \(mode.height) \(mode.pixelHeight / mode.height)x (\(mode.refreshRate) Hz)"
}

for displayID in onlineDisplays[0..<Int(displayCount)] {
    let screenID = "\(CGDisplayVendorNumber(displayID)):\(CGDisplayModelNumber(displayID)):\(CGDisplaySerialNumber(displayID))"
    print("--- ScreenID: " + screenID)
    let currentMode = CGDisplayCopyDisplayMode(displayID)

    if (currentMode == nil) {
        print("Current mode unknown")
    } else {
        print("Current mode:", modeString(currentMode!))
    }


    let settingsDict: CFDictionary = [kCGDisplayShowDuplicateLowResolutionModes as String: kCFBooleanTrue] as CFDictionary
    let modes = CGDisplayCopyAllDisplayModes(displayID, settingsDict as CFDictionary)! as! [CGDisplayMode]
    print("Supported modes:")
    for mode in modes {
        print("    " + modeString(mode))
    }
    print()
}
