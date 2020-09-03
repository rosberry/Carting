//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

import Files
import ShellOut
import Foundation
import XcodeProj

public final class ProjectService {

    enum Error: Swift.Error {
        case projectFileReadingFailed
        case targetFilterFailed(name: String)
        case noTargets(name: String?)
    }

    private enum Constants {
        static let projectExtension = "xcodeproj"
        static let carthageScript = "/usr/local/bin/carthage copy-frameworks"
        static let nothingToUpdate = "🤷‍♂️ Nothing to update."
    }

    public let projectDirectoryPath: String?
    public let frameworksDirectoryPaths: [String]

    private var projectFolder: Folder {
        if let path = projectDirectoryPath, let folder = try? Folder(path: path) {
            return folder
        }
        return FileSystem().currentFolder
    }

    // MARK: - Lifecycle

    public init(projectDirectoryPath: String?, frameworksDirectoryPaths: [String]) throws {
        self.projectDirectoryPath = projectDirectoryPath
        self.frameworksDirectoryPaths = frameworksDirectoryPaths.isEmpty ? ["Carthage"] : frameworksDirectoryPaths
    }

    public func updateScript(withName scriptName: String, format: Format, targetName: String?, projectNames: [String]) throws {
        let projectPaths = try self.projectPaths(inDirectory: projectDirectoryPath, filterNames: projectNames)
        guard projectPaths.count > 0 else {
            print(Constants.nothingToUpdate)
            return
        }
        for path in projectPaths {
            try updateScript(withName: scriptName, format: format, targetName: targetName, projectPath: path)
        }
    }

    public func updateScript(withName scriptName: String, format: Format, targetName: String?, projectPath: String) throws {
        let xcodeproj = try XcodeProj(pathString: projectPath)

        var needUpdateProject = false
        var filelistsWereUpdated = false

        let filteredTargets = try targets(in: xcodeproj, withName: targetName)

        if filteredTargets.isEmpty {
            throw Error.noTargets(name: targetName)
        }

        let carthageDynamicFrameworks = try dynamicFrameworksInformation().mapKeys(PathType.input)

        try filteredTargets.forEach { target in
            let inputPaths = target.paths(for: carthageDynamicFrameworks)
            let outputPaths = target.paths(for: carthageDynamicFrameworks.values.flatten(), type: .output)

            let targetBuildPhase = target.buildPhases.first { $0.name() == scriptName }
            let projectBuildPhase = xcodeproj.pbxproj.shellScriptBuildPhases.first { $0.uuid == targetBuildPhase?.uuid }

            var scriptHasBeenUpdated = false
            switch format {
            case .file:
                if let projectBuildPhase = projectBuildPhase {
                    scriptHasBeenUpdated = projectBuildPhase.update(shellScript: Constants.carthageScript)
                    scriptHasBeenUpdated = projectBuildPhase.update(inputPaths: inputPaths, outputPaths: outputPaths)
                }
                else {
                    let buildPhase = PBXShellScriptBuildPhase(name: scriptName,
                                                              inputPaths: outputPaths,
                                                              outputPaths: outputPaths,
                                                              shellScript: Constants.carthageScript)

                    target.buildPhases.append(buildPhase)
                    xcodeproj.pbxproj.add(object: buildPhase)
                    scriptHasBeenUpdated = true
                }
            case .list:
                let listsFolder = try projectFolder.createSubfolderIfNeeded(withName: "xcfilelists")
                let xcfilelistsFolderPath = listsFolder.path
                        .replacingOccurrences(of: projectFolder.path, with: "$(SRCROOT)/")
                        .deleting(suffix: "/")

                let inputFileListFileName = inputFileListName(forTargetName: target.name)
                let inputFileListPath = [xcfilelistsFolderPath, inputFileListFileName].joined(separator: "/")

                let outputFileListFileName = outputFileListName(forTargetName: target.name)
                let outputFileListPath = [xcfilelistsFolderPath, outputFileListFileName].joined(separator: "/")

                let inputFileListNewContent = inputPaths.joined(separator: "\n")
                filelistsWereUpdated = try updateFile(in: listsFolder,
                                                      withName: inputFileListFileName,
                                                      content: inputFileListNewContent)

                let outputFileListNewContent = outputPaths.joined(separator: "\n")
                filelistsWereUpdated = try updateFile(in: listsFolder,
                                                      withName: outputFileListFileName,
                                                      content: outputFileListNewContent)

                if let projectBuildPhase = projectBuildPhase {
                    scriptHasBeenUpdated = projectBuildPhase.update(shellScript: Constants.carthageScript)
                    scriptHasBeenUpdated = projectBuildPhase.update(inputFileListPath: inputFileListPath,
                                                                    outputFileListPath: outputFileListPath)
                }
                else {
                    let buildPhase = PBXShellScriptBuildPhase(name: scriptName,
                                                              inputFileListPaths: [inputFileListPath],
                                                              outputFileListPaths: [outputFileListPath],
                                                              shellScript: Constants.carthageScript)

                    target.buildPhases.append(buildPhase)
                    xcodeproj.pbxproj.add(object: buildPhase)
                    scriptHasBeenUpdated = true
                }
            }
            if scriptHasBeenUpdated {
                needUpdateProject = true
                print("✅ Script \(scriptName) in target \(target.name) was successfully updated.")
            }
        }

        if needUpdateProject {
            try xcodeproj.write(pathString: projectPath, override: true)
        }
        else if !filelistsWereUpdated {
            print(Constants.nothingToUpdate)
        }
    }

    public func printFrameworksInformation() throws {
        (try frameworksInformation()).values.flatten().forEach { information in
            let description = [information.name, information.linking.rawValue].joined(separator: "\t\t") +
                              "\t" +
                              information.architectures.map(\.rawValue).joined(separator: ", ")
            print(description)
        }
    }

    public func lintScript(withName scriptName: String, format: Format, targetName: String?, projectNames: [String]) throws {
        let projectPaths = try self.projectPaths(inDirectory: projectDirectoryPath, filterNames: projectNames)
        guard projectPaths.count > 0 else {
            print("🤷‍♂️ Nothing to lint.")
            return
        }
        for path in projectPaths {
            try lintScript(withName: scriptName, format: format, targetName: targetName, projectPath: path)
        }
    }

    public func lintScript(withName scriptName: String, format: Format, targetName: String?, projectPath: String) throws {
        let xcodeproj = try XcodeProj(pathString: projectPath)

        let filteredTargets = try targets(in: xcodeproj, withName: targetName)

        if filteredTargets.isEmpty {
            throw Error.noTargets(name: targetName)
        }

        let carthageDynamicFrameworks = try dynamicFrameworksInformation().mapKeys(PathType.input)

        try filteredTargets.forEach { target in

            let inputPaths = target.paths(for: carthageDynamicFrameworks)
            let outputPaths = target.paths(for: carthageDynamicFrameworks.values.flatten(), type: .output)

            let targetBuildPhase = target.buildPhases.first(with: scriptName, at: \.name)
            let buildPhase = xcodeproj.pbxproj.shellScriptBuildPhases.first(with: targetBuildPhase?.uuid, at: \.uuid)

            guard let projectBuildPhase = buildPhase else {
                return
            }

            var missingPaths = [String]()
            var projectInputPaths = [String]()
            var projectOutputPaths = [String]()
            switch format {
            case .file:
                projectInputPaths = projectBuildPhase.inputPaths
                projectOutputPaths = projectBuildPhase.outputPaths
            case .list:
                let listsFolder = try projectFolder.createSubfolderIfNeeded(withName: "xcfilelists")
                let xcfilelistsFolderPath = listsFolder.path
                        .replacingOccurrences(of: projectFolder.path, with: "$(SRCROOT)/")
                        .deleting(suffix: "/")

                let inputFileListFileName = inputFileListName(forTargetName: target.name)
                let inputFileListPath = [xcfilelistsFolderPath, inputFileListFileName].joined(separator: "/")

                let outputFileListFileName = outputFileListName(forTargetName: target.name)
                let outputFileListPath = [xcfilelistsFolderPath, outputFileListFileName].joined(separator: "/")

                if projectBuildPhase.inputFileListPaths?.contains(inputFileListPath) == false {
                    missingPaths.append(inputFileListPath)
                    break
                }
                if let inputFile = try? listsFolder.file(named: inputFileListFileName) {
                    projectInputPaths = try inputFile.readAsString().split(separator: "\n").map(String.init)
                }

                if projectBuildPhase.outputFileListPaths?.contains(outputFileListPath) == false {
                    missingPaths.append(inputFileListPath)
                    break
                }
                if let outputFile = try? listsFolder.file(named: outputFileListFileName) {
                    projectOutputPaths = try outputFile.readAsString().split(separator: "\n").map(String.init)
                }
            }
            missingPaths.append(contentsOf: inputPaths.filter { projectInputPaths.contains($0) == false })
            missingPaths.append(contentsOf: outputPaths.filter { projectOutputPaths.contains($0) == false })
            for path in missingPaths {
                print("error: Missing \(path) in \(target.name) target")
            }
        }
    }

    // MARK: - Private

    private func inputFileListName(forTargetName targetName: String) -> String {
        targetName + "-inputPaths.xcfilelist"
    }

    private func outputFileListName(forTargetName targetName: String) -> String {
        targetName + "-outputPaths.xcfilelist"
    }

    private func targets(in project: XcodeProj, withName name: String?) throws -> [PBXNativeTarget] {
        let filteredTargets = project.targets(with: .application, name: name)

        if let name = name, filteredTargets.isEmpty {
            throw Error.targetFilterFailed(name: name)
        }

        return filteredTargets
    }

    private func projectPaths(inDirectory directory: String?, filterNames: [String]) throws -> [String] {
        let directoryPath: String
        if let directory = directory {
            directoryPath = directory
        }
        else if let envPath = ProcessInfo.processInfo.environment["PROJECT_FILE_PATH"] {
            directoryPath = envPath
        }
        else {
            directoryPath = FileManager.default.currentDirectoryPath
        }
        let folder = try Folder(path: directoryPath)
        return folder.subfolders
                .filter { folder in
                    let projectName = folder.name.deleting(suffix: "." + Constants.projectExtension)
                    var isValid = folder.name.hasSuffix(Constants.projectExtension)
                    if filterNames.isEmpty == false {
                        isValid = isValid && filterNames.contains(projectName)
                    }
                    return isValid
                }
                .map { $0.path }
    }

    private func frameworksInformation() throws -> [String: [Framework]] {
        let frameworkFolders = Dictionary(uniqueKeysWithValues: try frameworksDirectoryPaths.map { path in
            (path, try projectFolder.subfolder(atPath: "\(path)/Build/iOS").subfolders)
        })
        return try frameworkFolders.compactMapValues { subfolders in
            try subfolders.compactMap { folder in
                folder.name.hasSuffix("framework") ? (try information(for: folder)) : nil
            }
        }
    }

    private func dynamicFrameworksInformation() throws -> [String: [Framework]] {
        try frameworksInformation().mapValues { frameworks in
            frameworks.filter { information in
                information.linking == .dynamic
            }
        }
    }

    private func information(for framework: Folder) throws -> Framework {
        let path = framework.path + framework.nameExcludingExtension
        let fileOutput = try shellOut(to: "file", arguments: [path.quotify])
        let lipoOutput = try shellOut(to: "lipo", arguments: ["-info", path.quotify])
        let rawArchitectures = lipoOutput.components(separatedBy: ": ").last!
        return Framework(name: framework.name,
                         architectures: architectures(fromOutput: rawArchitectures),
                         linking: linking(fromOutput: fileOutput))
    }

    @discardableResult
    private func updateFile(in folder: Folder, withName name: String, content: String) throws -> Bool {
        var fileWereUpdated = false
        if folder.containsFile(named: name) {
            let file = try folder.file(named: name)
            if let oldContent = try? file.readAsString(), oldContent != content {
                try shellOut(to: "chmod +w \"\(file.name)\"", at: folder.path)
                try file.write(string: content)
                fileWereUpdated = true
                print("✅ \(file.name) was successfully updated")
                try shellOut(to: "chmod -w \"\(file.name)\"", at: folder.path)
            }
        }
        else {
            let file = try folder.createFile(named: name)
            try file.write(string: content)
            fileWereUpdated = true
            print("✅ \(file.name) was successfully added")
            try shellOut(to: "chmod -w \"\(file.name)\"", at: folder.path)
        }
        return fileWereUpdated
    }
}

func linking(fromOutput output: String) -> Framework.Linking {
    if output.contains("current ar archive") {
        return .static
    }
    return .dynamic
}

func architectures(fromOutput output: String) -> [Framework.Architecture] {
    return output.components(separatedBy: " ").compactMap(Framework.Architecture.init)
}

extension ProjectService.Error: CustomStringConvertible {

    var description: String {
        switch self {
        case .projectFileReadingFailed:
            return "Can't find project file."
        case .targetFilterFailed(let name):
            return "There is no target with \(name) name."
        case .noTargets(let name):
            var description = "There are no application targets"
            if let name = name {
                description += " with \"\(name)\" name"
            }
            return description
        }
    }
}
