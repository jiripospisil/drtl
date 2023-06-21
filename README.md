# drtl

Yet another [tldr](https://github.com/tldr-pages/tldr) client. Written mostly as an exercise to try Zig. The client doesn't 
maintain a local database of tldr pages but rather embeds all of them in the binary.

<img width="972" alt="image" src="https://github.com/jiripospisil/drtl/assets/20820/364cb3c5-7ff2-4d9d-81ce-206c0e5306b8">

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
