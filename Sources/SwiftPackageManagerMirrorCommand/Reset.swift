//
//  File.swift
//  
//
//  Created by 张行 on 2022/4/1.
//

import Foundation
import ArgumentParser

struct Reset: ParsableCommand {
    func run() throws {
        let mirrorDataPath = try mirrorDataPath()
        try FileManager.default.removeItem(atPath: mirrorDataPath)
    }
}
