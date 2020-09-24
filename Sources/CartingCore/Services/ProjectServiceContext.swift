//
//

import Foundation

extension ProjectService {
    public struct Context {
        public init(scriptName: String,
                    projectPath: String,
                    format: Format,
                    target: String,
                    projectNames: [String],
                    frameworksDirectoryNames: [String]) {
            self.scriptName = scriptName
            self.projectPath = projectPath
            self.format = format
            self.target = target
            self.projectNames = projectNames
            self.frameworksDirectoryNames = frameworksDirectoryNames
        }

        let scriptName: String
        let projectPath: String
        let format: Format
        let target: String
        let projectNames: [String]
        let frameworksDirectoryNames: [String]
    }
}

