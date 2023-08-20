{ inputs }: {
  # Helix setup
  enable = true;

  # Set helix git package
  package = inputs.helix-git.packages.${inputs.pkgs.system}.default;

  # Language specific configuration
  languages = {
    # LSPs
    language-server = {
      rust-analyzer = {
        check.command = "clippy";
        cargo.features = "all";
      };

      typst-lsp.command = "typst-lsp";

      ltex = {
        command = "ltex-ls";
        args = [ "--log-file=/dev/null" ];
        config.ltex = {
          enabled = true;
          completionEnabled = true;
          language = "en-US";
          ltex-ls = {
            path = "ltex-ls";
            logLevel = "warning";
          };
          additionalRules = {
            enablePickyRules = true;
            motherTongue = "pt-BR";
          };
        };
      };

      texlab.config.texlab = {
        build = {
          executable = "latexmk";
          args = [
            "-cd"
            "-shell-escape"
            "-pdf"
            "-interaction=nonstopmode"
            "-synctex=1"
            "-auxdir=out"
            "-outdir=out"
            "%f"
          ];
          auxDirectory = "out";
          logDirectory = "out";
          pdfDirectory = "out";
          forwardSearchAfter = true;
          onSave = true;
        };
        chktex.onEdit = true;
        forwardSearch = {
          executable = "zathura";
          args = [ "--synctex-forward" "%l:1:%f" "%p" ];
        };
      };
    };

    # Languages
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
        language-servers = [ "typst-lsp" ];
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
          command = "latexindent";
          args = [ "-l" "-g" "/dev/null" "-m" "-" ];
        };
        language-servers = [ "texlab" "ltex" ];
      }

      {
        name = "bibtex";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
      }
    ];

    # Grammars
    grammar = [{
      name = "typst";
      source.path = "/home/skylab/.config/helix/tree-sitter-typst";
    }];
  };

  settings = {
    theme = "catppuccin_transparent";

    editor = {
      bufferline = "multiple";
      color-modes = true;
      cursor-shape.insert = "bar";
      cursorline = true;
      indent-guides.render = true;
      line-number = "relative";
      lsp = {
        display-inlay-hints = true;
        display-messages = false;
      };
      shell = [ "bash" "-l" "-c" ];
      soft-wrap.enable = true;
    };

    keys.normal = {
      V = "select_mode";
      C-h = "move_char_left";
      C-l = "move_char_right";
      C-s = [ "save_selection" ":w" ];
      Z.Z = ":wq";
      "#" = "toggle_comments";

      # Jumplist manipulation
      "'" = {
        a = [ "save_selection" ];
        n = [ "jump_forward" ];
        p = [ "jump_backward" ];
        j = [ "jumplist_picker" ];
      };
    };
    keys.insert = {
      j.k = "normal_mode";
      C-h = "move_char_left";
      C-l = "move_char_right";
      C-s = [ "save_selection" ":w" ];
    };
  };

  # Custom theme
  themes.catppuccin_transparent = {
    inherits = "catppuccin_mocha";
    "ui.background" = { };
  };
}
