package = "nvim-config-compare"
version = "0.1.0-1"
source = {
  url = "git+https://github.com/cosmicbuffalo/nvim-config-compare.git"
}
description = {
  summary = "Compare Neovim configs and plugins with Lua",
  detailed = [[
    A CLI and Lua toolkit for comparing Neovim configurations
  ]],
  homepage = "https://github.com/cosmicbuffalo/nvim-config-compare",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1",
  "dkjson"
}
test_dependencies = {
  "busted >= 2.0.0"
}
build = {
  type = "builtin",
  modules = {
    ["nvim_config_compare"] = "lua/nvim_config_compare.lua"
  },
  install = {
    bin = {
      ["nvim-config-compare"] = "bin/nvim-config-compare"
    }
  }
}

