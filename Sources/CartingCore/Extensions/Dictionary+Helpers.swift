//
//

import Foundation

extension Dictionary {
    @inlinable public func mapKeys<T: Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
        [T: Value](uniqueKeysWithValues: try map { key, value -> (T, Value) in
            (try transform(key), value)
        })
    }
}
