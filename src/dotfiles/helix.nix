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

      {
        name = "latex";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        formatter = {
          command = "latexindent -l main.tex -o main_f.tex";
          args = [ "-s" "-l" "-g" "/dev/null" "-m" "–GCString" "-" ];
        };
      }

      {
        name = "bibtex";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
      }
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
      soft-wrap.enable = true;
    };

    keys.normal.V = "select_mode";
    keys.insert.j.k = "normal_mode";
  };
}
