// Lidiculous
// Copyright © 2025 @ciutadellla. All rights reserved.

import AppKit

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}
