import Foundation
import JSONKit
import Files

extension StepIO {
    static let passthrough: StepIO =
        .named(
            NamedStepIO (
                name: UUID().uuidString + "lastStepOutput" + UUID().uuidString
            )
        )
}

class ProcessorStorage {
    private var managedData = [String:[JSONNode]]()
    private var dataToSave = [String:JSONNode]()
    
    let baseFolder: Folder
    init(baseFolder: Folder) {
        self.baseFolder = baseFolder
    }
    
    func flushWriteable() throws -> [(File, JSONNode)] {
        try dataToSave.map { (key, json) -> (File, JSONNode) in
            let file = try baseFolder.file(at: key)
            return (file, json)
        }
    }
    
    func load(_ stepParams: StepIO?) throws -> [JSONNode] {
        let stepParams = stepParams ?? .passthrough
        switch stepParams {
        case .folder(let folderParams):
            let folder = try baseFolder.subfolder(at: folderParams.folder)
            var files = folder.files.map{$0}
            if let filterRegex = folderParams.filter {
                files = files.filter {
                    $0.name.range(of: filterRegex, options: .regularExpression) != nil
                }
            }
            return try files.map {
                try $0.readJSON()
            }
        case .file(let fileParams):
            let file = try baseFolder.file(at: fileParams.file)
            return [try file.readJSON()]
        case .named(let namedParams):
            if let jsonContent = managedData[namedParams.name] {
                return jsonContent
            } else {
                throw ProcessorStorageError.stepIsMissingInput
            }
        case .multiple(let array):
            return try array.flatMap {
                try load($0)
            }
        }
    }
    
    func clearNamed(_ name: String) {
        managedData[name] = nil
    }
    
    func save(_ stepParams: StepIO?, jsonContent: [JSONNode]) throws {
        let stepParams = stepParams ?? .passthrough
        switch stepParams {
        case .file(let fileParams):
            if jsonContent.count == 1, let json = jsonContent.first {
                dataToSave[fileParams.file] = json
            } else {
                fatalError()
            }
        case .named(let namedParams):
            managedData[namedParams.name] = jsonContent
        case .multiple:
            // TODO: Implement saving to multiple files per step
            throw ProcessorStorageError.unsupportedMultipleFilesOutput
        case .folder:
            // TODO: Implement saving to multiple files per step
            throw ProcessorStorageError.unsupportedMultipleFilesOutput
        }
    }
}

enum ProcessorStorageError: Error {
    case stepIsMissingInput
    case unsupportedMultipleFilesOutput
}