#  pixivloader

A CLI to communicate with [pixiv.net](https://pixiv.net)

## Disclaimer

This whole peace is provided as is, and I am not responsible for any damage or law breakings, i. e. damage to your hardware or consumption of questionable content.

Also, please do not overuse this. Pixiv has no financial benefit from this, and they somehow have to finance their servers, too...

## Installation

I haven't uploaded an app archive yet, so you need to open the project file in Xcode and compile *in DEBUG mode*, because a bug yet causes the script to crash when built in Release mode.

## Documentation

generally:
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

See ```pixivloader help <subcommand>``` for detailed help.

You will be asked to provide either a token or you regular credentials on first login.


### Examples

## TODO
- Create tests

## Announcements
I'll release a repo of an iOS/macOS app using this API in a few weeks.

## Credits
- [pixiv.net](https://pixiv.net) for their amazing platform
- [Apple](https://github.com/apple) for creating a powerful language that is really nice to learn and use


