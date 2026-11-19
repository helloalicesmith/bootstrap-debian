return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        win = {
          input = {
            keys = {
              ["<A-q>"] = { "qflist", mode = { "i", "n" } },
            },
          },
          list = {
            keys = {
              ["<A-q>"] = "qflist",
            },
          },
        },
      },
    },
  },
}
