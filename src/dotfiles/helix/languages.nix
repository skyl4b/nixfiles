{
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
}
