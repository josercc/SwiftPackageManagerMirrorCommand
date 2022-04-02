//
//  ManyMirror.swift
//  
//
//  Created by admin on 2022/3/31.
//

import Foundation
import ArgumentParser
import Alamofire
import SwiftShell
struct ManyMirror {
    var urls:[String]
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
        
        let mirrorDataPath = try mirrorDataPath()
        let mirrorJson = try String(contentsOfFile: mirrorDataPath)
        guard let mirrorData = mirrorJson.data(using: .utf8) else {
            throw ExitCode.failure
        }
        let mirrorResponse = try JSONDecoder().decode(Response<[Mirror]>.self,
                                                      from: mirrorData)
        let mirrors = mirrorResponse.data ?? []
        
        /// 获取当前项目的依赖 swift package show-dependencies
        var context = CustomContext()
        context.env = ProcessInfo.processInfo.environment
        context.currentdirectory = currentPath
        let dependencies = urls
        guard dependencies.count > 0 else {
            throw ExitCode.failure
        }
        for dependency in dependencies {
            if let mirror = mirrors.filter({$0.origin == dependency}).first {
                try setMirror(context: context,
                              original: dependency,
                              mirror: mirror.mirror)
            }
            /// 获取镜像地址
            print("正在获取 \(dependency) 镜像地址")
            do {
                let mirrorUrl = try getMirror(from: dependency)
                /// 查询镜像是否存在
                guard try checkMirroRepoExit(url: mirrorUrl) else {
                    print("[ERROR] 镜像\(mirrorUrl)还在制作中，大约需要30分钟。请稍后重试!")
                    continue
                }
                print("镜像\(mirrorUrl)已经存在 准备设置镜像服务")
                /// swift package config set-mirror --original-url original --mirror-url mirror
    //            try context.runAndPrint("swift", "package", "config","set-mirror", "--original-url", dependency, "--mirror-url", mirrorUrl)
                try setMirror(context: context,
                              original: dependency,
                              mirror: mirrorUrl)
            } catch(_) {
                continue
            }
            
        }
        print("DONE")
    }
    
    func getMirror(from url:String) throws -> String {
        let semphore = DispatchSemaphore(value: 0)
        var mirrorUrl:String?
        AF.request(server + "/mirror",
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
        AF.request(url).responseDecodable(of: Response<String>.self, queue: .global(qos: .background)) { response in
            defer {
                semphore.signal()
            }
            print(response.value?.message ?? "")
            guard let statusCode = response.response?.statusCode else {
                return
            }
            exit = statusCode == 200
        }
        semphore.wait()
        return exit
    }
}

func setMirror(context:CustomContext, original:String, mirror:String) throws {
    print("swift package config set-mirror --original-url \(original) --mirror-url \(mirror)")
    try context.runAndPrint("swift", "package", "config","set-mirror", "--original-url", original, "--mirror-url", mirror)
}
