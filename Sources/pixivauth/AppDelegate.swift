//
//  AppDelegate.swift
//  pixivauth
//
//  Created by Fabio Mauersberger on 28.05.22.
//

import AppKit

//@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600), styleMask: [.titled, .closable, .resizable], backing: NSWindow.BackingStoreType.buffered, defer: false)
        window.orderFrontRegardless()
        window.title = "pixivauth"
        window.contentViewController = ViewController()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

}
