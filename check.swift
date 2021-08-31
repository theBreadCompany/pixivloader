//
//  check.swift
//  A script to check for duplicate illustrations in two locations
//
//  Created by Fabio Mauersberger on 12.06.21.
//

import Foundation


if CommandLine.arguments.count == 3 {
    let dir1 = CommandLine.arguments[1]
    let dir2 = CommandLine.arguments[2]
    do {
        let dir1_content = try FileManager.default.contentsOfDirectory(atPath: dir1)
        do {
            let dir2_content = try FileManager.default.contentsOfDirectory(atPath: dir2).map({$0.components(separatedBy: ["_"]).first ?? ""})
            for file in dir1_content {
                if dir2_content.contains(file.components(separatedBy: ["_"]).first ?? "") { print("Deleting \(dir1)/\(file)"); try! FileManager.default.removeItem(atPath: dir1 + "/" + file)
                }
            }
        } catch {
            fatalError(dir2 + " does not exist!")
        }
    } catch {
        fatalError(dir1 + " does not exist!")
    }
} else {
    fatalError("Please supply two directory names as arguments!")
}
