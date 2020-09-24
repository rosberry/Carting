//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

enum PathType: Hashable {
    case input(frameworksDirectoryName: String), output

    var prefix: String {
        switch self {
        case let .input(frameworksDirectoryName):
            return PathDispatcher.iOSFrameworksDirectory(name: "\(PathDispatcher.srcRoot)\(frameworksDirectoryName)") + "/"
        case .output:
            return "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/"
        }
    }
}
