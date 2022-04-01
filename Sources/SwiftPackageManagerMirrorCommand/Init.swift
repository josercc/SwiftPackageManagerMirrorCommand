//
//  Init.swift
//  
//
//  Created by 张行 on 2022/4/1.
//

import Foundation
import ArgumentParser
import Alamofire
import SwiftShell

struct Init: ParsableCommand {
    func run() throws {
        let mirrorDataFile = try mirrorDataPath()
        if !FileManager.default.fileExists(atPath: mirrorDataFile) {
            FileManager.default.createFile(atPath: mirrorDataFile, contents: nil)
        }
        guard let mirrorData = try String(contentsOfFile: mirrorDataFile).data(using: .utf8) else {
            throw ExitCode.failure
        }
        var mirrorResponse:Response<[Mirror]> = .init(code: 200,
                                                      message: "",
                                                      isSuccess: true,
                                                      data: [],
                                                      page: .init(page: 1, total: 1, per: 10))
        if let result = try? JSONDecoder().decode(Response<[Mirror]>.self, from: mirrorData) {
            mirrorResponse = result
        }
        var mirrors = mirrorResponse.data ?? []
        let response = try getMirrors(page: 1)
        guard let page = response.page, let cachePage = mirrorResponse.page else {
            throw ExitCode.failure
        }
        if page.total <= cachePage.total {
            var cachePageIndex = cachePage.page
            let totalPage = page.total / page.per + page.total % page.per
            while cachePageIndex <= totalPage {
                print("正在下载镜像配置 当前进度 \(cachePageIndex)/\(totalPage - cachePage.page + 1)")
                let mirrorData = try getMirrors(page: cachePageIndex)
                mirrors.append(contentsOf: mirrorData.data ?? [])
                cachePageIndex += 1
            }
            mirrorResponse.page = response.page
            mirrorResponse.data = mirrors
            let data = try JSONEncoder().encode(mirrorResponse)
            guard let jsonText = String(data: data, encoding: .utf8) else {
                throw ExitCode.failure
            }
            try jsonText.write(toFile: mirrorDataFile, atomically: true, encoding: .utf8)
            print("下载镜像配置完毕")
        }
        var context = CustomContext()
        context.env = ProcessInfo.processInfo.environment
        guard let pwd = ProcessInfo.processInfo.environment["PWD"] else {
            throw ExitCode.failure
        }
        context.currentdirectory = pwd
        try mirrors.forEach { element in
            try context.runAndPrint("swift", "package", "config","set-mirror", "--original-url", element.origin, "--mirror-url", element.mirror)
        }
    }
    
    func getMirrors(page:Int) throws -> Response<[Mirror]> {
        let uri = server + "/list?page=\(page)&per=10"
        print(uri)
        var mirrorResponse:Response<[Mirror]>?
        let semaphore = DispatchSemaphore(value: 0)
        var message:String?
        AF.request(uri).responseDecodable(of:Response<[Mirror]>.self, queue: .global(qos: .background)) { response in
            mirrorResponse = response.value
            message = response.error?.localizedDescription
            semaphore.signal()
        }
        semaphore.wait()
        guard let mirrorResponse = mirrorResponse else {
            print(message ?? "")
            throw ExitCode.failure
        }
        return mirrorResponse
    }
}

struct Response<T: Codable>: Codable {
    let code:Int
    let message:String
    let isSuccess:Bool
    var data:T?
    var page:Page?
}

struct Page: Codable {
    let page:Int
    let total:Int
    let per:Int
}

struct Mirror: Codable {
    let origin:String
    let mirror:String
}

func mirrorDataPath() throws -> String {
    guard let home = ProcessInfo.processInfo.environment["HOME"] else {
        throw ExitCode.failure
    }
    let cachePath = home + "/Library/Caches"
    let mirrorDataFile = cachePath + "/mirror_data.json"
    return mirrorDataFile
}
