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
        static let nothingToUpdate = "🤷️ Nothing to update."
        static let nothingToLint = "🤷‍️ Nothing to lint."
    }

    private let projectDirectoryPath: String
    private let carthageCopyFrameworks: String = "\(PathDispatcher.carthageScriptPath) copy-frameworks"

    private var projectFolder: Folder {
        if !projectDirectoryPath.isEmpty, let folder = try? Folder(path: projectDirectoryPath) {
            return folder
        }
        return Folder.current
    }

    // MARK: - Lifecycle

    public init(projectDirectoryPath: String) {
        self.projectDirectoryPath = projectDirectoryPath
    }

    public func updateScript(withName scriptName: String,
                             format: Format,
                             targetName: String,
                             projectNames: [String],
                             frameworksDirectoryPath: String,
                             shouldAppend: Bool) throws {
        let projectPaths = try self.projectPaths(inDirectory: projectDirectoryPath, filterNames: projectNames)
        guard projectPaths.count > 0 else {
            print(Constants.nothingToUpdate)
            return
        }
        for path in projectPaths {
            try updateScript(withName: scriptName,
                             format: format,
                             targetName: targetName,
                             projectPath: path,
                             frameworksDirectoryPath: frameworksDirectoryPath,
                             shouldAppend: shouldAppend)
        }
    }

    public func updateScript(withName scriptName: String,
                             format: Format,
                             targetName: String,
                             frameworksDirectoryPaths: [String],
                             shouldAppend: Bool) throws {
        let projectPaths = try self.projectPaths(inDirectory: projectDirectoryPath, filterNames: [])
        guard let projectPath = projectPaths.first else {
            print(Constants.nothingToUpdate)
            return
        }
        for path in frameworksDirectoryPaths {
            try updateScript(withName: scriptName,
                             format: format,
                             targetName: targetName,
                             projectPath: projectPath,
                             frameworksDirectoryPath: path,
                             shouldAppend: shouldAppend)
        }
    }

    public func updateScript(withName scriptName: String,
                             format: Format,
                             targetName: String,
                             projectPath: String,
                             frameworksDirectoryPath: String,
                             shouldAppend: Bool) throws {
        let (xcodeproj, filteredTargets, dynamicFrameworks) = try initialContext(projectPath: projectPath,
                                                                                 targetName: targetName,
                                                                                 frameworksDirectoryPath: frameworksDirectoryPath)

        var needUpdateProject = false
        var filelistsWereUpdated = false

        func updateBuildPhaseForFile(_ buildPhase: PBXShellScriptBuildPhase?,
                                     in target: PBXNativeTarget,
                                     inputPaths: [String],
                                     outputPaths: [String]) -> Bool {
            if let projectBuildPhase = buildPhase {
                return projectBuildPhase.update(shellScript: carthageCopyFrameworks) ||
                       projectBuildPhase.update(inputPaths: inputPaths, outputPaths: outputPaths)
            }
            else {
                let buildPhase = PBXShellScriptBuildPhase(name: scriptName,
                                                          inputPaths: inputPaths,
                                                          outputPaths: outputPaths,
                                                          shellScript: carthageCopyFrameworks)

                target.buildPhases.append(buildPhase)
                xcodeproj.pbxproj.add(object: buildPhase)
                return true
            }
        }

        func updateBuildPhaseForList(_ buildPhase: PBXShellScriptBuildPhase?,
                                     in target: PBXNativeTarget,
                                     inputFileListPath: String,
                                     outputFileListPath: String) -> Bool {
            if let projectBuildPhase = buildPhase {
                return projectBuildPhase.update(shellScript: carthageCopyFrameworks) ||
                       projectBuildPhase.update(inputFileListPath: inputFileListPath,
                                                outputFileListPath: outputFileListPath)
            }
            else {
                let buildPhase = PBXShellScriptBuildPhase(name: scriptName,
                                                          inputFileListPaths: [inputFileListPath],
                                                          outputFileListPaths: [outputFileListPath],
                                                          shellScript: carthageCopyFrameworks)

                target.buildPhases.append(buildPhase)
                xcodeproj.pbxproj.add(object: buildPhase)
                return true
            }
        }

        func proceed(target: PBXNativeTarget) throws {
            let (inputPaths, outputPaths) = paths(in: target, at: frameworksDirectoryPath, frameworks: dynamicFrameworks)
            let targetBuildPhase = target.buildPhases.first(with: scriptName, at: \.name)
            let projectBuildPhase = xcodeproj.pbxproj.shellScriptBuildPhases.first { $0.uuid == targetBuildPhase?.uuid }

            let scriptHasBeenUpdated: Bool
            switch format {
            case .file:
                scriptHasBeenUpdated = updateBuildPhaseForFile(projectBuildPhase,
                                                               in: target,
                                                               inputPaths: inputPaths,
                                                               outputPaths: outputPaths)
            case .list:
                let listsFolder = try projectFolder.createSubfolderIfNeeded(withName: "xcfilelists")
                let xcfilelistsFolderPath = listsFolder.path
                        .replacingOccurrences(of: projectFolder.path, with: PathDispatcher.srcRoot)
                        .deleting(suffix: "/")

                let inputFileListFileName = inputFileListName(forTargetName: target.name)
                let inputFileListPath = [xcfilelistsFolderPath, inputFileListFileName].joined(separator: "/")

                let outputFileListFileName = outputFileListName(forTargetName: target.name)
                let outputFileListPath = [xcfilelistsFolderPath, outputFileListFileName].joined(separator: "/")

                let inputFileListNewContent = inputPaths.joined(separator: "\n")
                filelistsWereUpdated = try updateFile(in: listsFolder,
                                                      withName: inputFileListFileName,
                                                      content: inputFileListNewContent,
                                                      shouldAppend: shouldAppend)

                let outputFileListNewContent = outputPaths.joined(separator: "\n")
                filelistsWereUpdated = try updateFile(in: listsFolder,
                                                      withName: outputFileListFileName,
                                                      content: outputFileListNewContent,
                                                      shouldAppend: shouldAppend)

                scriptHasBeenUpdated = updateBuildPhaseForList(projectBuildPhase,
                                                               in: target,
                                                               inputFileListPath: inputFileListPath,
                                                               outputFileListPath: outputFileListPath)
            }
            if scriptHasBeenUpdated {
                needUpdateProject = true
                print("✅ Script \(scriptName) in target \(target.name) was successfully updated.")
            }
        }

        try filteredTargets.forEach { target in
            try proceed(target: target)
        }

        if needUpdateProject {
            try xcodeproj.write(pathString: projectPath, override: true)
        }
        else if !filelistsWereUpdated {
            print(Constants.nothingToUpdate)
        }
    }

    public func printFrameworksInformation(frameworksDirectoryPath: String) throws {
        let informations = try frameworksInformation(frameworksDirectoryPath: frameworksDirectoryPath)
        informations.forEach { information in
            let description = [information.name, information.linking.rawValue].joined(separator: "\t\t") +
                              "\t" +
                              information.architectures.map(\.rawValue).joined(separator: ", ")
            print(description)
        }
    }

    public func lintScript(withName scriptName: String,
                           format: Format,
                           targetName: String,
                           projectNames: [String],
                           frameworksDirectoryPath: String) throws {
        let projectPaths = try self.projectPaths(inDirectory: projectDirectoryPath, filterNames: projectNames)
        guard projectPaths.count > 0 else {
            print(Constants.nothingToLint)
            return
        }
        for path in projectPaths {
            try lintScript(withName: scriptName,
                           format: format,
                           targetName: targetName,
                           projectPath: path,
                           frameworksDirectoryPath: frameworksDirectoryPath)
        }
    }

    public func lintScript(withName scriptName: String,
                           format: Format,
                           targetName: String,
                           frameworksDirectoryPaths: [String]) throws {
        let projectPaths = try self.projectPaths(inDirectory: projectDirectoryPath, filterNames: [])
        guard let projectPath = projectPaths.first else {
            print(Constants.nothingToLint)
            return
        }
        for path in frameworksDirectoryPaths {
            try lintScript(withName: scriptName,
                           format: format,
                           targetName: targetName,
                           projectPath: projectPath,
                           frameworksDirectoryPath: path)
        }
    }

    public func lintScript(withName scriptName: String,
                           format: Format,
                           targetName: String,
                           projectPath: String,
                           frameworksDirectoryPath: String) throws {

        func missingPaths(for target: PBXNativeTarget,
                          buildPhase: PBXShellScriptBuildPhase,
                          inputPaths: [String],
                          outputPaths: [String]) throws -> [String] {
            var missingPaths = [String]()
            var projectInputPaths = [String]()
            var projectOutputPaths = [String]()
            switch format {
            case .file:
                projectInputPaths = buildPhase.inputPaths
                projectOutputPaths = buildPhase.outputPaths
            case .list:
                let listsFolder = try projectFolder.createSubfolderIfNeeded(withName: "xcfilelists")
                let xcfilelistsFolderPath = listsFolder.path
                        .replacingOccurrences(of: projectFolder.path, with: PathDispatcher.srcRoot)
                        .deleting(suffix: "/")

                let inputFileListFileName = inputFileListName(forTargetName: target.name)
                let inputFileListPath = [xcfilelistsFolderPath, inputFileListFileName].joined(separator: "/")

                let outputFileListFileName = outputFileListName(forTargetName: target.name)
                let outputFileListPath = [xcfilelistsFolderPath, outputFileListFileName].joined(separator: "/")

                if buildPhase.inputFileListPaths?.contains(inputFileListPath) == false {
                    missingPaths.append(inputFileListPath)
                    break
                }
                if let inputFile = try? listsFolder.file(named: inputFileListFileName) {
                    projectInputPaths = try inputFile.readAsString().split(separator: "\n").map(String.init)
                }

                if buildPhase.outputFileListPaths?.contains(outputFileListPath) == false {
                    missingPaths.append(outputFileListPath)
                    break
                }
                if let outputFile = try? listsFolder.file(named: outputFileListFileName) {
                    projectOutputPaths = try outputFile.readAsString().split(separator: "\n").map(String.init)
                }
            }
            missingPaths.append(contentsOf: inputPaths.filter { projectInputPaths.contains($0) == false })
            missingPaths.append(contentsOf: outputPaths.filter { projectOutputPaths.contains($0) == false })
            return missingPaths
        }

        func proceed(target: PBXNativeTarget, frameworks: [Framework]) throws {

            let targetBuildPhase = target.buildPhases.first(with: scriptName, at: \.name)
            guard let buildPhase = xcodeproj.pbxproj.shellScriptBuildPhases.first(with: targetBuildPhase?.uuid, at: \.uuid) else {
                return
            }

            let (inputPaths, outputPaths) = paths(in: target, at: frameworksDirectoryPath, frameworks: frameworks)
            for path in (try missingPaths(for: target, buildPhase: buildPhase, inputPaths: inputPaths, outputPaths: outputPaths)) {
                print("error: Missing \(path) in \(target.name) target")
            }
        }

        let (xcodeproj, filteredTargets, dynamicFrameworks) = try initialContext(projectPath: projectPath,
                                                                                 targetName: targetName,
                                                                                 frameworksDirectoryPath: frameworksDirectoryPath)

        try filteredTargets.forEach { target in
            try proceed(target: target, frameworks: dynamicFrameworks)
        }
    }

    // MARK: - Private

    private func initialContext(projectPath: String,
                                targetName: String,
                                frameworksDirectoryPath: String) throws -> (XcodeProj, [PBXNativeTarget], [Framework]) {
        let xcodeproj = try XcodeProj(pathString: projectPath)

        let filteredTargets = try targets(in: xcodeproj, withName: targetName)

        if filteredTargets.isEmpty {
            throw Error.noTargets(name: targetName)
        }

        let dynamicFrameworks = try dynamicFrameworksInformation(frameworksDirectoryPath: frameworksDirectoryPath)

        return (xcodeproj, filteredTargets, dynamicFrameworks)
    }

    private func paths(in target: PBXNativeTarget,
                       at frameworksDirectoryPath: String,
                       frameworks: [Framework]) -> (input: [String], output: [String]) {
        (target.paths(for: frameworks, type: .input(frameworksDirectoryPath: frameworksDirectoryPath)),
         target.paths(for: frameworks, type: .output))
    }

    private func inputFileListName(forTargetName targetName: String) -> String {
        targetName + "-inputPaths.xcfilelist"
    }

    private func outputFileListName(forTargetName targetName: String) -> String {
        targetName + "-outputPaths.xcfilelist"
    }

    private func targets(in project: XcodeProj, withName name: String) throws -> [PBXNativeTarget] {
        let filteredTargets = project.targets(with: .application, name: name)

        if !name.isEmpty, filteredTargets.isEmpty {
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
        return folder.subfolders.compactMap { folder in
            let projectName = folder.name.deleting(suffix: "." + PathDispatcher.projectExtension)
            var isValid = folder.name.hasSuffix(PathDispatcher.projectExtension)
            if filterNames.isEmpty == false {
                isValid = isValid && filterNames.contains(projectName)
            }
            return isValid ? folder.path : nil
        }
    }

    private func frameworksInformation(frameworksDirectoryPath: String) throws -> [Framework] {
        let frameworkFolder = try projectFolder.subfolder(at: PathDispatcher.iOSFrameworksDirectory(path: frameworksDirectoryPath))
        let frameworks = frameworkFolder.subfolders.filter { $0.name.hasSuffix("framework") }
        return try frameworks.map(information)
    }

    private func dynamicFrameworksInformation(frameworksDirectoryPath: String) throws -> [Framework] {
        try frameworksInformation(frameworksDirectoryPath: frameworksDirectoryPath).filter { information in
            information.linking == .dynamic
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
    private func updateFile(in folder: Folder, withName name: String, content: String, shouldAppend: Bool) throws -> Bool {
        var fileWereUpdated = false
        if folder.containsFile(named: name) {
            let file = try folder.file(named: name)
            let (oldContent, newContent) = try self.content(for: file, newContent: content, shouldAppend: shouldAppend)
            if oldContent != newContent {
                try shellOut(to: "chmod +w \"\(file.name)\"", at: folder.path)
                try file.write(newContent)
                fileWereUpdated = true
                print("✅ \(file.name) was successfully updated")
                try shellOut(to: "chmod -w \"\(file.name)\"", at: folder.path)
            }
        }
        else {
            let file = try folder.createFile(named: name)
            try file.write(content)
            fileWereUpdated = true
            print("✅ \(file.name) was successfully added")
            try shellOut(to: "chmod -w \"\(file.name)\"", at: folder.path)
        }
        return fileWereUpdated
    }

    private func content(for file: File, newContent: String, shouldAppend: Bool) throws -> (oldContent: String, newContent: String) {
        let fileContent = try file.readAsString()
        return (fileContent, shouldAppend ? (fileContent + newContent) : (newContent))
    }
}

func linking(fromOutput output: String) -> Framework.Linking {
    if output.contains("current ar archive") {
        return .static
    }
    return .dynamic
}

func architectures(fromOutput output: String) -> [Framework.Architecture] {
    output.components(separatedBy: " ").compactMap(Framework.Architecture.init)
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
