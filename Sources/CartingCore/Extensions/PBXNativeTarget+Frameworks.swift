//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

import XcodeProj

extension PBXNativeTarget {

    func linkedFrameworks(for context: (PathType, [Framework])) -> [String] {
        guard let frameworksBuildPhase = try? frameworksBuildPhase() else {
            return []
        }
        let (type, frameworks) = context
        return frameworks.compactMap { framework in
            let name = framework.name
            guard let files = frameworksBuildPhase.files,
                  files.contains(with: name, at: \.file?.name) else {
                return nil
            }
            return type.prefix + name
        }
    }

    func paths(for frameworks: [Framework], type: PathType) -> [String] {
        paths(for: [type: frameworks])
    }

    func paths(for frameworks: [PathType: [Framework]]) -> [String] {
        frameworks.reduce([]) { result, value in
            result + linkedFrameworks(for: value)
        }
    }
}
