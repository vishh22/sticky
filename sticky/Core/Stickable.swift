import Foundation

fileprivate let stickyDataDumpLogQueue = "queue.sticky.log"

public extension Stickable {
    static func read() -> [Self]? {
        if let data = cache.stored[entityName], !data.isEmpty {
            stickyLog("Read from cache")
            return data as? [Self]
        } else {
            return Self.decode(from: fileData)
        }
    }

    static func readAsync(completion: @escaping ([Self]?) -> Void) {
        DispatchQueue.main.async {
            completion(Self.decode(from: fileData))
        }
    }

    static func dumpDataStoreToLog() {
        if Sticky.shared.configuration.logStyle == .verbose {
            if Sticky.shared.configuration.async {
                let queue = DispatchQueue(label: stickyDataDumpLogQueue, qos: .background)
                queue.async {
                    guard let data = fileData else { return }
                    stickyLog("\(entityName): \(String(bytes: data, encoding: .utf8) ?? "")")
                }
            } else {
                stickyLog(debugDescription)
            }
        } else {
            stickyLog("\(entityName).\(#function) - Please enable logging in StickyConfiguration to see stored data")
        }
    }

    static var entityName: String {
        return String(describing: Self.self)
    }

    static var notificationName: NSNotification.Name {
        return NSNotification.Name(entityName)
    }

    private static var debugDescription: String {
        guard let data = fileData else { return "" }
        return "\(entityName): \(String(bytes: data, encoding: .utf8) ?? "")"
    }

    private static func decode(from data: Data?) -> [Self]? {
        var decoded: [Self]?
        guard let jsonData = data, !jsonData.isEmpty else { return nil }

        do {
            let decoder = JSONDecoder()
            decoder.userInfo = [CodingUserInfoKey.codedTypeKey: entityName]
            decoded = try decoder.decode([Self].self, from: jsonData)
        } catch {
            var errorMessage = "ERROR: \(entityName).\(#function) \(error.localizedDescription) "
            errorMessage += handleDecodeError(error) ?? ""
            errorMessage += debugDescription
            stickyLog(errorMessage, logAction: .error)
        }

        // Write to cache if data is returned and cache is empty
        if let decoded = decoded, cache.stored.isEmpty {
            cache.stored.updateValue(decoded, forKey: entityName)
        }

        return decoded
    }

    private static var fileData: Data? {
        return FileHandler.read(from: filePath)
    }

    static var filePath: String {
        return FileHandler.url(for: Self.entityName).path
    }

    private static func handleDecodeError(_ error: Error) -> String? {
        guard let decodeError = error as? DecodingError else { return nil }
        switch decodeError {
        case let .keyNotFound(_, context): return context.debugDescription
        case let .dataCorrupted(context): return context.debugDescription
        case let .typeMismatch(_, context): return context.debugDescription
        case let .valueNotFound(_, context): return context.debugDescription
        @unknown default:
            return ""
        }
    }
}

public extension Stickable where Self: Equatable & StickyPromise {
    // Public API
    ///
    /// Checks to see if data object is stored locally.
    ///
    var isStored: Bool {
        if let _ = Self.read()?.firstIndex(of: self) {
            return true
        }
        return false
    }

    ///
    /// If data object conforms to Equatable, this method will
    /// scan the local store and find the first value that matches
    /// the Equatable (==) definition.
    ///
    /// This method will always insert a new data object unless
    /// data is completely unchanged, then it will do nothing.
    ///
    /// Use this if data object doesn't need to update and storage space
    /// and performance are less concerning. More suited for transactional data.
    ///
    func stick() {
        stickyLog("\(Self.entityName) saving without key")
        save()
    }

    func unstick() {
        delete()
    }

    // Implementation

    fileprivate func delete() {
        let dataSet = Self.read()
        stickyLog("\(Self.entityName) removing data \(self)")
        let index = dataSet?.firstIndex(of: self)
        Store.remove(value: self, from: dataSet, at: index)
    }

    fileprivate func save() {
        let dataSet = Self.read()
        let index = dataSet?.firstIndex(of: self)
        let stickyAction = Store.stickyAction(from: dataSet, with: self, at: index)
        Store.save(with: stickyAction)
    }
}

// MARK: - Stickable - Equatable & StickyKey

public extension Stickable where Self: Equatable & StickyKey & StickyPromise {
    // Public API
    ///
    /// When data object conforms to StickyKey, this method will seek
    /// the unique stored data element that matches the key and either:
    ///   1. Update the non-key values if needed
    ///   2. Store the new object
    ///   3. Do nothing if data is unchanged.
    ///
    /// Use this method if you have data objects with one or two
    /// properties that ensure uniqueness and need to update values frequently.
    ///
    @discardableResult func stickWithKey() -> StickyPromise {
        let dataSet = Self.read()
        stickyLog("\(Self.entityName) saving with key")
        let index = dataSet?
            .map({ $0.key })
            .firstIndex(of: key)
        let stickyAction = Store.stickyAction(from: dataSet, with: self, at: index)
        Store.save(with: stickyAction)
        return self as StickyPromise
    }

    func unstick() {
        let dataSet = Self.read()
        stickyLog("\(Self.entityName) removing data \(self)")
        let index = dataSet?
            .map({ $0.key })
            .firstIndex(of: key)
        Store.remove(value: self, from: dataSet, at: index)
    }
}
