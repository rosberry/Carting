//
//  Copyright © 2020 Artem Novichkov. All rights reserved.
//

import Foundation
import CartingCore
import ArgumentParser

struct Options: ParsableArguments {

    @Option(name: [.short, .long], help: "The name of Carthage script.")
    var script: String = "Carthage"

    @Option(name: [.short, .long], help: "The project directory path.")
    var path: String = ProcessInfo.processInfo.environment["PROJECT_DIR", default: ""]

    @Option(name: [.short, .long], help: "The project directories that contains frameworks to proceed")
    var frameworksDirectoryPath: String = "Carthage"

    @Option(name: [.short, .long], help: "Format of input/output file paths: file - using simple paths, list - using xcfilelists")
    var format: Format = .list

    @Option(name: [.short, .long], help: "The project target name.")
    var target: String = ProcessInfo.processInfo.environment["TARGET_NAME", default: ""]

    @Argument(help: "The names of projects.")
    var projectNames: [String]
}
