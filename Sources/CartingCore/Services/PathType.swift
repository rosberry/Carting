//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

enum PathType: Hashable {
    case input(frameworksDirectoryPath: String), output

    var prefix: String {
        switch self {
        case let .input(frameworksDirectoryPath):
            return "$(SRCROOT)/\(frameworksDirectoryPath)/Build/iOS/"
        case .output:
            return "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/"
        }
    }
}
