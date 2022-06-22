//
//  main.swift
//  SwiftyPixiv
//
//  Created by Fabio Mauersberger on 16.04.21.
//

import Foundation
import ArgumentParser
import pixivswiftWrapper
import pixivswift
import swiftbar

extension Publicity: ExpressibleByArgument {}

struct pixivloader: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Utility to manage illustrations/users from pixiv.net.",
        subcommands: [download.self, bookmark.self, unbookmark.self, follow.self, unfollow.self, info.self, meta_update.self, auth.self])
    
    // for now this is ~/Library/Application Support/pixivloader and not changable
    static let config_dir_url: URL = URL(fileURLWithPath: "pixivloader", relativeTo: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
    
    static let config_file_url: URL = URL(fileURLWithPath: "config.json", relativeTo: config_dir_url)
    
    static let translations_file_url: URL = URL(fileURLWithPath: "translations.json", relativeTo: config_dir_url)
    
    
    static var config: pixivloaderSettings = load_config(file_url: config_file_url)
    
    static var translations: [String:String] = load_translations(file_url: translations_file_url)
    
    static let downloader = PixivDownloader(login_with_token: config.loginRefreshToken)
    // Aka whether the translations file should be updated
    static var translations_changed: Bool = false
    
    struct Options: ParsableArguments {
        
        @Option(name: [.short, .long], help: "Set publicity for operation")
        var publicity: Publicity = Publicity.public
        
        /// If there shall be any verbosity for debugging (which for now doesnt exist) DEAD BECAUSE NO USE FOR NOW
        //@Flag(name: [.short, .long], help: "Set verbosity")
        //var verbose: Bool = false
        
        /// If any customwise defined options shall be saved to the config file
        @Flag(name: [.short, .long], help: "Overwrite current configuration")
        var overwrite: Bool = false
    }
    
    struct download: ParsableCommand {
        
        @OptionGroup var options: pixivloader.Options
        
        static var configuration = CommandConfiguration(abstract: "download illustrations")
        
        @Option(name: [.short, .long], help: "Set maximum posts to download")
        var limit: Int = config.downloadMaxPages
        
        @Option(name: [.short, .long], help: "directory to download to")
        var download_dir: String = config.downloadDirectory
        
        @Option(name: [.long], help: "maximum pages per post")
        var max_pages: Int = config.downloadMaxPages
        
        @Option(name: [.long], help: "minimum bookmarks required to be downloaded")
        var min_bookmarks: Int = config.downloadMinBookmarks
        
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
        
        @Option(name: [.long], help: "blacklist illustrations; also can be used to prevent illustrations i.e. relying in specific folders from redownloading")
        var blacklistedIllustrations: [Int] = []
        
        @Option(name: [.long], help: "blacklist users")
        var blacklistedUsers: [String] = []
        
        @Option(name: [.long], help: "blacklist tags")
        var blacklistedTags: [String] = []
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include ugoiras (GIFs)")
        var ugoiras: Bool = true
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include mangas")
        var mangas: Bool = true
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include illustrations")
        var illusts: Bool = true
        
        static func download(illusts: [PixivIllustration], download_dir: String, options: download, valid_types: Array<IllustrationType>) {
            let _illusts = Set(illusts.filter(
                { !options.blacklistedIllustrations.contains($0.id) // check against blacklisted illustration ID
                    && !options.blacklistedUsers.contains($0.user.name) // check against blacklisted user name
                    && !options.blacklistedUsers.contains(String($0.user.id)) // check against blacklisted user id
                    && $0.tags.allSatisfy({!options.blacklistedTags.contains($0.translatedName ?? $0.name)}) // check against blacklisted tags
                    && $0.totalBookmarks >= options.min_bookmarks && $0.pageCount <= options.max_pages // check against typical filters, namely bookmarks and pages
                    && valid_types.contains($0.type)})) // check against allowed media types
            if !_illusts.isEmpty {
                print("Query succeded, expecting \(_illusts.count) results with \(_illusts.reduce(0, {$0+$1.pageCount})) pages in total.")
                let bar = Progressbar(total: _illusts.count)
                for illustration in _illusts {
                    if illustration.pageCount != downloader.download(illustration: illustration, directory: URL(fileURLWithPath: download_dir, isDirectory: true), with_metadata: true).count { print("Download for illustration \(illustration.id) incomplete/failed!") } // The doenload has failed if the page count of the illustration does not equal the number of URLs returned by the download method
                    pixivloader.add_translations(file_url: pixivloader.translations_file_url, newTranslations: illustration.tags) // dump illustration tags
                    bar.setProgressAndPrint(bar.getProgress() + 1) // increment progress bar
                }
            } else {
                print("No illustrations to download!")
            }
        }
        
        mutating func run() {
            
            // Overwrite changed properties if applicable
            if options.overwrite {
                config.downloadDirectory = download_dir
                config.downloadMaxPages = max_pages
                config.downloadMinBookmarks = min_bookmarks
                config.blacklistIllustrations = blacklistedIllustrations
                config.blacklistUsers = blacklistedUsers
                config.blacklistTags = blacklistedTags
            }
            
            let valid_types: [IllustrationType] = [ugoiras ? IllustrationType.ugoira : nil, mangas ? IllustrationType.manga : nil, illusts ? IllustrationType.illust : nil].compactMap({$0}) // Set the allowed media types depending on the set flags
            
            if var tags = tags {
                let _ = (translations.keys).sorted(by: { $0.count > $1.count }).filter({ tags.lowercased().contains($0.lowercased()) }).map({tags = tags.lowercased().replacingOccurrences(of: $0.lowercased(), with: translations[$0]!)})
                //if self.options.verbose {
                print("Downloading tags: \(String(describing: tags.description))")
                //}
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
                min_bookmarks = (min_bookmarks == config.downloadMinBookmarks) ? 0 : min_bookmarks
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
                let _ = parse_result(source: illust).map({ do { try downloader.follow(user: downloader.illustration(illust_id: $0).user.id.description, publicity: self.options.publicity); Thread.sleep(forTimeInterval: .init(0.2)) } catch let e {pixivloader.handle(error: e)}})
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
                let _ = parse_result(source: illust).map({ do { try downloader.unfollow(user: downloader.illustration(illust_id: $0).user.id.description); Thread.sleep(forTimeInterval: .init(0.2)) } catch let e { pixivloader.handle(error: e) } })
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
                print("User name: \(illustration.user.name)")
                print("User ID: \(illustration.user.id)")
                print("Tags: \(illustration.tags.map {$0.translatedName != nil ? $0.translatedName! : $0.name})")
                print("Illustration bookmarks: \(illustration.totalBookmarks)")
                print("Date/Time created: \(illustration.creationDate)")
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
    
    struct auth: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "authorize the pixivloader installation")
        
        @Option(name: [.short, .long], help: "authorize by using a token")
        var refreshtoken: String?
        
        @Option(name: [.short, .long], help: "authorize by using username AND password")
        var user: String?
        
        @Option(name: [.short, .long], help: "authorize by using password AND password")
        var password: String?
        
        mutating func run() throws {
            #if canImport(Erik)
            downloader.login(username: user, password: password, refresh_token: refreshtoken)
            #else
            downloader.login(refresh_token: refreshtoken)
            #endif
            if !downloader.authed {
                fatalError("Login failed with given credentials!")
            }
            config.loginRefreshToken = downloader.refresh_token!
            save_and_quit(save_config: true, save_translations: false, error: nil)
        }
    }
    
    static func parse_result(source: String, user_mode: Bool = false) -> Set<Int> {
        var illusts = Set<Int>()
        if source.contains("https://") {
            illusts.insert(Int(source.split(separator: "/")[-1])!)
        } else if FileManager().directoryExists(source) {
            for item in try! FileManager.default.contentsOfDirectory(atPath: source) {
                if item.count >= 14, let _illust = Int(item.split(separator: "/").last!.split(separator: "_").first!) {
                    if 5 <= _illust.description.count && _illust.description.count <= 9 {
                        illusts.insert(_illust)
                    }
                }
            }
        } else if FileManager.default.fileExists(atPath: source) {
            if let _illust = Int(source.split(separator: "/").last!.split(separator: "_").first!) { illusts.insert(_illust) }
        } else if Int(source) != nil && source.count == 8 {
            illusts.insert(Int(source)!)
        } else if Int(source) != nil && user_mode {
            illusts.insert(Int(source)!)
        }
        return illusts
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
    
    static func load_config(file_url: URL) -> pixivloaderSettings {
        setup()
        let config = (try? JSONDecoder().decode(pixivloaderSettings.self, from: try! Data(contentsOf: config_file_url))) ?? pixivloaderSettings()
        return config
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
    
    static func save_and_quit(save_config: Bool, save_translations: Bool, error: Error?) {
        if save_config {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try! encoder.encode(config).write(to: config_file_url)
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
    
    static func add_translations(file_url: URL, newTranslations: [IllustrationTag]) {
        for dict in newTranslations {
            if dict.translatedName != nil && translations[dict.translatedName ?? ""] == nil {
                if dict.translatedName != "fate" {
                    translations[dict.translatedName ?? ""] = dict.name
                    translations_changed = true
                }
            }
        }
    }
    
    static func handle(error: Error) {
        switch error {
        case PixivError.targetNotFound:
            return
        case PixivError.RateLimitError:
            fatalError("Exiting on RateLimit!")
        case PixivError.AuthErrors.missingAuth:
            fatalError("Missing auth! Please run 'pixivloader auth' first!")
        default:
            fatalError()
        }
    }
}
pixivloader.main()

extension PixivIllustration: Hashable {
    public static func == (lhs: PixivIllustration, rhs: PixivIllustration) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

public struct pixivloaderSettings: Codable {
    public var downloadDirectory: String = "Downloads"
    public var downloadLimit: Int = 30
    public var downloadMaxPages: Int = 10
    public var downloadMinBookmarks: Int = 2500
    
    public var blacklistTags: [String] = []
    public var blacklistUsers: [String] = []
    public var blacklistIllustrations: [Int] = []
    
    public var loginRefreshToken: String = ""
}
