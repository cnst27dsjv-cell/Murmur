import AppKit
import Foundation

final class AppStore {
    private let fileManager = FileManager.default

    private var supportDirectory: URL {
        if let devPath = ProcessInfo.processInfo.environment["MURMUR_DEV_DATA_DIR"], !devPath.isEmpty {
            return URL(fileURLWithPath: devPath, isDirectory: true)
        }

        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Murmur", isDirectory: true)
    }

    private var stateURL: URL {
        supportDirectory.appendingPathComponent("state.json")
    }

    func load() -> MurmurState {
        do {
            let data = try Data(contentsOf: stateURL)
            return try JSONDecoder.murmur.decode(MurmurState.self, from: data)
        } catch {
            let state = MurmurState.defaultValue
            NSLog("Murmur using state path: \(stateURL.path)")
            save(state)
            return state
        }
    }

    func save(_ state: MurmurState) {
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.murmur.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            NSLog("Murmur failed to save state: \(error.localizedDescription)")
        }
    }
}

extension JSONDecoder {
    static var murmur: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var murmur: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
