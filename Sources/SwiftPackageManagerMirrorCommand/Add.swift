//
//  Add.swift
//  
//
//  Created by admin on 2022/3/31.
//

import Foundation
import SwiftShell
import ArgumentParser
struct Add: ParsableCommand {
    @Argument(help:"需要制作镜像的库地址 https://github.com/xxxx/xxx")
    var url:String
    func run() throws {
        guard url.contains("https://github.com/") else {
            print("当前的地址不是一个github库地址")
            throw ExitCode.failure
        }
        try ManyMirror(urls: [url]).run()
    }
}
