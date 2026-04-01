/* @source cursor @line_count 12 @branch main */
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

NSApp.run()
