# further help

These will (hopefully) help if you're interested in more examples.

### download
```
OVERVIEW: download illustrations

USAGE: pixivloader download <options>

OPTIONS:
  -p, --publicity <publicity>
                          Set publicity for operation (default: public)
  -v, --verbose           Set verbosity 
  -o, --overwrite         Overwrite current configuration 
  -l, --limit <limit>     Set maximum posts to download (default: 20)
  -d, --download_dir <download_dir>
                          directory to download to (default: Downloads)
  --max_pages <max_pages> maximum pages per post (default: 5)
  --min_bookmarks <min_bookmarks>
                          minimum bookmarks required to be downloaded (default: 1000)
  -t, --tags <tags>       tags to download 
  -i, --illust_id <illust_id>
                          illustration ID/URL to download 
  -u, --user_id <user_id> user ID/URL to download 
  -s, --source <source>   download illustrations related to given ID/URL 
  -n, --newest            download the newest illustrations of the users you are following 
  -r, --recommended       download recommended illustrations 
  -b, --bookmarks         download your bookmarks 
  --ugoiras/--no-ugoiras  include ugoiras (GIFs) (default: true)
  --mangas/--no-mangas    include mangas (default: true)
  --illusts/--no-illusts  include illustrations (default: true)
  -h, --help              Show help information.
```
Examples:
- ```pixivloader download -u nixeu -l 50 -d uwu``` -> downloads max. ``50``` illustrations of the user ```nixeu``` to the directory ```uwu```
- ```pixivloader download -b -l 50 --min_bookmarks 3000``` -> download the first ```50``` illustrations you've bookmarked publicly and filter out the ones under ```3000``` bookmarks
- ```pixivloader download -s 76945062 92390572 92364113 -l 10``` -> download illustrations related to given ```IDs```, you've keep in mind that the limit, here ```10```, is meant as the __limit per given ID__

### bookmark
```
OVERVIEW: bookmark illustrations

USAGE: pixivloader bookmark [--publicity <publicity>] [--verbose] [--overwrite] [<bookmark> ...]

ARGUMENTS:
  <bookmark>              bookmark illustration 

OPTIONS:
  -p, --publicity <publicity>
                          Set publicity for operation (default: public)
  -v, --verbose           Set verbosity 
  -o, --overwrite         Overwrite current configuration 
  -h, --help              Show help information.
```
Examples:
- ```pixivloader bookmark uwu``` -> publicly ```bookmark``` all illustrations in the directory ```uwu```
- ```pixivloader bookmark owo -p private``` -> privatly ```bookmark``` all illustrations in the directory ```owo```

### unbookmark
```
OVERVIEW: unbookmark illustrations

USAGE: pixivloader unbookmark [<unbookmark> ...]

ARGUMENTS:
  <unbookmark>            un-bookmark illustration 

OPTIONS:
  -h, --help              Show help information.
```
Examples:
- ```pixivloader unbookmark uwu``` -> ```unbookmark``` all illustrations in the directory ```uwu```, if they have been bookmarked at all

### follow
```
OVERVIEW: follow users

USAGE: pixivloader follow [--publicity <publicity>] [--verbose] [--overwrite] [--illust <illust>] [--user <user>]

OPTIONS:
  -p, --publicity <publicity>
                          Set publicity for operation (default: public)
  -v, --verbose           Set verbosity 
  -o, --overwrite         Overwrite current configuration 
  -i, --illust <illust>   manage illustration 
  -u, --user <user>       manage user 
  -h, --help              Show help information.
```
Examples:
- ```pixivloader follow --illust 55808865``` -> publicly ```follow``` the user who created the illustration ```55808865```
- ```pixivloader follow --user axsens -p private``` -> privatly ```follow``` the user ```axsens``` 

### unfollow
```
OVERVIEW: unfollow users

USAGE: pixivloader unfollow [--illust <illust>] [--user <user>]

OPTIONS:
  -i, --illust <illust>   manage illustration 
  -u, --user <user>       manage user 
  -h, --help              Show help information.
```
Examples:
- ```pixivloader unfollow --user axsens``` -> ```unfollow``` the user ```axsens```
- ```pixivloader unfollow --illust 55808865``` -> ```unfollow``` the user who created the illustration ```55808865```

### info
```
OVERVIEW: print details about users and illustrations

USAGE: pixivloader info [--illust <illust>] [--user <user>]

OPTIONS:
  -i, --illust <illust>   print information about an illustration 
  -u, --user <user>       print information about an user 
  -h, --help              Show help information.
```
Examples:
- ```pixivloader info --illust ~/Downloads/92428410_p0.png``` -> print ```info``` about the illustration ID ```92428410```

### meta update
```
OVERVIEW: update metadata of given images

USAGE: pixivloader meta_update <illusts>

ARGUMENTS:
  <illusts>               folder with illustrations to update 

OPTIONS:
  -h, --help              Show help information.
```
Examples:
- ```pixivloader meta_update test``` -> update the metadata of all images in the directory ```test```
