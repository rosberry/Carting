//
//  Copyright © 2020 Artem Novichkov. All rights reserved.
//

import Foundation
import CartingCore
import ArgumentParser

struct Update: ParsableCommand {

    static let configuration: CommandConfiguration = .init(abstract: "Adds a new script with input/output file paths or updates the script named `Carthage`.")

    @OptionGroup()
    var options: Options

    @Flag(name: [.customLong("append to file"), .short], help: "Should output be appended to previous output")
    var isAppendingToFile: Bool = false

    func run() throws {
        let projectService = ProjectService(projectDirectoryPath: options.path)
        try projectService.updateScript(withName: options.script,
                                        format: options.format,
                                        targetName: options.target,
                                        projectNames: options.projectNames,
                                        frameworksDirectoryPath: options.frameworksDirectoryPath,
                                        shouldAppend: isAppendingToFile)
    }
}
