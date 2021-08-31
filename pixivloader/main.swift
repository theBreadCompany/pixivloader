//
//  main.swift
//  SwiftyPixiv
//
//  Created by Fabio Mauersberger on 16.04.21.
//

import Foundation
import ArgumentParser
import SwiftyPixiv
import pixivswift

extension Publicity: ExpressibleByArgument {}

struct pixivloader: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Utility to manage illustrations/users from pixiv.net.",
        subcommands: [download.self, bookmark.self, unbookmark.self, follow.self, unfollow.self, info.self, meta_update.self])
    

    static let config_dir_url: URL = URL(fileURLWithPath: "pixivloader", relativeTo: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
    static let config_file_url: URL = URL(fileURLWithPath: "config.txt", relativeTo: config_dir_url)
    static let translations_file_url: URL = URL(fileURLWithPath: "translations.txt", relativeTo: config_dir_url)
    
    static let placeholder: () = setup()
    
    static var config: [String:Any] = load_config(file_url: config_file_url)
    static var translations: [String:String] = load_translations(file_url: translations_file_url)
    
    static let downloader = PixivDownloader(login_with_token: config["refresh_token"] as! String)
    
    static var translations_changed: Bool = false
    
    struct Options: ParsableArguments {
        
        @Option(name: [.short, .long], help: "Set publicity for operation")
        var publicity: Publicity = Publicity.public
        
        @Flag(name: [.short, .long], help: "Set verbosity")
        var verbose: Bool = false
        
        @Flag(name: [.short, .long], help: "Overwrite current configuration")
        var overwrite: Bool = false
    }
    
    struct download: ParsableCommand {
        
        @OptionGroup var options: pixivloader.Options
        
        static var configuration = CommandConfiguration(abstract: "download illustrations")
        
        @Option(name: [.short, .long], help: "Set maximum posts to download")
        var limit: Int = config["limit"] as! Int
        
        @Option(name: [.short, .long], help: "directory to download to")
        var download_dir: String = config["download_dir"] as! String
        
        @Option(name: [.long], help: "maximum pages per post")
        var max_pages: Int = config["max_pages"] as! Int
        
        @Option(name: [.long], help: "minimum bookmarks required to be downloaded")
        var min_bookmarks: Int = config["min_bookmarks"] as! Int
        
        @Option(name: [.short, .long], help: "tags to download")
        var tags: String?
        
        @Option(name: [.short, .long], parsing: .upToNextOption, help: "illustration ID/URL to download")
        var illust_id: [String] = []
        
        @Option(name: [.short, .long], parsing: .upToNextOption, help: "user ID/URL to download")
        var user_id: [String] = []
        
        @Option(name: [.short, .long], parsing: .upToNextOption, help: "download illustrations related to given ID/URL")
        var source: [String] = []
       
        @Flag(name: .shortAndLong, help: "download the newest illustrations of the users you are following")
        var newest: Bool = false
        
        @Flag(name: .shortAndLong, help: "download recommended illustrations")
        var recommended: Bool = false
        
        @Flag(name: .shortAndLong, help: "download your bookmarks")
        var bookmarks: Bool = false
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include ugoiras (GIFs)")
        var ugoiras: Bool = true
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include mangas")
        var mangas: Bool = true
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include illustrations")
        var illusts: Bool = true
        
        static func download(illusts: [PixivIllustration], download_dir: String, options: download, valid_types: Array<IllustType>) {
            var idSet = [Int]()
            var _illusts = illusts.filter({ $0.total_bookmarks >= options.min_bookmarks && $0.page_count <= options.max_pages && valid_types.contains($0.type)})
            _illusts = _illusts.compactMap({ if !idSet.contains($0.id) {idSet.append($0.id); return $0} else {return nil} })
            if !_illusts.isEmpty {
                print("Query succeded, expecting \(_illusts.count) results with \(_illusts.flatMap({$0.image_urls}).count) pages in total.")
                for illustration in _illusts {
                    if illustration.page_count != downloader.download(illustration: illustration, directory: URL(fileURLWithPath: download_dir, isDirectory: true), with_metadata: true).count { print("Download for illustration \(illustration.id) failed!") }
                    pixivloader.add_translations(file_url: pixivloader.translations_file_url, translation_array: illustration.tags_dict as [[String:Any]])
                }
            } else {
                print("No illustrations to download!")
            }
        }
        
        mutating func run() {
            
            let valid_types: [IllustType] = [ugoiras ? IllustType.ugoira : nil, mangas ? IllustType.manga : nil, illusts ? IllustType.illust : nil].compactMap({$0})
                             
            if var tags = tags {
                let _ = (translations.keys).sorted(by: { $0.count > $1.count }).filter({ tags.lowercased().contains($0.lowercased()) }).map({tags = tags.lowercased().replacingOccurrences(of: $0.lowercased(), with: translations[$0]!)})
                if self.options.verbose {
                    print("Downloading tags: \(String(describing: tags.description))")
                }
                pixivloader.download.download(illusts: try! downloader.search(query: tags, limit: limit), download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if !illust_id.isEmpty {
                var illusts: [PixivIllustration] = []
                let _ = illust_id.flatMap({parse_result(source: $0)}).map({do { illusts.append(try downloader.illustration(illust_id: $0)) } catch let e { handle(error: e) }})
                pixivloader.download.download(illusts: illusts, download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if !user_id.isEmpty {
                var illusts: [PixivIllustration] = []
                let _ = user_id.map({do { let _ = try downloader.user_illusts(user: $0, limit: limit).map({illusts.append($0)})} catch let e {pixivloader.handle(error: e)}})
                pixivloader.download.download(illusts: illusts,download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if !source.isEmpty {
                var illusts: [PixivIllustration] = []
                let _ = source.flatMap({parse_result(source: $0)}).map({ do { illusts.append(contentsOf: try downloader.related_illusts(illust_id: $0, limit: limit))} catch let e {pixivloader.handle(error: e)}})
                pixivloader.download.download(illusts: illusts, download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if newest {
                do { pixivloader.download.download(illusts: try downloader.my_following_illusts(publicity: options.publicity, limit: limit), download_dir: download_dir, options: self, valid_types: valid_types) } catch let e {pixivloader.handle(error: e)}
            }
            if recommended {
                do { pixivloader.download.download(illusts: try downloader.my_recommended(limit: limit), download_dir: download_dir, options: self, valid_types: valid_types) } catch let e {pixivloader.handle(error: e)}
            }
            if bookmarks {
                do { pixivloader.download.download(illusts: try downloader.my_favorite_works(limit: limit), download_dir: download_dir, options: self, valid_types: valid_types) } catch let e {pixivloader.handle(error: e)}
            }
            
            save_and_quit(save_config: options.overwrite, save_translations: translations_changed, error: nil)
        }
    }
    
    struct bookmark: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "bookmark illustrations")
        
        @OptionGroup var options: pixivloader.Options
        
        @Argument(parsing: .remaining, help: "bookmark illustration")
        var bookmark: [String]
        
        mutating func run() {
              
            let source = bookmark.flatMap({parse_result(source: $0)})
            let _ = source.map( { do { try downloader.bookmark(illust_id: $0, publicity: self.options.publicity); source.count >= 50 ? Thread.sleep(forTimeInterval: TimeInterval(0.16)) : Thread.sleep(forTimeInterval: TimeInterval(0))} catch let e {pixivloader.handle(error: e)}} )
            
        }
    }
    
    struct unbookmark: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "unbookmark illustrations")
                
        @Argument(parsing: .remaining, help: "un-bookmark illustration")
        var unbookmark: [String]
        
        mutating func run() {

            let source = unbookmark.flatMap({parse_result(source: $0)})
            let _ = source.map( {do { try downloader.unbookmark(illust_id: $0); source.count >= 50 ? Thread.sleep(forTimeInterval: TimeInterval(0.15)) : Thread.sleep(forTimeInterval: TimeInterval(0))} catch let e {pixivloader.handle(error: e)}} )
            
        }
    }
    
    struct follow: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "follow users")
        
        @OptionGroup var options: pixivloader.Options
        
        @Option(name: [.short, .long], help: "manage illustration")
        var illust: String?
        
        @Option(name: [.short, .long], help: "manage user")
        var user: String?
        
        mutating func run() {
            
            if let illust = illust {
                let _ = parse_result(source: illust).map({ do { try downloader.follow(user: downloader.illustration(illust_id: $0).user_id.description, publicity: self.options.publicity); Thread.sleep(forTimeInterval: .init(0.2)) } catch let e {pixivloader.handle(error: e)}})
            } else if let user = user {
                try! downloader.follow(user: user, publicity: self.options.publicity)
            } else {
                print("Please set -i or -u to specify a target.")
            }
        }
    }
    
    struct unfollow: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "unfollow users")
        
        @Option(name: [.short, .long], help: "manage illustration")
        var illust: String?
        
        @Option(name: [.short, .long], help: "manage user")
        var user: String?
        
        mutating func run() {
            
            if let illust = illust {
                let _ = parse_result(source: illust).map({ do { try downloader.unfollow(user: downloader.illustration(illust_id: $0).user_id.description); Thread.sleep(forTimeInterval: .init(0.2)) } catch let e { pixivloader.handle(error: e) } })
            } else if let user = user {
                try! downloader.unfollow(user: user)
            }
        }
    }
    
    struct info: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "print details about users and illustrations")
        
        @Option(name: [.short, .long], help: "print information about an illustration")
        var illust: String?
        
        @Option(name: [.short, .long], help: "print information about an user")
        var user: String?
        
        mutating func run() {
            
            if let user = user {
                print(try! downloader.user_details(user: user))
            }
            if let illust = illust {
                let illustration = try! downloader.illustration(illust_id: parse_result(source: illust).first!)
                print("Title: \(illustration.title)")
                print("Illustration ID: \(illustration.id)")
                print("User name: \(illustration.user_name)")
                print("User ID: \(illustration.user_id)")
                print("Tags: \(illustration.tags_dict.description)")
                print("Illustration bookmarks: \(illustration.total_bookmarks)")
                print("Date/Time created: \(illustration.creation_time)")
                print("Illustration address: https://pixiv.net/en/artworks/\(illustration.id)")
            }
        }
    }
    
    struct meta_update: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "update metadata of given images")
        
        @Argument(help: "folder with illustrations to update")
        var illusts: String
        
        mutating func run() {
            do {
                for _file in try FileManager.default.contentsOfDirectory(atPath: illusts) {
                    if _file.contains(".jpg") || _file.contains(".png") {
                        let file = "\(FileManager.default.currentDirectoryPath)/\(illusts)/\(_file)"
                        if let illust_id = parse_result(source: file).first {
                            downloader.meta_update(metadata: try! downloader.illustration(illust_id: illust_id), illust_url: URL(fileURLWithPath: file))
                        }
                    }
                }
            } catch {
                print("Given directory not found!")
            }
        }
    }
    
    static func parse_result(source: String, user_mode: Bool = false) -> [Int] {
        var illusts: [Int] = []
        if source.contains("https://") {
            illusts.append(Int(source.split(separator: "/")[-1])!)
        } else if FileManager().directoryExists(source) {
            for item in try! FileManager.default.contentsOfDirectory(atPath: source) {
                if item.count >= 14, let _illust = Int(item.split(separator: "/").last!.split(separator: "_").first!) {
                    if 5 <= _illust.description.count && _illust.description.count <= 9 {
                        illusts.append(_illust)
                    }
                }
            }
        } else if FileManager.default.fileExists(atPath: source) {
            if let _illust = Int(source.split(separator: "/").last!.split(separator: "_").first!) { illusts.append(_illust) }
        } else if Int(source) != nil && source.count == 8 {
            illusts.append(Int(source)!)
        } else if Int(source) != nil && user_mode {
            illusts.append(Int(source)!)
        }
         return Array(Set(illusts))
    }
    
    static func setup() {
        if !FileManager().directoryExists(config_dir_url.path) {
            try! FileManager.default.createDirectory(at: config_dir_url, withIntermediateDirectories: false)
        }
        if !FileManager().fileExists(atPath: config_file_url.path) {
            FileManager.default.createFile(atPath: config_file_url.path, contents: Data("{}".utf8))
        }
        if !FileManager().fileExists(atPath: translations_file_url.path) {
            FileManager.default.createFile(atPath: translations_file_url.path, contents: Data("{}".utf8))
        }
    }
    
    static func load_config(file_url: URL) -> [String:Any]{
        var _config: [String?:Any?] = [:]
        do {
            _config = try JSONSerialization.jsonObject(with: Data(String(contentsOfFile: file_url.path).utf8), options: .fragmentsAllowed) as! [String?:Any?]
            if _config["download_dir"] == nil || _config["limit"] == nil || _config["max_pages"] == nil || _config["min_bookmarks"] == nil {
                _config["download_dir"] = "Downloads"
                _config["limit"] = 20
                _config["min_bookmarks"] = 2000
                _config["max_pages"] = 10
            }
            if _config["refresh_token"] == nil {
                _config["refresh_token"] = get_token()
            }
        } catch {
            _config["download_dir"] = "Downloads"
            _config["limit"] = 20
            _config["min_bookmarks"] = 2000
            _config["max_pages"] = 10
            _config["refresh_token"] = get_token()
        }
        return _config as! [String:Any]
    }
    
    static func load_translations(file_url: URL) -> [String:String]{
        var _translations: [String:String]
        do {
            _translations = try JSONSerialization.jsonObject(with: Data(String(contentsOfFile: file_url.path).utf8), options: .fragmentsAllowed) as! [String:String]
        } catch {
            _translations = [:]
        }
        return _translations
    }
    
    static func get_token() -> String {
        print("No login credentials saved; enter \"u\" to login with credentials, \n\"t\" if you have a refreshtoken or \"q\" to quit.")
        var login_method = ""
        while true {
            login_method = readLine()!
            if login_method == "u" {
                print("username: ")
                let username = readLine()
                let password = String(validatingUTF8: getpass("password: "))
                self.downloader.login(username: username, password: password)
                return self.downloader.refresh_token!
            } else if login_method == "t" {
                print("token: ")
                let token = readLine()
                self.downloader.login(refresh_token: token)
                return self.downloader.refresh_token!
            } else if login_method == "q" {
                fatalError("No login method given; exiting...")
            }
        }
    }
    
    static func save_and_quit(save_config: Bool, save_translations: Bool, error: Error?) {
        if save_config {
            try! config.description.write(toFile: config_file_url.path, atomically: true, encoding: String.Encoding.utf8)
        }
        if save_translations {
            try! JSONSerialization.data(withJSONObject: translations, options: .prettyPrinted).write(to: self.translations_file_url)
        }
        if let error = error {
            exit(withError: error)
        } else {
            exit()
        }
    }
    
    static func add_translations(file_url: URL, translation_array: [[String:Any]]) {
        for dict in translation_array {
            if (dict["translated_name"] as? String) != nil && translations[dict["translated_name"] as! String] == nil {
                if translations[dict["translated_name"] as! String] != "fate" {
                    translations[dict["translated_name"] as! String] = dict["name"]! as? String
                    translations_changed = true
                }
            }
        }
    }
    
    static func handle(error: Error) {
        switch error {
        case PixivError.targetNotFound, PixivError.badProgramming:
            return
        case PixivError.RateLimitError:
            fatalError("Exiting on RateLimit!")
        default:
            fatalError()
        }
    }
}
pixivloader.main()
