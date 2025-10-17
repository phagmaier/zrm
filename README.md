# Trash - A Safe File Deletion Utility

A modern replacement for `rm` written in Zig that moves files to trash instead of permanently deleting them, giving you a safety net for accidental deletions.

## 🎯 Project Goals

Inspired by the Rust community's movement to rewrite classic Unix utilities with modern safety features (like `ripgrep`, `exa`, `bat`), this project aims to bring similar improvements to the Zig ecosystem. The goal is to create a fast, safe, and user-friendly alternative to `rm` that prevents the all-too-common "oh no, I just deleted that" moment.

## ⚠️ Development Status

**This project is currently in active development.** Core functionality is working, but some features are still being implemented.

### ✅ Implemented Features

- ✅ Move files to trash instead of permanent deletion
- ✅ Recursive directory deletion (`-r` flag)
- ✅ Metadata tracking (original path, deletion timestamp)
- ✅ Smart conflict resolution (replaces files from same location)
- ✅ Manual trash management (`--empty`, `--clear <days>`)
- ✅ FreeDesktop.org Trash specification compliance

### 🚧 In Progress / Planned Features

- 🚧 `--restore` - Interactive restore of deleted files
- 🚧 `--restoreAll` - Restore all files from current directory

## 🚀 Installation

### Prerequisites

- Zig 0.15.0 or later

### Building from Source

```bash
git clone https://github.com/yourusername/trash.git
cd trash
zig build-exe main.zig -O ReleaseFast
sudo mv trash /usr/local/bin/
```

### Optional: Create an Alias

For muscle memory convenience, you can alias `rm` to `zrm` but I **strongly suggest against this**. If you don't want to use rm I suggest aliasing it to something that tells you not to use it.:

### Optional: Auto delete everything older than X days in the trash:
I sugest using crontab 
Once I get everything set up I will test it out and place the exact command here.
Trash cli recomends the following:

```bash
(crontab -l ; echo "@daily $(which trash-empty) 30") | crontab -
```


## 📖 Usage

### Basic Usage

```bash
# Delete a file (moves to trash)
trash file.txt

# Delete multiple files
trash file1.txt file2.txt file3.txt

# Delete a directory (recursive)
trash -r my_directory/
```

### Trash Management

```bash
# View trash directory location
trash --dir

# Empty entire trash
trash --empty

# Delete items older than 30 days
trash --clear 30

# Delete items older than 7 days
trash --clear 7
```

### Help

```bash
trash --help
```

## 🗂️ How It Works

### Trash Location

Files are moved to `~/.local/share/Trash/files/` following the [FreeDesktop.org Trash specification](https://specifications.freedesktop.org/trash-spec/trashspec-latest.html). 
Meta data is moved to `~/.local/share/Trash/info/`. If you renamed a directory and need to manually restore I suggest looking 
through the meta data to ensure you are recovering the correct file and I also suggest you delete the meta data file 
after you move it. Will also impliment a force restore where you can specify the exact file you want back even if it doesn't 
match that way we can do the cleanup for you

### Metadata

For each deleted file, a `.trashinfo` metadata file is created and as it said above we are compliant with the speccification provided by the [FreeDesktop.org Trash specification](https://specifications.freedesktop.org/trash-spec/trashspec-latest.html). 

### Conflict Resolution

When deleting a file that already exists in trash:

1. **Same file from same location** → Old version is replaced
2. **Different file with same name** → Timestamp is appended (e.g., `file.txt.1729095234`)

This prevents trash bloat from repeatedly deleting and re-creating the same files during development.

## 🤔 Why Zig?

Zig offers several advantages for system utilities:

- **No hidden allocations** - Explicit memory management without garbage collection overhead
- **Compile-time guarantees** - Catch errors before runtime
- **C interop** - Easy integration with system APIs
- **Performance** - Compiles to fast, native code
- **Safety** - Built-in error handling and bounds checking

This project serves as both a useful tool and a learning exercise in building practical CLI applications with Zig.

## 🤝 Contributing

Contributions are welcome! This is a learning project, so feel free to:

- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

Please open an issue before starting work on major features.

## 📝 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- Inspired by the Rust CLI tools renaissance
- FreeDesktop.org for the Trash specification
- The Zig community for excellent documentation and support
- [trash-cli](https://github.com/andreafrancia/trash-cli) was the major inspiration it was what I personally used as my rm until I wrote this

---

**Note:** This is a personal project under active development. Use at your own risk and always maintain backups of important data.
