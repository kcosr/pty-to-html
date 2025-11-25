# pty-to-html

Convert raw PTY (pseudo-terminal) log files to styled HTML output using [Ghostty's](https://github.com/ghostty-org/ghostty) terminal emulation library.

This tool parses terminal escape sequences (ANSI colors, styles, cursor movements, etc.) and renders the final terminal state as HTML with proper styling.

## Features

- Full terminal emulation using Ghostty's VT parser
- Supports ANSI colors (16, 256, and true color)
- Handles cursor movements, scrolling, and line editing
- Configurable terminal dimensions
- Output as HTML fragment or full HTML document
- Reads from file or stdin
- Fast processing

## Requirements

- **Zig 0.15.2** (required by Ghostty)
- **Ghostty source code** (for the `ghostty-vt` library)
- Linux, macOS, or Windows

## Quick Setup

Note: The setup and installation steps below reflect the original developer
environment (Linux/macOS with no Zig installed). If you already have Zig
0.15.2 and Ghostty available via your own toolchain or package manager, you
can use those instead and may not need to follow these steps exactly.

Run the automated setup script:

```bash
./setup.sh
```

This will:
1. Download and install Zig 0.15.2
2. Clone the Ghostty repository
3. Build pty-to-html in release mode

## Manual Setup

### 1. Install Zig 0.15.2

Ghostty requires Zig 0.15.2. Download and install it:

```bash
# Linux x86_64
curl -LO https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz
tar xf zig-x86_64-linux-0.15.2.tar.xz
sudo mv zig-x86_64-linux-0.15.2 /opt/zig
sudo ln -sf /opt/zig/zig /usr/local/bin/zig

# macOS ARM64
curl -LO https://ziglang.org/download/0.15.2/zig-macos-aarch64-0.15.2.tar.xz
tar xf zig-macos-aarch64-0.15.2.tar.xz
sudo mv zig-macos-aarch64-0.15.2 /opt/zig
sudo ln -sf /opt/zig/zig /usr/local/bin/zig

# macOS x86_64
curl -LO https://ziglang.org/download/0.15.2/zig-macos-x86_64-0.15.2.tar.xz
tar xf zig-macos-x86_64-0.15.2.tar.xz
sudo mv zig-macos-x86_64-0.15.2 /opt/zig
sudo ln -sf /opt/zig/zig /usr/local/bin/zig
```

Verify installation:
```bash
zig version  # Should output: 0.15.2
```

### 2. Clone Ghostty

Clone the Ghostty repository adjacent to this project:

```bash
cd ..
git clone https://github.com/ghostty-org/ghostty.git
cd pty-to-html
```

Your directory structure should look like:
```
parent-dir/
├── ghostty/
└── pty-to-html/
```

### 3. Build

Build in release mode for optimal performance:

```bash
zig build -Doptimize=ReleaseFast
```

The binary will be at `zig-out/bin/pty-to-html`.

## Usage

```
Usage: pty-to-html [OPTIONS] [FILE]

Convert a raw PTY log file to HTML with styled terminal output.

If FILE is not provided, reads from stdin.

Options:
  -c, --cols N         Terminal width in columns (default: 120)
  -r, --rows N         Terminal height in rows (default: 40)
  -o, --output FILE    Write output to FILE instead of stdout
  --full               Output a full HTML document (with <html>, <head>, etc.)
  --unwrap             Unwrap soft-wrapped lines
  --no-trim            Don't trim trailing whitespace
  --bg COLOR           Background color (hex, e.g., #1e1e1e)
  --fg COLOR           Foreground color (hex, e.g., #d4d4d4)
  --inline-colors      Emit colors as RGB instead of CSS variables
  --no-palette         Don't emit CSS palette variables
  -h, --help           Show this help message
```

### Examples

Basic conversion (outputs HTML fragment to stdout):
```bash
./zig-out/bin/pty-to-html session.log
```

Specify terminal dimensions:
```bash
./zig-out/bin/pty-to-html -c 80 -r 24 session.log
```

Generate a full HTML document:
```bash
./zig-out/bin/pty-to-html --full -o output.html session.log
```

Read from stdin:
```bash
cat session.log | ./zig-out/bin/pty-to-html --full > output.html
```

Process with custom dimensions and save to file:
```bash
./zig-out/bin/pty-to-html -c 132 -r 50 --full -o wide.html session.log
```

## How It Works

1. **Terminal Emulation**: Creates a virtual terminal with specified dimensions using Ghostty's `ghostty-vt` library
2. **VT Stream Processing**: Parses the raw PTY data through the terminal's VT stream, interpreting all escape sequences
3. **State Capture**: After processing, the terminal contains the final rendered state
4. **HTML Generation**: Uses Ghostty's `TerminalFormatter` to convert the terminal state to styled HTML with proper color support

## Recording PTY Sessions

To create PTY logs for conversion, you can use tools like:

- **script**: `script -q session.log` (records raw terminal output)
- **ttyrec**: Records terminal sessions in ttyrec format
- **asciinema**: Can export raw recordings

Note: This tool expects raw PTY output (the actual bytes sent to the terminal), not formatted recordings.

## Troubleshooting

### Linker errors with ubsan

If you see errors like:
```
error: lld-link: undefined symbol: __ubsan_handle_type_mismatch_v1
```

Make sure you have checked out the most recent version of ghostty.

### Slow performance

Ensure you're building with optimization:
```bash
zig build -Doptimize=ReleaseFast
```

Debug builds are significantly slower due to the terminal emulation complexity.

### Wrong Zig version

Ghostty requires Zig 0.15.2. Other versions may not work:
```bash
zig version  # Must be 0.15.2
```

## Development & Testing

- Build in debug mode:
  - `zig build`
- Build in release mode:
  - `zig build -Doptimize=ReleaseFast`
- Run the test suite (uses Zig's built-in `test` framework):
  - `zig build test`

## Project Structure

```
pty-to-html/
├── AGENTS.md        # Instructions for agents working with this codebase
├── build.zig        # Zig build configuration
├── build.zig.zon    # Package manifest (references ghostty)
├── LICENSE          # License
└── README.md        # This file
├── setup.sh         # Automated setup script
├── src
│   └── main.zig     # Main application
└── testdata         # Test input data
    └── session.log
```

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [Ghostty](https://github.com/ghostty-org/ghostty) - Terminal emulator providing the VT parsing library
- [Zig](https://ziglang.org/) - Programming language and build system
