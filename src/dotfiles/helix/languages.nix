helix:

let
  # Extract the the default configured languages  the `languages.toml` file
  defaultLanguages = (builtins.fromTOML
    (builtins.readFile (helix + "/languages.toml"))).language;

  # Find the language servers configured for each default language
  languagesLsps = builtins.map
    ({ name, language-servers, ... }: {
      inherit name;
      inherit language-servers;
    })
    (builtins.filter (language: builtins.hasAttr "language-servers" language)
      defaultLanguages);

  # `languagesWithGpt` maps over the `languagesLsps` list, appending "gpt" to the `language-servers` list of each language.
  # This effectively adds support for the GPT language server to each language.
  languagesWithGpt = builtins.map
    ({ name, language-servers }: {
      inherit name;
      language-servers = language-servers ++ [
        # TODO: configure efm and perhaps change gpt here
        "gpt"
        # { name = "efm"; only-features = [ "diagnostics" "format" ]; }
      ];
    })
    languagesLsps;

in
{
  # LSPs
  language-server = {
    rust-analyzer = {
      check.command = "clippy";
      cargo.features = "all";
    };

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

    # AI autocompletion
    gpt = {
      command = "bun";
      args = [ "run" "/home/skylab/Apps/helix-gpt/src/app.ts" "--handler" "copilot" ];
    };

    # Universal LSP for linters / formatters
    efm.command = "efm-langserver";

    # Fast python linter
    ruff = {
      command = "ruff-lsp";
      config.settings.args = [
        # Set line length
        "--line-length"
        "79"

        # Enable some ruff rules
        "--select"
        (
          "F,W,E,I,N,D200,D201,D202,D203,D204,D205,D206,D207,D208,D209,D210,D211,"
          + "D212,D213,D214,D215,D300,D301,D400,D401,D402,D403,D404,D405,D406,"
          + "D407,D408,D409,D410,D411,D412,D413,D414,D415,D416,D417,D418,D419,"
          + "UP,YTT,TRIO,ASYNC,B,A,COM,C4,DTZ,T10,DJ,EXE,FA,ISC,ICN001,G010,"
          + "G101,G201,G202,INP,PIE,Q,RSE,RET,SLOT,SIM,TCH,INT,ARG,PTH,TD001,"
          + "TD004,TD005,TD006,TD007,PD,PL,TRY004,TRY200,TRY201,TRY302,TRY400,"
          + "TRY401,FLY,NPY,AIR,PERF,FURB,LOG,RUF"
        )
      ];
    };
  };

  # Languages
  language = languagesWithGpt ++ [
    {
      name = "bash";
      indent = {
        tab-width = 4;
        unit = "    ";
      };
      formatter = {
        command = "shfmt";
        args = [ "-i" "4" ];
      };
    }

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
      language-servers = [ "texlab" "ltex" "gpt" ];
    }

    {
      name = "bibtex";
      indent = {
        tab-width = 2;
        unit = "  ";
      };
    }

    {
      name = "modelica";
      scope = "source.mo";
      file-types = [ "mo" ];
      injection-regex = "modelica";
      comment-token = "//";
      roots = [ ];
      indent = {
        tab-width = 2;
        unit = "  ";
      };
      # Remove trailing space with git
      formatter = {
        command = "git";
        args = [ "stripspace" ];
      };
    }

    {
      name = "yaml";
      formatter = {
        command = "prettier";
        args = [ "--parser" "yaml" ];
      };
    }

    {
      name = "markdown";
      language-servers = [ "marksman" "ltex" "gpt" ];
    }

    {
      name = "nix";
      formatter.command = "nixpkgs-fmt";
    }

    {
      name = "python";
      language-servers = [ "pyright" "ruff" "gpt" ];
      formatter = {
        command = "ruff";
        args = [
          "format"
          "--line-length"
          "79"
          # TODO: add this option when it's ready
          # See: https://github.com/helix-editor/helix/pull/5626
          # "--stdin-filename"
          # "%val{filename}"
          "-"
        ];
      };
      debugger = {
        name = "debugpy";
        transport = "stdio";
        command = "python";
        args = [ "-m" "debugpy.adapter" ];
        templates = [{
          name = "source";
          request = "launch";
          completion = [{
            name = "entrypoint";
            completion = "filename";
            default = ".";
          }];
          args = {
            mode = "debug";
            program = "{0}";
          };
        }];
      };
    }
  ];

  # Grammars
  grammar = [{
    name = "modelica";
    source = {
      git = "https://github.com/OpenModelica/tree-sitter-modelica";
      rev = "695804c544a0c9bb8afc435d59672ec078d64208";
    };
  }];
}
