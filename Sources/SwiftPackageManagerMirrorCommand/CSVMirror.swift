//
//  CSVMirror.swift
//  
//
//  Created by admin on 2022/3/31.
//

import Foundation
import ArgumentParser

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
        try ManyMirror(urls: repos).run()
    }
}
