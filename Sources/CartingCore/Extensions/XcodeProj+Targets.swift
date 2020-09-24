//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

import XcodeProj

extension XcodeProj {

    func targets(with type: PBXProductType, name: String) -> [PBXNativeTarget] {
        pbxproj.nativeTargets
            .filter { target in
                guard target.productType == type else {
                    return false
                }
                if !name.isEmpty {
                    return target.name.lowercased() == name.lowercased()
                }
                return true
            }
    }
}
