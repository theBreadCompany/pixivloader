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
        
        @Option(name: [.long], parsing: .upToNextOption, help: "blacklist illustrations; also can be used to prevent illustrations i.e. relying in specific folders from redownloading")
        var blacklistedIllustrations: [String] = []
        
        @Option(name: [.long], parsing: .upToNextOption, help: "blacklist users")
        var blacklistedUsers: [String] = []
        
        @Option(name: [.long], parsing: .upToNextOption, help: "blacklist tags")
        var blacklistedTags: [String] = []
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include ugoiras (GIFs)")
        var ugoiras: Bool = true
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include mangas")
        var mangas: Bool = true
        
        @Flag(name: .long, inversion: .prefixedNo, help: "include illustrations")
        var illusts: Bool = true
        
        static func download(illusts: [PixivIllustration], download_dir: String, options: download, valid_types: Array<IllustrationType>) {
            let _illusts = Set(illusts.filter(
                { !options.blacklistedIllustrations.contains($0.id.description)                               // check against blacklisted illustration ID
                    && !options.blacklistedUsers.contains($0.user.name)                                        // check against blacklisted user name
                    && !options.blacklistedUsers.contains(String($0.user.id))                                  // check against blacklisted user id
                    && $0.tags.allSatisfy({!options.blacklistedTags.contains($0.translatedName ?? $0.name)}) // check against blacklisted tags
                    && $0.totalBookmarks >= options.min_bookmarks && $0.pageCount <= options.max_pages        // check against typical filters, namely bookmarks and pages
                    && valid_types.contains($0.type)}))                                                          // check against allowed media types
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
                pixivloader.download.download(illusts: pixivloader.safelyExecute(content: illust_id.flatMap({parse_result(source: $0)}), for: { id in
                    [try downloader.illustration(illust_id: id as! Int)]
                }), download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if !user_id.isEmpty {
                pixivloader.download.download(illusts: pixivloader.safelyExecute(content: user_id, for: { id in
                    try downloader.user_illusts(user: id as! String, limit: limit)
                }), download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if !source.isEmpty {
                pixivloader.download.download(illusts: pixivloader.safelyExecute(content: source.flatMap({parse_result(source: $0)}), for: { id in
                    try downloader.related_illusts(illust_id: id as! Int, limit: limit)
                }), download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if newest {
                min_bookmarks = (min_bookmarks == config.downloadMinBookmarks) ? 0 : min_bookmarks
                pixivloader.download.download(illusts: pixivloader.safelyExecute(for: { _ in
                    try downloader.my_following_illusts(publicity: options.publicity, limit: limit)
                }), download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if recommended {
                pixivloader.download.download(illusts: pixivloader.safelyExecute(for: { _ in
                    try downloader.my_recommended(limit: limit)
                }), download_dir: download_dir, options: self, valid_types: valid_types)
            }
            if bookmarks {
                pixivloader.download.download(illusts: pixivloader.safelyExecute(for: { _ in
                    try downloader.my_favorite_works(publicity: options.publicity, limit: limit)
                }), download_dir: download_dir, options: self, valid_types: valid_types)
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
            
            pixivloader.safelyExecute(content: bookmark.flatMap({parse_result(source: $0)}), for: ({ id in
                try downloader.bookmark(illust_id: id as! Int, publicity: options.publicity)
            }))
            
        }
    }
    
    struct unbookmark: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "unbookmark illustrations")
        
        @Argument(parsing: .remaining, help: "un-bookmark illustration")
        var unbookmark: [String]
        
        mutating func run() {
            
            pixivloader.safelyExecute(content: unbookmark.flatMap({parse_result(source: $0)}), for: { id in
                try downloader.unbookmark(illust_id: id as! Int)
            })
        }
    }
    
    struct follow: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "follow users")
        
        @OptionGroup
        var options: pixivloader.Options
        
        @Option(name: [.short, .long], help: "manage illustration")
        var illust: [String] = []
        
        @Option(name: [.short, .long], help: "manage user")
        var user: [String] = []
        
        mutating func run() {
            
            if !illust.isEmpty {
                pixivloader.safelyExecute(content: illust.flatMap({parse_result(source: $0)}), for: { id in
                    try downloader.follow(user: downloader.illustration(illust_id: id as! Int).user.id.description, publicity: options.publicity)
                })
            } else if !user.isEmpty {
                pixivloader.safelyExecute(content: user.flatMap({parse_result(source: $0)}), for: {
                    try downloader.follow(user: downloader.illustration(illust_id: $0 as! Int).user.id.description, publicity: options.publicity)
                })
            } else {
                print("Please set -i or -u to specify a target.")
            }
        }
    }
    
    struct unfollow: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "unfollow users")
        
        @Option(name: [.short, .long], parsing: .upToNextOption, help: "manage illustration")
        var illust: [String] = []
        
        @Option(name: [.short, .long], parsing: .upToNextOption, help: "manage user")
        var user: [String] = []
        
        mutating func run() {
            
            if !illust.isEmpty {
                pixivloader.safelyExecute(content: illust, for: { id in
                    try downloader.follow(user: id as! String)
                })
            } else if !user.isEmpty {
                pixivloader.safelyExecute(content: user, for: { id in
                    try downloader.unfollow(user: id as! String)
                })
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

            if let illust_u = illust {
                pixivloader.safelyExecute(content: parse_result(source: illust_u), for: { id in 
                    let illustration = try downloader.illustration(illust_id: (id as! Set<Int>).first!) 
                    print("Title: \(illustration.title)")
                    print("Illustration ID: \(illustration.id)")
                    print("User name: \(illustration.user.name)")
                    print("User ID: \(illustration.user.id)")
                    print("Tags: \(illustration.tags.map {$0.translatedName != nil ? $0.translatedName! : $0.name})")
                    print("Illustration bookmarks: \(illustration.totalBookmarks)")
                    print("Date/Time created: \(illustration.creationDate)")
                    print("Illustration address: https://pixiv.net/en/artworks/\(illustration.id)")
                })
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
            if let refreshtoken = refreshtoken, refreshtoken.isEmpty {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/find")
                process.arguments = [".", "-name", "pixivauth", "-type", "f"]
                let find_stdout = Pipe()
                process.standardOutput = find_stdout
                print("Searching for a pixivauth executable...")
                try process.run()
                let find_data = find_stdout.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: find_data, encoding: .utf8), let execPath = output.components(separatedBy: "\n").first(where: {$0.contains("pixivauth")}) {
                    print("Found executable, preparing for GUI login...")
                    print("Executing " + execPath + "...")
                    let process = Process()
                    process.executableURL = URL(filePath: execPath)
                    let auth_stdout = Pipe()
                    process.standardOutput = auth_stdout
                    try process.run()
                    if let output = String(data: auth_stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), !output.isEmpty {
                        config.loginRefreshToken = output
                    }
                }
            }
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
                    if 5 <= _illust.description.count && _illust.description.count <= 10 {
                        illusts.insert(_illust)
                    }
                }
            }
        } else if FileManager.default.fileExists(atPath: source) {
            if let _illust = Int(source.split(separator: "/").last!.split(separator: "_").first!) { illusts.insert(_illust) }
        } else if Int(source) != nil {
            illusts.insert(Int(source)!)
        }
        return illusts
    }
    
    static func setup() {
        if !FileManager().directoryExists(config_dir_url.path) {
            try! FileManager.default.createDirectory(at: config_dir_url, withIntermediateDirectories: false)
        }
        if !FileManager().fileExists(atPath: config_file_url.path) {
            let _ = FileManager.default.createFile(atPath: config_file_url.path, contents: Data("{}".utf8))
        }
        if !FileManager().fileExists(atPath: translations_file_url.path) {
            let _ = FileManager.default.createFile(atPath: translations_file_url.path, contents: Data("{}".utf8))
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
    
    static func safelyExecute(content: Any? = nil, for function: (Any?) throws -> Void ) {
        let _ = safelyExecute(content: content, for: function, placeholderToMakeSyntaxNonAmbigous: true)
    }
    
    static func safelyExecute(content: Any? = nil, for function: (Any?) throws -> Any?, placeholderToMakeSyntaxNonAmbigous: Bool = true) -> [PixivIllustration] {
        var retries = 0
        var results = [PixivIllustration]()
        let content = content as? [Any] ?? Array(arrayLiteral: content as? Set<Int> ?? ())
        for var i in 0..<content.count {
            do {
                if let result = try function(content[i]) as? [PixivIllustration] {
                    results += result
                }
            } catch let e { handle(e, retries: &retries, i: &i) }
        }
        return results
    }
    
    static func handle(_ error: Error, retries: inout Int, i: inout Int) {
        switch(error) {
        case PixivError.RateLimitError:
            print("Ratelimit catched us, waiting for 10 sec until retrying...")
            Thread.sleep(forTimeInterval: 10)
            i -= 1
        case PixivError.targetNotFound(_):
            break
        case PixivError.responseAcquirationFailed(_):
            if retries < 3 { retries += 1 } else { fatalError(error.localizedDescription) }
        default:
            fatalError(error.localizedDescription)
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
    public var blacklistIllustrations: [String] = []
    
    public var loginRefreshToken: String = ""
}
