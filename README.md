# zrm - A Safe File Deletion Utility

A modern replacement for `rm` written in Zig that moves files to trash instead of permanently deleting them, giving you a safety net for accidental deletions.

## 🎯 Project Goals

Inspired by the Rust community's movement to rewrite classic Unix utilities with modern safety features (like `ripgrep`, `exa`, `bat`), this project aims to bring similar improvements to the Zig ecosystem. The goal is to create a fast, safe, and user-friendly alternative to `rm` that prevents the all-too-common "oh no, I just deleted that" moment.

## ⚠️ Development Status

**This project is currently in active development.** Core functionality is working, but several features are still being implemented.

### ✅ Implemented Features

- ✅ Move files to trash instead of permanent deletion
- ✅ Recursive directory deletion (`-r` flag)
- ✅ Metadata tracking (original path, deletion timestamp)
- ✅ Duplicate file handling with numeric suffixes
- ✅ Manual trash management (`--empty`, `--clear <days>`)
- ✅ Show trash directory location (`--dir`)
- ✅ FreeDesktop.org Trash specification compliance
- ✅ Age-based automatic cleanup

### 🚧 Planned Features (In Priority Order)

####  Enhanced Management
- 🚧 `--search <pattern>` - Find specific files in trash by name/pattern
- 🚧 `--rm <pattern>` - Permanently delete specific items from trash
- 🚧 `--size` - Show total size of trash directory

#### Phase 3: Quality of Life
- 🚧 Conflict resolution on restore (rename/skip/overwrite options)
- 🚧 `--dry-run` - Preview operations without executing
- 🚧 Batch operations optimization
- 🚧 Better error messages and user feedback

## 🚀 Installation

### Prerequisites

- Zig 0.15.2 or later

### Building from Source

```bash
git clone https://github.com/yourusername/zrm.git
cd zrm
zig build-exe main.zig -O ReleaseFast
sudo mv zrm /usr/local/bin/
```

### Optional: Create an Alias

For muscle memory convenience, you can alias `rm` to `zrm`, but I **strongly suggest against this**. If you absolutely don't want to use `rm`, I suggest aliasing it to something that reminds you not to:

```bash
# In your ~/.bashrc or ~/.zshrc
alias rm='echo "Use zrm instead, dummy"'
```

### Optional: Automatic Trash Cleanup

Set up a cron job to automatically delete files older than X days:

```bash
# Delete files older than 30 days every day at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * $(which zrm) --clear 30") | crontab -
```

Or using the `@daily` shorthand:

```bash
(crontab -l 2>/dev/null; echo "@daily $(which zrm) --clear 30") | crontab -
```

## 📖 Usage

### Basic Usage

```bash
# Delete a file (moves to trash)
zrm file.txt

# Delete multiple files
zrm file1.txt file2.txt file3.txt

# Delete a directory (recursive)
zrm -r my_directory/

# Delete multiple directories
zrm -r dir1/ dir2/ dir3/
```

### Trash Management

```bash
# View trash directory location
zrm --dir

# Empty entire trash (permanent deletion!)
zrm --empty

# Delete items older than 30 days
zrm --clear 30

# Delete items older than 7 days
zrm --clear 7
```

### File Recovery (Coming Soon)

```bash
# List all files in trash
zrm --list

# Interactive restore menu
zrm --restore

# Restore all files from current directory that don't conflict
zrm --restoreAll

# Search for specific files in trash
zrm --search myfile.txt
```

### Help

```bash
zrm --help
zrm -h
```

## 🗂️ How It Works

### Trash Location

Files are moved to `~/.local/share/Trash/files/` following the [FreeDesktop.org Trash specification](https://specifications.freedesktop.org/trash-spec/trashspec-latest.html).

Metadata is stored in `~/.local/share/Trash/info/` as `.trashinfo` files containing:
- Original file path
- Deletion timestamp (ISO 8601 format)

### Metadata Format

Each deleted file gets a corresponding `.trashinfo` file:

```ini
[Trash Info]
Path=/home/user/documents/important.txt
DeletionDate=2025-10-17T14:30:00
```

### Duplicate Handling

When deleting a file with a name that already exists in trash:

1. **First instance** → `file.txt`
2. **Second instance** → `file.txt_1`
3. **Third instance** → `file.txt_2`
4. And so on...

This prevents trash bloat and maintains all versions of files with the same basename.

## 🤔 Why Zig?

Zig offers several advantages for system utilities:

- **No hidden allocations** - Explicit memory management without garbage collection overhead
- **Compile-time guarantees** - Catch errors before runtime
- **C interop** - Easy integration with system APIs
- **Performance** - Compiles to fast, native code comparable to C
- **Safety** - Built-in error handling and bounds checking
- **Simplicity** - Clear, readable code without C's footguns

This project serves as both a useful tool and a learning exercise in building practical CLI applications with Zig.

## 🏗️ Development Roadmap

###  Enhanced Features (📋 PLANNED)
- [ ] Permanent deletion from trash
- [ ] Trash size reporting
- [ ] Dry run mode
- [ ] Better conflict resolution
- [ ] Progress indicators for large operations

### Milestone 4: Polish & Release (📋 PLANNED)
- [ ] Comprehensive error handling
- [ ] Man page documentation
- [ ] Shell completions (bash, zsh, fish)
- [ ] Binary releases for common platforms
- [ ] Performance benchmarks vs trash-cli or other similar applications

## 🤝 Contributing

Contributions are welcome! This is a learning project, so feel free to:

- Report bugs or issues
- Suggest features or improvements
- Submit pull requests
- Improve documentation
- Share performance insights

Please open an issue before starting work on major features to discuss the approach.

## 📝 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- Inspired by the Rust CLI tools renaissance (`ripgrep`, `bat`, `exa`, `fd`)
- [FreeDesktop.org](https://freedesktop.org/) for the Trash specification
- The Zig community for excellent documentation and support
- [trash-cli](https://github.com/andreafrancia/trash-cli) - The Python implementation that inspired this project

## 🔗 Similar Projects

- [trash-cli](https://github.com/andreafrancia/trash-cli) - Python implementation (what this replaces)
- [trashy](https://github.com/oberblastmeister/trashy) - Rust implementation
- [gio trash](https://developer.gnome.org/gio/stable/gio.html) - GNOME's built-in trash utility

---

**Note:** This is a personal learning project under active development. While functional, always maintain backups of important data. Test thoroughly before using in production environments.
