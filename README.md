# drtl

Yet another [tldr](https://github.com/tldr-pages/tldr) client. Written mostly as an exercise to try Zig. The client doesn't 
maintain a local database of tldr pages but rather embeds all of them in the binary.

<img width="972" alt="image" src="https://github.com/jiripospisil/drtl/assets/20820/d40ee21a-2429-408f-9e96-26157beca855">

## Installation

```
# On Arch Linux
paru -Sy drtl-bin
```

You can also just use the [prebuilt binaries](https://github.com/jiripospisil/drtl/releases) or build it yourself.

## Usage

```
Usage: drtl <name>

Prints tldr page for the given name.

Pages are split into several categories (android, common, linux, osx, sunos, and windows). If
you want a page for a specific category, use "category/name".

Options:
 -h, --help        print this help
 -v, --version     print version
 -l, --list        list all pages
 ```

## Building from Source

Tested with [Zig](https://ziglang.org/) `0.11.0-dev.3726+8fcc28d30`.

```
./update_pages.bash # Optionally update tldr pages
zig build
```

## License

MIT
