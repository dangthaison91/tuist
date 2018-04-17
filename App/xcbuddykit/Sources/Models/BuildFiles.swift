import Foundation
import PathKit
import Unbox

// MARK: - BuildFiles

enum BuildFiles {
    case include([Path])
    case exclude([Path])
}

// MARK: - BuildFiles (Equatable)

extension BuildFiles: Equatable {
    static func == (lhs: BuildFiles, rhs: BuildFiles) -> Bool {
        switch (lhs, rhs) {
        case let (.include(lhsPath), .include(rhsPath)):
            return lhsPath == rhsPath
        case let (.exclude(lhsPath), .exclude(rhsPath)):
            return lhsPath == rhsPath
        default:
            return false
        }
    }
}

// MARK: - BuildFiles (Unboxable)

extension BuildFiles: Unboxable {
    init(unboxer: Unboxer) throws {
        let type: String = try unboxer.unbox(key: "type")
        let paths: [Path] = try unboxer.unbox(key: "paths")
        try paths.forEach({ try $0.assertRelative() })
        if type == "include" {
            self = .include(paths)
        } else if type == "exclude" {
            self = .exclude(paths)
        } else {
            let message = "Buildfile type \(type) not supported"
            throw GraphLoadingError.unexpected(message)
        }
    }
}

// MARK: - Array (BuildFiles)

extension Array where Element == BuildFiles {
    func list(context: GraphLoaderContexting) -> Set<Path> {
        let reduced = reduce(into: (included: Array<Path>(), excluded: Array<Path>()), { prev, buildFiles in
            switch buildFiles {
            case let .include(paths):
                let absolutePaths = paths.flatMap { context.fileHandler.glob(context.projectPath, glob: $0.string) }
                prev.included.append(contentsOf: absolutePaths)
            case let .exclude(paths):
                let absolutePaths = paths.flatMap { context.fileHandler.glob(context.projectPath, glob: $0.string) }
                prev.excluded.append(contentsOf: absolutePaths)
            }
        })
        let included = Set(reduced.included)
        let excluded = Set(reduced.excluded)
        return included.subtracting(excluded)
    }
}