//
//  Copyright © 2020 Rosberry. All rights reserved.
//

import Foundation

public enum PathDispatcher {
    public static let srcRoot: String = "$(SRCROOT)/"
    public static let projectExtension: String = "xcodeproj"
    public static let carthageScriptPath: String = "/usr/local/bin/carthage"
    public static let defaultFrameworksDirectory: String = "Carthage"
    public static let defaultProjectDirectoryPath: String = ProcessInfo.processInfo.environment["PROJECT_DIR", default: ""]
    public static let listsFolderName: String = "xcfilelists"

    public static func iOSFrameworksDirectory(name: String) -> String {
        "\(name)/Build/iOS"
    }
}
