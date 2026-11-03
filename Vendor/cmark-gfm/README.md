# cmark-gfm (vendored)

GitHub-flavored Markdown parser and HTML renderer used by md2HTML.

- Upstream: https://github.com/swiftlang/swift-cmark (branch `gfm`)
- Pinned commit: `437611671145d47e6d9679761b8a5987766f4ae5`
- License: BSD-2-Clause, see [COPYING](COPYING)

Only the C sources, headers, `.inc` tables, and module maps from upstream `src/` and
`extensions/` are copied; CMake files, `.re` scanner sources, and tests are left out.
Files are unmodified. `scripts/build_cmark.sh` compiles them into a cached static library.

To update, copy the same files from a newer upstream commit and change the pinned commit above.
