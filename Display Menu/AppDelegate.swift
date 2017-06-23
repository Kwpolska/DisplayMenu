/*
 * Display Menu
 * Copyright © 2017, Chris Warrick.
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

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var displayManager: DisplayManager? = nil
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    let statusMenu = NSMenu()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        do {
            try acquireDisplayManager()
        } catch let error {
            alertAndQuit("Failed to initialize display manager.", String(reflecting: error))
        }

        statusMenu.delegate = self

        statusItem.image = #imageLiteral(resourceName: "DMStatusReady")
        statusItem.menu = statusMenu
    }

    func acquireDisplayManager() throws {
        let appsupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let appdir = appsupport.appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        try FileManager.default.createDirectory(at: appdir, withIntermediateDirectories: true, attributes: nil)
        let url = appdir.appendingPathComponent("DisplayMenu.json")
        if FileManager.default.fileExists(atPath: url.path) {
            displayManager = try DisplayManager(jsonPath: url)
        } else {
            alertAndQuit("Settings file not found", "Place a settings file at \(url.path) and try again.")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func _resetDMIcon() {
        self.statusItem.image = #imageLiteral(resourceName: "DMStatusReady")
    }

    func applyPresetFromMenu(_ sender: NSMenuItem?) {
        self.statusItem.image = #imageLiteral(resourceName: "DMStatusWorking")
        do {
            try displayManager!.applyPreset(sender!.representedObject as! DisplayPreset)
            self.statusItem.image = #imageLiteral(resourceName: "DMStatusSuccess")
        } catch let error {
            self.statusItem.image = #imageLiteral(resourceName: "DMStatusError")
            alert("Failed to apply preset", String(reflecting: error), alertStyle: .critical)
        }
        Timer.scheduledTimer(timeInterval: TimeInterval(1.5), target: self, selector: #selector(_resetDMIcon), userInfo: nil, repeats: false)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        for (name, preset) in displayManager!.presets {
            let item = NSMenuItem(title: name, action: #selector(applyPresetFromMenu), keyEquivalent: preset.keyEquivalent)
            item.representedObject = preset
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q")
    }
}

public func alert(_ messageText: String, _ informativeText: String? = nil, alertStyle: NSAlertStyle = NSAlertStyle.informational) {
    let alert = NSAlert()
    alert.messageText = messageText
    if informativeText != nil {
        alert.informativeText = informativeText!
    }
    alert.alertStyle = alertStyle
    alert.runModal()
}

public func alertAndQuit(_ messageText: String, _ informativeText: String? = nil) {
    var informative = "The application will now quit."
    if informativeText != nil {
        informative = informativeText! + " The application will now quit."
    }
    alert(messageText, informative, alertStyle: NSAlertStyle.critical)
    NSApp.terminate(nil)
}
