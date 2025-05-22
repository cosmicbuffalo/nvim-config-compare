# nvim-config-compare

A CLI and Lua toolkit for comparing Neovim configurations

---

## Installation

### Using LuaRocks

```bash
luarocks install nvim-config-compare
```

### Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/cosmicbuffalo/nvim-config-compare.git
   cd nvim-config-compare
   ```

2. Install dependencies:
   ```bash
   luarocks install dkjson
   npm install -g json-diff
   ```

3. Install the package:
   ```bash
   luarocks make
   ```

---

## Usage

### Comparing Two Neovim Configurations

```bash
nvim-config-compare config1 config2 -o output_dir
```

Where:
- `config1` and `config2` are the names of your Neovim configurations (NVIM_APPNAME values)
- `-o output_dir` (optional) specifies where to save the output files (defaults to "output")

### Dumping a Single Configuration

```bash
nvim-config-compare config1
```

This will dump the configuration to a JSON file without comparing.

### Output

The tool generates:
- JSON files for each configuration
- A diff file showing the differences
- A summary of plugin and keymap differences in the terminal

---

## Requirements

- [json-diff](https://www.npmjs.com/package/json-diff) (`npm install -g json-diff`)
- Lua 5.1+ and [dkjson](https://github.com/LuaDist/dkjson)
- Neovim with the lazy.nvim plugin manager

