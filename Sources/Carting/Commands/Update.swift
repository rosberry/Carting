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

    func run() throws {
        let projectService = ProjectService(projectDirectoryPath: options.path)
        if !options.projectNames.isEmpty,
           let frameworksDirectoryName = options.frameworksDirectoryNames.first {
            try projectService.updateScript(withName: options.script,
                                            format: options.format,
                                            targetName: options.target,
                                            projectNames: options.projectNames,
                                            frameworksDirectoryName: frameworksDirectoryName)
        }
        else {
            try projectService.updateScript(withName: options.script,
                                            format: options.format,
                                            targetName: options.target,
                                            frameworksDirectoryNames: options.frameworksDirectoryNames)
        }
    }
}
