import ArgumentParser
import Foundation
import SwiftShell
import Alamofire

let server = "http://122.112.144.84:8080/mirror"

struct SwiftPackageManagerMirrorCommand: ParsableCommand {
    
    static var configuration: CommandConfiguration {
        .init(commandName:"spmmc", subcommands: [
            CSVMirror.self
        ])
    }
    
    
    
    
    
    func run() throws {
        
    }
    
    
}
SwiftPackageManagerMirrorCommand.main(["csv","/Users/admin/Downloads/data.csv"])

struct MirrorResult<T: Codable>: Codable {
    let code:Int
    let message:String
    let data:T?
}
