//
//  Copyright © 2020 Artem Novichkov. All rights reserved.
//

import Foundation
import CartingCore
import ArgumentParser

struct Info: ParsableCommand {

    static let configuration: CommandConfiguration = .init(abstract: "Prints Carthage frameworks list with linking description.")

    @Option(name: [.short, .long], help: "The project directory path.")
    var path: String = ProcessInfo.processInfo.environment["PROJECT_DIR", default: ""]

    @Option(name: [.short, .long], help: "The project directories that contains frameworks to proceed")
    var frameworksDirectoryPath: String = "Carthage"

    func run() throws {
        let projectService = ProjectService(projectDirectoryPath: path)
        try projectService.printFrameworksInformation(frameworksDirectoryPath: frameworksDirectoryPath)
    }
}
