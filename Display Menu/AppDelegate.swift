/*
 * Display Menu
 * Copyright © 2017-2019, Chris Warrick.
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
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let statusMenu = NSMenu()
    let refreshItem = NSMenuItem(title: NSLocalizedString("Reload", comment: "Reload menu item"), action: #selector(acquireDisplayManager), keyEquivalent: "r")
    let openConfigItem = NSMenuItem(title: NSLocalizedString("Open Config File", comment: "Open Config File menu item"), action: #selector(openConfigFile), keyEquivalent: ",")
    let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: "Quit menu item"), action: #selector(NSApp.terminate), keyEquivalent: "q")
    let dockPresetsItem = NSMenuItem(title: NSLocalizedString("Dock Presets", comment: "Dock Presets menu item"), action: nil, keyEquivalent: "")
    var settingsURL: URL? = nil
    override init() {
        super.init()

        refreshItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.control
        statusMenu.delegate = self

        statusItem.button?.image = #imageLiteral(resourceName: "DMStatusReady")
        statusItem.menu = statusMenu
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        do {
            try acquireDisplayManager()
        } catch let error {
            alertAndQuit(NSLocalizedString("Failed to initialize display manager.", comment: "Alert title (display manager/config error)"), String(reflecting: error))
        }

    }

    @objc func acquireDisplayManager() throws {
        let appsupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let appdir = appsupport.appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        try FileManager.default.createDirectory(at: appdir, withIntermediateDirectories: true, attributes: nil)
        settingsURL = appdir.appendingPathComponent("DisplayMenu.json")
        if FileManager.default.fileExists(atPath: settingsURL!.path) {
            displayManager = try DisplayManager(jsonPath: settingsURL!)
        } else {
            alertAndQuit(
                NSLocalizedString("Settings file not found", comment: "no settings alert title"),
                String.localizedStringWithFormat(NSLocalizedString("Place a settings file at %@ and try again.", comment: "no settings alert description"), settingsURL!.path)
            )
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @objc func _resetDMIcon() {
        self.statusItem.button?.image = #imageLiteral(resourceName: "DMStatusReady")
    }

    @objc func applyPresetFromMenu(_ sender: NSMenuItem?) {
        self.statusItem.button?.image = #imageLiteral(resourceName: "DMStatusWorking")
        do {
            try displayManager!.applyPreset(sender!.representedObject as! DisplayPreset)
            self.statusItem.button?.image = #imageLiteral(resourceName: "DMStatusSuccess")
        } catch let error {
            self.statusItem.button?.image = #imageLiteral(resourceName: "DMStatusError")
            alert(NSLocalizedString("Failed to apply preset", comment: "alert when applyPreset fails"), String(reflecting: error), alertStyle: .critical)
        }
        Timer.scheduledTimer(timeInterval: TimeInterval(1.5), target: self, selector: #selector(_resetDMIcon), userInfo: nil, repeats: false)
    }

    @objc func applyDockPresetFromMenu(_ sender: NSMenuItem?) {
        let dp = sender!.representedObject as! DockPreset
        dp.apply(force: true)
    }
    
    @objc func openConfigFile(_ sender: NSMenuItem?) {
        NSWorkspace.shared.openFile(settingsURL!.path, withApplication: "TextEdit")
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        for preset in displayManager!.presetOrder {
            let item = NSMenuItem(title: preset.name, action: #selector(applyPresetFromMenu), keyEquivalent: preset.keyEquivalent)
            item.representedObject = preset
            menu.addItem(item)
        }

        let dpsubmenu = NSMenu()
        for (name, dp) in displayManager!.dockPresets {
            let item = NSMenuItem(title: name, action: #selector(applyDockPresetFromMenu), keyEquivalent: "")
            item.representedObject = dp
            dpsubmenu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(dockPresetsItem)
        dockPresetsItem.submenu = dpsubmenu
        menu.addItem(refreshItem)
        menu.addItem(openConfigItem)
        menu.addItem(quitItem)
    }
}

public func alert(_ messageText: String, _ informativeText: String? = nil, alertStyle: NSAlert.Style = NSAlert.Style.informational) {
    let alert = NSAlert()
    alert.messageText = messageText
    if informativeText != nil {
        alert.informativeText = informativeText!
    }
    alert.alertStyle = alertStyle
    alert.runModal()
}

public func alertAndQuit(_ messageText: String, _ informativeText: String? = nil) {
    var informative = NSLocalizedString("The application will now quit.", comment: "fatal error alert (without informative text)")
    if informativeText != nil {
        informative = String.localizedStringWithFormat(NSLocalizedString("%@ The application will now quit.", comment: "fatal error alert (argument is informative text)"), informativeText!)
    }
    alert(messageText, informative, alertStyle: NSAlert.Style.critical)
    NSApp.terminate(nil)
}
