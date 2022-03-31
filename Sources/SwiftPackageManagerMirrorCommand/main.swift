import ArgumentParser
import Foundation
import SwiftShell
import Alamofire

let server = "http://swiftmirror.vipgz1.91tunnel.com/api/mirror"

struct SwiftPackageManagerMirrorCommand: ParsableCommand {
    func run() throws {
        /// 获取当前运行的路径
        guard let currentPath = ProcessInfo.processInfo.environment["PWD"] else {
            print("获取当前路径不存在!")
            throw ExitCode.failure
        }
        /// 获取当前路径的文件
        let currentContents = try FileManager.default.contentsOfDirectory(atPath: currentPath)
        /// 判断当前路径是否存在 Package.swift 是否是Swift Package Manager 工程
        guard currentContents.contains("Package.swift") else {
            print("当前不存在 Package.swift")
            throw ExitCode.failure
        }
        /// 获取当前项目的依赖 swift package show-dependencies
        var context = CustomContext()
        context.env = ProcessInfo.processInfo.environment
        context.currentdirectory = currentPath
        let command = context.runAsync("swift", "package","show-dependencies")
        command.resume()
        let commandStout = command.stdout.read()
        let expression = try NSRegularExpression(pattern: "https://github.com/.*.git")
        let result = expression.matches(in: commandStout,
                                        range: NSRange(commandStout.startIndex...,
                                                       in: commandStout))
        var dependencies:[String] = []
        result.forEach { subResult in
            let text = String(commandStout[Range(subResult.range, in: commandStout)!])
            guard !dependencies.contains(text) else {
                return
            }
            dependencies.append(text)
        }
        for dependency in dependencies {
            /// 获取镜像地址
            print("正在获取 \(dependency) 镜像地址")
            let mirrorUrl = try getMirror(from: dependency)
            /// 查询镜像是否存在
            guard try checkMirroRepoExit(url: mirrorUrl) else {
                print("[ERROR] 镜像\(mirrorUrl)还在制作中，大约需要30分钟。请稍后重试!")
                continue
            }
            print("镜像\(mirrorUrl)已经存在 准备设置镜像服务")
            /// swift package config set-mirror --original-url original --mirror-url mirror
            try context.runAndPrint("swift", "package", "config","set-mirror", "--original-url", dependency, "--mirror-url", mirrorUrl)
        }
        print("DONE")
    }
    
    func getMirror(from url:String) throws -> String {
        let semphore = DispatchSemaphore(value: 0)
        var mirrorUrl:String?
        AF.request(server,
                   method: .post,
                   parameters: ["url":url])
        .responseString(queue:.global(qos: .background)) { response in
            defer {
                semphore.signal()
            }
            do {
                let result = try response.result.get()
                print(result)
                guard let data = result.data(using: .utf8) else {
                    return
                }
                let mirrorResult = try JSONDecoder().decode(MirrorResult<String>.self, from: data)
                guard let data = mirrorResult.data else {
                    print(mirrorResult.message)
                    return
                }
                mirrorUrl = data
            } catch(let e) {
                print(e.localizedDescription)
            }
        }
        semphore.wait()
        guard let mirrorUrl = mirrorUrl else {
            throw ExitCode.failure
        }
        return mirrorUrl
    }
    
    func checkMirroRepoExit(url:String) throws -> Bool {
        let semphore = DispatchSemaphore(value: 0)
        var exit:Bool = false
        AF.request(url).response(queue:.global(qos: .background)) { response in
            defer {
                semphore.signal()
            }
            guard let statusCode = response.response?.statusCode else {
                return
            }
            exit = statusCode == 200
        }
        semphore.wait()
        return exit
    }
}
SwiftPackageManagerMirrorCommand.main()

struct MirrorResult<T: Codable>: Codable {
    let code:Int
    let message:String
    let data:T?
}
