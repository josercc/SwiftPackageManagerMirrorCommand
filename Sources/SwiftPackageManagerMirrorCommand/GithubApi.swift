//
//  GithubApi.swift
//  
//
//  Created by 张行 on 2022/4/15.
//

import Foundation
import ArgumentParser
import Alamofire

struct GithubApi {
    let token:String
    let host = "https://api.github.com"
    init() throws {
        guard let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] else {
            print("GITHUB_TOKRN 不存在")
            throw ExitCode.failure
        }
        self.token = token
    }
    
    static func getTags(repoPath:String, page:Int = 1) throws -> [TagResponse] {
        sleep(2)
        let api = try GithubApi()
        let url = "\(api.host)/repos/\(repoPath)/tags?per_page=100&page=\(page)"
        let semphore = DispatchSemaphore(value: 0)
        var tags:[TagResponse]?
        let headers:HTTPHeaders = HTTPHeaders([.init(name: "Authorization", value: "Bearer \(api.token)")])
        AF.request(url,headers: headers).responseDecodable(of: [TagResponse].self, queue:.global()) { response in
            defer {
                semphore.signal()
            }
            if response.response?.statusCode != 200 {
                print(String(data: response.data!, encoding: .utf8) ?? "")
            }
            tags = response.value
        }
        semphore.wait()
        guard let tags = tags else {
            throw ExitCode.failure
        }
        return tags
    }
    
    static func getBranchs(repoPath:String, page:Int = 1) throws -> [BranchResponse] {
        sleep(2)
        let api = try GithubApi()
        let url = "\(api.host)/repos/\(repoPath)/branches"
        let semphore = DispatchSemaphore(value: 0)
        var branchs:[BranchResponse]?
        let headers:HTTPHeaders = HTTPHeaders([.init(name: "Authorization", value: "Bearer \(api.token)")])
        AF.request(url,headers: headers).responseDecodable(of: [BranchResponse].self, queue:.global()) { response in
            defer {
                semphore.signal()
            }
            if response.response?.statusCode != 200 {
                print(String(data: response.data!, encoding: .utf8) ?? "")
            }
            branchs = response.value
        }
        semphore.wait()
        guard let branchs = branchs else {
            throw ExitCode.failure
        }
        print(branchs.map({$0.name}))
        return branchs
    }
}

struct TagResponse: Codable {
    let name:String
}

struct BranchResponse: Codable {
    let name:String
}
