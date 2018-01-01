/*
 * Display Menu
 * Copyright © 2017-2018, Chris Warrick.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions, and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions, and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the author of this software nor the names of
 *    contributors to this software may be used to endorse or promote
 *    products derived from this software without specific prior written
 *    consent.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import Quartz

// MARK: - Dock settings

/**
 The side on which the Dock should appear.
 Accepted values: `left`, `right`, `bottom`.
*/
enum DockPosition: String {
    case left, right, bottom
}

/// A preset for the Dock appearance (side and icon size).
class DockPreset: CustomStringConvertible {
    /// Name of the preset.
    let name: String
    /// The side on which the Dock should appear.
    let position: DockPosition
    /// Tile (icon) size, in pixels.
    let tilesize: Int

    /**
     Initialize a preset.

     - parameter position: The side on which the Dock should appear.
     - parameter tilesize: Tile (icon) size, in pixels.
    */
    init(name: String, position: DockPosition, tilesize: Int) {
        self.name = name
        self.position = position
        self.tilesize = tilesize
    }

    convenience init(name: String, position: String, tilesize: Int) throws {
        let enumPosition = DockPosition(rawValue: position)
        if (enumPosition == nil) {
            throw DisplayManagerError.UnknownDockPosition
        }
        self.init(name: name, position: enumPosition!, tilesize: tilesize)
    }

    /// Apply a dock preset.
    func apply(force: Bool = false) {
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        if !force {
            let tilesize_current = defaults?.integer(forKey: "tilesize")
            let position_current = defaults?.string(forKey: "orientation")

            if tilesize == tilesize_current && position.rawValue == position_current {
                return // Don’t change the settings if it’s what we want already
            }
        }

        defaults?.set(tilesize, forKey: "tilesize")
        defaults?.set(position.rawValue, forKey: "orientation")
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            if app.bundleIdentifier == "com.apple.dock" {
                app.terminate()
            }
        }
    }

    var description: String {
        return "Dock Preset \(name) (\(position), \(tilesize))"
    }
}

// MARK: - Helper types

/// A screen ID, which uniquely describes a display device (based on display vendor number, model number and serial number).
typealias ScreenID = String

/** Return a screen ID.

 - parameter displayID: a display ID (from Core Graphics).
 */
func getScreenID(displayID: CGDirectDisplayID) -> ScreenID {
    return "\(CGDisplayVendorNumber(displayID)):\(CGDisplayModelNumber(displayID)):\(CGDisplaySerialNumber(displayID))" as ScreenID
}

/// A display identifier string. May be a ScreenID, a name, or a symbol.
typealias DisplayIdentifierString = String

let DEFAULT_REFRESH_RATE: Double = 60.0
let REFRESH_RATE_IGNORE: Double = 0.0

/// A screen resolution.
class Resolution: Hashable, Equatable, CustomStringConvertible {
    let width: Int
    let height: Int
    let scale: Int

    /// Initialize a screen resolution, based on width, height, and scale.
    init(width: Int, height: Int, scale: Int) {
        self.width = width
        self.height = height
        self.scale = scale
    }

    /// Initialize a screen resolution, based on a resolution string (`"(width) (height) (scale)x"`), as returned by `description`.
    convenience init(resolutionString: String) {
        self.init(resolutionParts: resolutionString.components(separatedBy: " "))
    }

    /// Initialize a screen resolution, based on a resolution string (`"(width) (height) (scale)x"`), that has already been split into parts.
    convenience init(resolutionParts: [String]) {
        let scale = String(resolutionParts[2].first!)
        self.init(width: Int(resolutionParts[0])!, height: Int(resolutionParts[1])!, scale: Int(scale)!)
    }

    /// Describe resolution in the format `"(width) (height) (scale)x"`.
    public var description: String {
        return "\(width) \(height) \(scale)x"
    }

    public var hashValue: Int {
        return scale * 100000000 + height * 10000 + width
    }

    static func ==(lhs: Resolution, rhs: Resolution) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height && lhs.scale == rhs.scale
    }
}

func resArrayFromStrings(_ stringArray: [String]) -> [Resolution] {
    var resArray: [Resolution] = []
    for r in stringArray {
        resArray.append(Resolution(resolutionString: r))
    }
    return resArray
}

// MARK: - Setup/preset classes

/// A structure describing properties of a display.
class DisplayProperties: CustomStringConvertible {
    let screenID: ScreenID
    /// A human-friendly name.
    let name: String
    /// A display symbol, used for visual screen identification. (Emoji welcome)
    let symbol: String
    /// A whitelist of resolutions. If this is not empty, only resolutions named in the list will be displayed to users.
    let resolutionWhitelist: [Resolution]
    /// Allowed refresh rate. Any other refresh rate is silently ignored, unless this is set to 0. WARNING: incorrect setting may destroy your display.
    var allowedRefreshRate: Double = DEFAULT_REFRESH_RATE

    init(screenID: ScreenID, name: String, symbol: String, resolutionWhitelist: [Resolution], allowedRefreshRate: Double = DEFAULT_REFRESH_RATE) {
        self.screenID = screenID
        self.name = name
        self.symbol = symbol
        self.resolutionWhitelist = resolutionWhitelist
        self.allowedRefreshRate = allowedRefreshRate
    }

    var description: String {
        return "Display Properties (\(screenID), \(name), \(symbol), \(resolutionWhitelist), \(allowedRefreshRate) Hz)"
    }
}

/// A display setup, used to specify each display’s desired resolution and mirroring settings.
class DisplaySetup: CustomStringConvertible {
    let mirroring: Bool
    let mirrorOfDisplay: DisplayIdentifierString?
    let resolution: Resolution?

    init(_ setupString: String) throws {
        var parts = setupString.components(separatedBy: " ")
        let mirrordesc = parts.removeFirst()
        if mirrordesc == "self" {
            mirroring = false
            mirrorOfDisplay = nil
            resolution = Resolution(resolutionParts: parts)
        } else if mirrordesc == "mirror" {
            mirroring = true
            mirrorOfDisplay = parts.last! as DisplayIdentifierString
            resolution = nil
        } else {
            throw DisplayManagerError.UnknownMirroringDescription(found: mirrordesc)
        }
    }

    var description: String {
        if mirroring {
            return "mirror \(mirrorOfDisplay!)"
        } else {
            return "self \(resolution!)"
        }
    }
}

/// A display preset — displayed in the menu, consists of a Dock preset, display setups, and extra settings.
class DisplayPreset: CustomStringConvertible {
    var dockPreset: DockPreset
    /// Key that will be part of the keyboard shortcut (with ⌘, case-sensitive)
    var keyEquivalent: String = ""
    /// If true, the
    var allDisplaysPresent: Bool = true
    var displays: [DisplayIdentifierString: DisplaySetup] = [:]

    init(dockPreset: DockPreset, keyEquivalent: String, allDisplaysPresent: Bool, displays: [DisplayIdentifierString: DisplaySetup]) {
        self.dockPreset = dockPreset
        self.keyEquivalent = keyEquivalent
        self.allDisplaysPresent = allDisplaysPresent
        self.displays = displays
    }

    var description: String {
        return "Display Preset (\(dockPreset), \(keyEquivalent), \(allDisplaysPresent), \(displays))"
    }
}

// MARK: - Display

/// A connected display.
class Display: CustomStringConvertible {
    let screenID: ScreenID
    let displayID: CGDirectDisplayID
    let name: String
    /// A display symbol, used for visual screen identification. (Emoji welcome)
    let symbol: String
    /// A whitelist of resolutions. If this is not empty, only resolutions named in the list will be displayed to users.
    let resolutionWhitelist: [Resolution]
    /// Allowed refresh rate. Any other refresh rate is silently ignored, unless this is set to 0. WARNING: incorrect setting may destroy your display.
    var allowedRefreshRate: Double = DEFAULT_REFRESH_RATE
    var available: Bool = false
    /// An array of supported display modes.
    var modes: [CGDisplayMode] = []
    /// A dictionary mapping resolutions to the display modes using said resolution.
    var resolutions: [Resolution: CGDisplayMode] = [:]

    init(screenID: ScreenID, displayID: CGDirectDisplayID, name: String, symbol: String, resolutionWhitelist: [Resolution], allowedRefreshRate: Double = DEFAULT_REFRESH_RATE) {
        self.screenID = screenID
        self.displayID = displayID
        self.name = name
        self.symbol = symbol
        self.resolutionWhitelist = resolutionWhitelist
        self.allowedRefreshRate = allowedRefreshRate
        fetchModes()
    }

    convenience init(properties: DisplayProperties, displayID: CGDirectDisplayID) {
        self.init(screenID: properties.screenID, displayID: displayID, name: properties.name, symbol: properties.symbol, resolutionWhitelist: properties.resolutionWhitelist, allowedRefreshRate: properties.allowedRefreshRate)
    }

    /// Initialize an unknown display. Not fireproof — allowed refresh rate is 60 Hz.
    convenience init(displayID: CGDirectDisplayID) {
        let sid = getScreenID(displayID: displayID)
        self.init(screenID: sid,
                  displayID: displayID,
                  name: sid,
                  symbol: "📺",
                  resolutionWhitelist: [],
                  allowedRefreshRate: DEFAULT_REFRESH_RATE)
    }

    /// Fetch modes and resolutions supported by this screen.
    func fetchModes() {
        modes.removeAll()
        resolutions.removeAll()
        if CGDisplayIsActive(displayID) == 1 {
            available = true
            let settingsDict: CFDictionary = [kCGDisplayShowDuplicateLowResolutionModes as String: kCFBooleanTrue] as CFDictionary

            modes = CGDisplayCopyAllDisplayModes(displayID, settingsDict as CFDictionary)! as! [CGDisplayMode]
            for mode in modes {
                /* Displays claim to support many more modes than they really do:
                 * External display claims it can do 50 Hz, and interlaced mode.
                 * MBP built-in display claims its refresh rate is 0.
                 */
                if (allowedRefreshRate != REFRESH_RATE_IGNORE && mode.refreshRate != allowedRefreshRate) || !mode.isUsableForDesktopGUI() || (mode.ioFlags & UInt32(kDisplayModeInterlacedFlag) != 0) { continue }
                let res = Resolution(width: mode.width, height: mode.height, scale: mode.pixelHeight / mode.height)
                resolutions[res] = mode
            }
        } else {
            available = false
        }
    }

    /**
     Set a screen resolution.

     - parameter config: A display configuration, as created by `beginConfig()`
     - parameter resolution: The resolution to switch to.
     */
    func setResolution(config: inout CGDisplayConfigRef, resolution: Resolution) throws {
        let res = resolutions[resolution]
        if res == nil {
            throw DisplayManagerError.UnknownResolution(resolution: resolution)
        }
        let error = CGConfigureDisplayWithDisplayMode(config, displayID, res!, nil)

        if (error != CGError.success) {
            throw DisplayManagerError.SetResolutionFailed(display: self, resolution:  resolution, mode: res, reason: error)
        }
    }

    /**
     Set a screen’s mirroring mode.

     - parameter config: A display configuration, as created by `beginConfig()`
     - parameter otherDisplayID: The ID of the other display to switch to, or `nil` to disable mirroring.
     */
    func setMirroring(config: inout CGDisplayConfigRef, otherDisplayID: CGDirectDisplayID?) throws {
        let oid = otherDisplayID ?? kCGNullDirectDisplay

        let error = CGConfigureDisplayMirrorOfDisplay(config, displayID, oid)
        if (error != CGError.success) {
            throw DisplayManagerError.SetMirroringFailed(display: self, otherDisplayID: oid, reason: error)
        }
    }

    /**
     Set a screen’s mirroring mode.

     - parameter config: A display configuration, as created by `beginConfig()`
     - parameter otherDisplay: The other display to switch to, or `nil` to disable mirroring.
     */
    func setMirroring(config: inout CGDisplayConfigRef, otherDisplay: Display?) throws {
        try setMirroring(config: &config, otherDisplayID: otherDisplay?.displayID)
    }

    func disableMirroringIfNeeded(config: inout CGDisplayConfigRef) throws {
        if CGDisplayIsInMirrorSet(displayID) == 1 {
            try setMirroring(config: &config, otherDisplay: nil)
        }
    }

    /// The current display mode.
    var mode: CGDisplayMode? {
        return CGDisplayCopyDisplayMode(displayID)
    }

    var description: String {
        return "Display (\(screenID), \(displayID), \(name), \(symbol), \(resolutionWhitelist), \(available))"
    }
}

// MARK: - Display manager and preset handlers

/// A display manager. Handles storing settings and performing configuration.
class DisplayManager {
    var dockPresets: [String: DockPreset] = [:]
    var displayProperties: [ScreenID: DisplayProperties] = [:]
    var presets: [String: DisplayPreset] = [:]

    var displays: [Display] = []
    var displaysByScreenID: [ScreenID: Display] = [:]

    init(dockPresets: [String: DockPreset], displayProperties: [ScreenID: DisplayProperties], presets: [String: DisplayPreset]) {
        self.dockPresets = dockPresets
        self.displayProperties = displayProperties
        self.presets = presets
        findDisplays()
    }

    convenience init(jsonDict: [String: Any]) throws {
        var dockp: [String: DockPreset] = [:]
        var displayp: [ScreenID: DisplayProperties] = [:]
        var allp: [String: DisplayPreset] = [:]
        let dockPresetsDict = jsonDict["dockPresets"] as! [String: [String: Any]]
        for (name, preset) in dockPresetsDict {
            dockp[name] = try DockPreset(
                name: name,
                position: preset["position"] as! String,
                tilesize: preset["tilesize"] as! Int
            )
        }

        let displayPropertiesDict = jsonDict["displayProperties"] as! [ScreenID: [String: Any]]
        for (screenID, prop) in displayPropertiesDict {
            displayp[screenID] = DisplayProperties(
                screenID: screenID,
                name: prop["name"] as! String,
                symbol: prop["symbol"] as! String,
                resolutionWhitelist: resArrayFromStrings(prop["resolutionWhitelist"] as! [String]),
                allowedRefreshRate: prop["allowedRefreshRate"] as? Double ?? DEFAULT_REFRESH_RATE
            )
        }

        let presetsDict = jsonDict["presets"] as! [String: [String: Any]]
        for (name, preset) in presetsDict {
            var displaySetups: [DisplayIdentifierString: DisplaySetup] = [:]
            for (identifierString, setupString) in preset["displays"] as! [DisplayIdentifierString: String] {
                displaySetups[identifierString] = try DisplaySetup(setupString)
            }
            allp[name] = DisplayPreset(
                dockPreset: dockp[preset["dockPreset"] as! String]!,
                keyEquivalent: preset["keyEquivalent"] as? String ?? "",
                allDisplaysPresent: preset["allDisplaysPresent"] as? Bool ?? false,
                displays: displaySetups
            )
        }

        self.init(dockPresets: dockp, displayProperties: displayp, presets: allp)
    }

    convenience init(jsonPath: URL) throws {
        let jsonText = try Data(contentsOf: jsonPath, options: .alwaysMapped)
        try self.init(jsonDict: try JSONSerialization.jsonObject(with: jsonText, options: []) as! [String: Any])
    }

    /// Find displays attached to the system.
    func findDisplays() {
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)

        displays.removeAll()
        for currentDid in onlineDisplays[0..<Int(displayCount)] {
            let currentSid = getScreenID(displayID: currentDid)
            let dprop = displayProperties[currentSid]
            if dprop != nil {
                let display = Display(properties: dprop!, displayID: currentDid)
                displays.append(display)
            } else {
                let display = Display(displayID: currentDid)
                displays.append(display)
            }
        }

        displaysByScreenID.removeAll()
        for d in displays {
            displaysByScreenID[d.screenID] = d
        }
    }

    /// Find display by an identifier string (ScreenID, name, symbol).
    func findDisplay(identifierString: DisplayIdentifierString) -> Display? {
        var display: Display?
        // First, search for the display in displaysByScreenID
        display = displaysByScreenID[identifierString]
        if display != nil { return display }
        // Then, search by name or symbol
        for d in displays {
            if d.name == identifierString || d.symbol == identifierString { return d }
        }
        return nil
    }

    func applyPreset(_ preset: DisplayPreset) throws {
        // Changing resolutions works only if mirroring is disabled everywhere.

        // MARK: Identify affected displays
        findDisplays()
        var missingDisplay: DisplayIdentifierString? = nil

        for (identifierString, setup) in preset.displays {
            let dt1 = findDisplay(identifierString: identifierString)
            if dt1 == nil { missingDisplay = identifierString }
            if setup.mirroring {
                let dt2 = findDisplay(identifierString: setup.mirrorOfDisplay!)
                if dt2 == nil { missingDisplay = identifierString }
            }
        }

        if missingDisplay != nil && preset.allDisplaysPresent {
            throw DisplayManagerError.DisplayNotFound(identifierString: missingDisplay!, preset: preset)
        }

        // Do our own fade to avoid flickering 3 times
        var fadeToken = try reserveFade(5)
        CGDisplayFade(fadeToken, 0.3, CGDisplayBlendFraction(kCGDisplayBlendNormal), CGDisplayBlendFraction(kCGDisplayBlendSolidColor), 0.0, 0.0, 0.0, 1)

        // MARK: Pass 1: disable mirroring everywhere
        var config = try beginConfig()

        for (identifierString, _) in preset.displays {
            let display = findDisplay(identifierString: identifierString)
            if display == nil { continue }
            do {
                try display!.disableMirroringIfNeeded(config: &config)
            } catch let e {
                try cancelConfig(&config)
                try endFadeAndRelease(&fadeToken)
                throw e
            }
        }

        try completeConfig(&config)

        // MARK: Pass 2: change resolution settings
        config = try beginConfig()

        for (identifierString, setup) in preset.displays {
            let display = findDisplay(identifierString: identifierString)
            if setup.mirroring || display == nil { continue }
            display?.fetchModes()
            do {
                try display!.setResolution(config: &config, resolution: setup.resolution!)
            } catch let e {
                try cancelConfig(&config)
                try endFadeAndRelease(&fadeToken)
                throw e
            }
        }
        try completeConfig(&config)

        // MARK: Pass 3: change mirroring settings
        config = try beginConfig()
        for (identifierString, setup) in preset.displays {
            let display = findDisplay(identifierString: identifierString)
            if !setup.mirroring || display == nil { continue }
            let otherDisplay = findDisplay(identifierString: setup.mirrorOfDisplay!)
            do {
                try display!.setMirroring(config: &config, otherDisplay: otherDisplay)
            } catch let e {
                try cancelConfig(&config)
                try endFadeAndRelease(&fadeToken)
                throw e
            }
        }

        try completeConfig(&config)

        // MARK: Handle dock config and unfade
        preset.dockPreset.apply()
        try endFadeAndRelease(&fadeToken)
    }

    // MARK: internal functions

    /**
     Begin display configuration.

     - returns: a display configuration reference.
    */
    fileprivate func beginConfig() throws -> CGDisplayConfigRef {
        var config: CGDisplayConfigRef? = nil
        let error = CGBeginDisplayConfiguration(&config)
        if (error != CGError.success) {
            throw DisplayManagerError.BeginConfigFailed(reason: error)
        }
        return config!
    }

    /**
     Complete display configuration.

     - parameter config: A display configuration, as acquired from `beginConfig()`.
    */
    fileprivate func completeConfig(_ config: inout CGDisplayConfigRef) throws {
        let error = CGCompleteDisplayConfiguration(config, .forSession)
        if (error != CGError.success) {
            throw DisplayManagerError.CompleteConfigFailed(reason: error)
        }
    }

    /**
     Cancel display configuration.

     - parameter config: A display configuration, as acquired from `beginConfig()`.
     */
    fileprivate func cancelConfig(_ config: inout CGDisplayConfigRef) throws {
        let error = CGCancelDisplayConfiguration(config)
        if (error != CGError.success) {
            throw DisplayManagerError.CancelConfigFailed(reason: error)
        }
    }

    /**
     Reserve a fade operation.

     - parameter seconds: seconds to reserve the fade operation for
    */
    fileprivate func reserveFade(_ seconds: CGDisplayReservationInterval) throws -> CGDisplayFadeReservationToken {
        var token: CGDisplayFadeReservationToken = 0
        let error = CGAcquireDisplayFadeReservation(seconds, &token)
        if (error != CGError.success) {
            throw DisplayManagerError.FadeReservationFailed(reason: error)
        }
        return token
    }

    fileprivate func releaseFade(_ token: inout CGDisplayFadeReservationToken) throws {
        let error = CGReleaseDisplayFadeReservation(token)
        if (error != CGError.success) {
            throw DisplayManagerError.FadeReleaseFailed(reason: error)
        }
    }

    fileprivate func endFadeAndRelease(_ token: inout CGDisplayFadeReservationToken) throws {
        CGDisplayFade(token, 0.5, CGDisplayBlendFraction(kCGDisplayBlendSolidColor), CGDisplayBlendFraction(kCGDisplayBlendNormal), 0.0, 0.0, 0.0, 1)
        try releaseFade(&token)
    }
}

// MARK: - Error type definitions


enum DisplayManagerError: Error {
    case UnknownDockPosition
    case UnevenScaling
    case UnknownMirroringDescription(found: String)
    case UnknownResolution(resolution: Resolution)
    case BeginConfigFailed(reason: CGError)
    case SetResolutionFailed(display: Display, resolution: Resolution, mode: CGDisplayMode?, reason: CGError)
    case SetMirroringFailed(display: Display, otherDisplayID: CGDirectDisplayID, reason: CGError)
    case CancelConfigFailed(reason: CGError)
    case CompleteConfigFailed(reason: CGError)
    case FadeReservationFailed(reason: CGError)
    case FadeReleaseFailed(reason: CGError)
    case DisplayNotFound(identifierString: DisplayIdentifierString, preset: DisplayPreset)
}
