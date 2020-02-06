import Foundation

fileprivate let codingUserInfoKey = "codedTypeName"

public protocol StickyPromise {
    func after(_ completion: () -> Void)
}

public extension StickyPromise {
    func after(_ completion: () -> Void) {
        completion()
    }
}

public protocol Stickable: Codable, StickyPromise {}

public protocol StickyKey {
    associatedtype Key: Equatable
    var key: Key { get }
}

public typealias StickyComparable = Stickable & Equatable
public typealias StickyKeyable = StickyComparable & StickyKey
public typealias StickyDataSet<T: StickyComparable> = [T]

public extension CodingUserInfoKey {
    static let codedTypeKey = CodingUserInfoKey(rawValue: codingUserInfoKey)!
}

public extension Decoder {
    var codedTypeName: String {
        return userInfo[CodingUserInfoKey.codedTypeKey] as? String ?? ""
    }
}
