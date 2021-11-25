#  pixivloader

A CLI to communicate with [pixiv.net](https://pixiv.net)

## Disclaimer

This whole peace is provided as is, and I am not responsible for any damage or law breakings, i. e. damage to your hardware or consumption of questionable content.

Also, please do not overuse this. Pixiv has no financial benefit from this, and they somehow have to finance their servers, too...

## Installation

Clone this repo via ```git clone https://github.com/theBreadCompany/pixivloader```, enter it via ```cd pixivloader``` and build via ```swift build```. You then have a handy binary at ```.build/debug/pixivloader``` that you can move to a location in your ```PATH```.

You yet have to clone the repo and build it yourself because I didn't upload any binary yet as some bugs occur when built in release mode.

## Documentation

### generally:
```
USAGE: pixivloader <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  download                download illustrations
  bookmark                bookmark illustrations
  unbookmark              unbookmark illustrations
  follow                  follow users
  unfollow                unfollow users
  info                    print details about users and illustrations
  meta_update             update metadata of given images
```

See ```pixivloader help <subcommand>``` or [furtherHelp.md](https://github.com/theBreadCompany/pixivloader/blob/main/furtherHelp.md) for detailed help.
You will be asked to provide either a token or you regular credentials on first login.

### Examples

- ```pixivloader download -u nixeu -l 50 -d uwu``` -> downloads max. ```50``` illustrations of the user ```nixeu``` to the directory ```uwu```
- ```pixivloader info --illust 92167325```-> print information about the illustration with the ID ```92167325``` (filenames are possible, too)
- ```pixivloader bookmark uwu``` -> publicly bookmarks all illustrations in the directory ```uwu```

### Tips And Tricks
- if your system has a easy-to-use index search (like macOS spotlight), you can combine this tool with it: you can use i.e. ```pixivloader download -s $(mdfind -interpret "girl scenery" -onlyin <dir1>)``` to download illustrations that are related to the ones returned by the search query, which itself searches for images with the tags ```girl``` and ```scenery``` in the directory ```<dir1>```.
- the script is not yet able to read the the source URL integrated in the image, meaning that you have to preserve the ID in the filename in order to keep it recognizable by the script

## Tools
- check.swift: a small script to check if a directory contains illustrations of another directory. Use with ```check <dir1> <dir2>```, all matching illustrations from ```<dir2>``` that occur in ```<dir1>``` will be deleted. Compile with ```swiftc check.swift``` and place somewhere handy.

## TODO
- Create tests

## Announcements
I'll release a repo of an iOS/macOS app using this API in a few weeks.


## Credits
- [pixiv.net](https://pixiv.net) for their amazing platform
- [Apple](https://github.com/apple) for creating a powerful language that is really nice to learn and use


