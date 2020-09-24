//
//  Copyright © 2020 Artem Novichkov. All rights reserved.
//

import Foundation
import CartingCore
import ArgumentParser

struct Info: ParsableCommand {

    static let configuration: CommandConfiguration = .init(abstract: "Prints Carthage frameworks list with linking description.")

    @Option(name: [.short, .long], help: "The project directory path.")
    var path: String = PathDispatcher.defaultProjectDirectoryPath

    @Argument(help: "The project directory that contains frameworks to proceed")
    var frameworksDirectoryName: String = PathDispatcher.defaultFrameworksDirectory

    func run() throws {
        let projectService = ProjectService(projectDirectoryPath: path)
        try projectService.printFrameworksInformation(frameworksDirectoryName: frameworksDirectoryName)
    }
}
