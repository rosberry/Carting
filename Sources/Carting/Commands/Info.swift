//
//  Copyright © 2020 Artem Novichkov. All rights reserved.
//

import Foundation
import CartingCore
import ArgumentParser

struct Info: ParsableCommand {

    static let configuration: CommandConfiguration = .init(abstract: "Prints Carthage frameworks list with linking description.")

    @Option(name: [.short, .long], default: ProcessInfo.processInfo.environment["PROJECT_DIR"], help: "The project directory path.")
    var path: String?

    @Option(name: [.short, .long], default: "Carthage", help: "The project directories that contains frameworks to proceed")
    var frameworksDirectoryPath: String

    func run() throws {
        let projectService = ProjectService(projectDirectoryPath: path)
        try projectService.printFrameworksInformation(frameworksDirectoryPath: frameworksDirectoryPath)
    }
}
