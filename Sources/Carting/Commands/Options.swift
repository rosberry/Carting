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
    var path: String = PathDispatcher.defaultProjectDirectoryPath

    @Option(name: [.short, .long], help: "Format of input/output file paths: file - using simple paths, list - using xcfilelists")
    var format: Format = .list

    @Option(name: [.short, .long], help: "The project target name.")
    var target: String = ProcessInfo.processInfo.environment["TARGET_NAME", default: ""]

    @Option(help: "The names of projects. If specified, only first (or default) frameworksDirectoryName will be proceed")
    var projectNames: [String] = []

    @Argument(help: "The project directories that contains frameworks to proceed")
    var frameworksDirectoryNames: [String] = [PathDispatcher.defaultFrameworksDirectory]
}
