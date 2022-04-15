//
//  CSVMirror.swift
//  
//
//  Created by admin on 2022/3/31.
//

import Foundation
import ArgumentParser
import SwiftShell
import SwiftVersionCompare

var ParseUrls:[String] = []

struct CSVMirror: ParsableCommand {
    static var configuration: CommandConfiguration {
        .init(commandName:"csv")
    }
    @Argument(help:"CSV文件的路径")
    var file:String
    func run() throws {
        guard let data = FileManager.default.contents(atPath: file), let content = String(data: data, encoding: .utf8) else {
            print("\(file)无法读取数据")
            throw ExitCode.failure
        }
        var repos:[String] = []
        content.components(separatedBy: "\n").forEach { element in
            let subElements = element.components(separatedBy: ",")
            guard subElements.count == 3 else {
                return
            }
            let repo = subElements[2]
            guard repo.contains("\"") else {
                return
            }
            repos.append("https://github.com/\(repo.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\r", with: ""))")
         }
        var index = 0
        for repo in repos {
            index += 1
            if index < 143 {
                continue
            }
            let repoPath = repo.replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: ".git", with: "")
            var branch:String?
            let branchs = try GithubApi.getBranchs(repoPath: repoPath)
            if branchs.filter({$0.name == "main"}).count > 0 {
                branch = "main"
            } else if branchs.filter({$0.name == "master"}).count > 0 {
                branch = "master"
            } else if branchs.filter({$0.name == "develop"}).count > 0 {
                branch = "develop"
            }
            guard let branch = branch else {
                throw ExitCode.failure
            }
            print("\(index)/\(repos.count)")
            let _ = try getRepoDependencies(url: "https://raw.githubusercontent.com/\(repoPath)/\(branch)/Package.swift")
        }
        // try ManyMirror(urls: repos).run()
    }

    /// 获取仓库所有的依赖
    func getRepoDependencies(url:String) throws -> [String] {
        print("开始分析仓库依赖:\(url)")
        if ParseUrls.contains(url) {
            return []
        }
        /// 获取数据
        let data = try Data(contentsOf: URL(string: url)!)
        /// 获取 PWD
        guard let pwd = ProcessInfo.processInfo.environment["PWD"] else {
            throw ExitCode.failure
        }
        let packageFile = pwd + "/Package.swift"
        /// 检车是否存在 存在就删除
        if FileManager.default.fileExists(atPath: packageFile) {
            try FileManager.default.removeItem(atPath: packageFile)
        }
        /// 将输入写入本地文件 packageFile
        try data.write(to: URL(fileURLWithPath: packageFile))
        /// 获取描述信息
         var context = CustomContext()
        context.currentdirectory = pwd
        context.env = ProcessInfo.processInfo.environment
        let command = context.runAsync("swift", "package", "dump-package")
        command.resume()
        let commandStdout = command.stdout.read()
        guard let data = commandStdout.data(using: .utf8) else {
            throw ExitCode.failure
        }
        guard let dumpPackageResponse = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else {
            return []
        }
        guard let dependencies = dumpPackageResponse["dependencies"] as? [[String:Any]] else {
            return []
        }
        for dependencieMap in dependencies {
            print(dependencieMap)
            guard let data = try? JSONSerialization.data(withJSONObject: dependencieMap) else {
                continue
            }
            let dependencie = try JSONDecoder().decode(DumpPackageResponse.Dependencie.self, from: data)
            guard let source = dependencie.sourceControl.first else {
                throw ExitCode.failure
            }
            print(source.identity)
            guard let remote = source.location.remote.first else {
                throw ExitCode.failure
            }
            print(remote)
            let repoPath = remote.replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: ".git", with: "")
                .replacingOccurrences(of: "git@github.com:", with: "")
            if let range = source.requirement.range?.first {
                print(range)
                var filterTag:String?
                var page = 0
                while true {
                    page += 1
                    let tags = try GithubApi.getTags(repoPath: repoPath, page: page)
                    guard tags.count > 0 else {
                        break
                    }
                    for tag in tags {
                        let name = tag.name.replacingOccurrences(of: "v", with: "")
                        guard let tagVersion = Version(name),
                              let lowerBound = Version(range.lowerBound),
                              let upperBound = Version(range.upperBound),
                              tagVersion >= lowerBound,
                              tagVersion <= upperBound else {
                            print("\(tag.name) \(range)")
                            continue
                        }
                        filterTag = tag.name
                        break
                    }
                    if filterTag != nil {
                        break
                    }
                }
                guard let tag = filterTag else {
                    throw ExitCode.failure
                }
                print(tag)
                let dependencies = try getRepoDependencies(url: "https://raw.githubusercontent.com/\(repoPath)/\(tag)/Package.swift")
                print(dependencies)
            } else if let exact = source.requirement.exact?.first {
                let dependencies = try getRepoDependencies(url: "https://raw.githubusercontent.com/\(repoPath)/\(exact)/Package.swift")
                print(dependencies)
            } else if let branch = source.requirement.branch?.first {
                let dependencies = try getRepoDependencies(url: "https://raw.githubusercontent.com/\(repoPath)/\(branch)/Package.swift")
                print(dependencies)
            } else if let revision = source.requirement.revision?.first {
                let dependencies = try getRepoDependencies(url: "https://raw.githubusercontent.com/\(repoPath)/\(revision)/Package.swift")
                print(dependencies)
            }
            else {
                throw ExitCode.failure
            }
        }
        ParseUrls.append(url)
        return []
    }
}

struct DumpPackageResponse: Codable {
    let dependencies:[Dependencie]
}
extension DumpPackageResponse {
    struct Dependencie: Codable {
        let sourceControl:[SourceControl]
    }
}

extension DumpPackageResponse.Dependencie {
    struct SourceControl: Codable {
        let identity:String
        let location:Location
        let requirement:Requirement
    }
}

extension DumpPackageResponse.Dependencie.SourceControl {
    struct Location: Codable {
        let remote:[String]
    }
}

extension DumpPackageResponse.Dependencie.SourceControl {
    struct Requirement: Codable {
        let range:[Range]?
        let exact:[String]?
        let branch:[String]?
        let revision:[String]?
    }
}

extension DumpPackageResponse.Dependencie.SourceControl.Requirement {
    struct Range: Codable {
        let lowerBound:String
        let upperBound:String
    }
}


