{ ... }: {
  # Helix setup
  enable = true;

  # Language specific configuration
  languages = {
    language = [
      {
        name = "typst";
        scope = "source.typst";
        injection-regex = "^typ(st)?$";
        file-types = [ "typ" ];
        comment-token = "//";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        roots = [ ];
        # Disabled until some update, broken
        # formatter = { 
        #   command = "typst-fmt";
        #   args = ["/dev/stdin" "-o" "/dev/stdout"];
        # }
        language-server.command = "typst-lsp";
        soft-wrap.enable = true;
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = ''"'';
          "`" = "`";
          "<" = ">";
          "$" = "$";
        };
      }

      {
        name = "nix";
        formatter = { command = "nixfmt"; };
      }

      { name = "rust"; }
    ];

    grammar = [{
      name = "typst";
      source.path = "/home/skylab/.config/helix/tree-sitter-typst";
    }];

    language-server.rust-analyzer = {
      check.command = "clippy";
      cargo.features = "all";
    };
  };

  settings = {
    theme = "catppuccin_mocha";

    editor = {
      line-number = "relative";
      cursorline = true;
      bufferline = "multiple";
      shell = [ "bash" "-l" "-c" ];
      cursor-shape.insert = "bar";
      indent-guides.render = true;
    };

    keys.insert.j.k = "normal_mode";
  };
}
