_: {
  # Enable starship prompt, a colorful and informative prompt
  enable = true;

  # Theme
  catppuccin.enable = true;

  # Starship configuration
  settings = {
    # Wait 10 milliseconds for starship to check files
    scan_timeout = 10;

    aws = {
      symbol = "  ";
      format = "[$symbol($profile )(\($region\) )(\[$duration\] )]($style)";
    };

    battery = {
      disabled = true;
    };

    buf = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    bun = {
      format = "[$symbol($version )]($style)";
    };

    c = {
      symbol = " ";
      format = "[$symbol($version(-$name) )]($style)";
    };

    character = {
      success_symbol = "[λ](bold green)";
      error_symbol = "[λ](bold red)";
    };

    cmake = {
      format = "[$symbol($version )]($style)";
    };

    cobol = {
      format = "[$symbol($version )]($style)";
    };

    cmd_duration = {
      disabled = true;
    };

    conda = {
      symbol = " ";
      format = "[$symbol$environment]($style) ";
    };

    container = {
      format = "[$symbol \[$name\]]($style) ";
    };

    crystal = {
      format = "[$symbol($version )]($style)";
    };

    daml = {
      format = "[$symbol($version )]($style)";
    };

    dart = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    deno = {
      format = "[$symbol($version )]($style)";
    };

    directory = {
      read_only = " 󰌾";
      truncation_length = 3;
      # Catppuccin "lavender"
      style = "bold lavender";
    };

    docker_context = {
      symbol = " ";
      format = "[$symbol$context]($style) ";
    };

    dotnet = {
      format = "[$symbol($version )(🎯 $tfm )]($style)";
    };

    elixir = {
      symbol = " ";
      format = "[$symbol($version \(OTP $otp_version\) )]($style)";
    };

    elm = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    env_var = {
      format = "[$env_value]($style) ";
    };

    erlang = {
      format = "[$symbol($version )]($style)";
    };

    fennel = {
      format = "[$symbol($version )]($style)";
    };

    fossil_branch = {
      symbol = " ";
      format = "[$symbol$branch]($style) ";
    };

    gcloud = {
      format = "[$symbol$account(@$domain)(\($region\))]($style) ";
    };

    git_branch = {
      symbol = " ";
      format = "[$symbol$branch(:$remote_branch)]($style) ";
      only_attached = true;
    };

    golang = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    guix_shell = {
      symbol = " ";
      format = "[$symbol]($style) ";
    };

    gradle = {
      format = "[$symbol($version )]($style)";
    };

    haskell = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    haxe = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    helm = {
      format = "[$symbol($version )]($style)";
    };

    hg_branch = {
      symbol = " ";
      format = "[$symbol$branch(:$topic)]($style) ";
      disabled = false;
    };

    hostname = {
      ssh_only = false;
      ssh_symbol = " ";
      format = "[$ssh_symbol$hostname]($style):";
    };

    java = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    julia = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    kotlin = {
      format = "[$symbol($version )]($style)";
    };

    kubernetes = {
      format = "[$symbol$context( \($namespace\))]($style) ";
      disabled = false;
    };

    line_break = {
      disabled = true;
    };

    lua = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    memory_usage = {
      symbol = "󰍛 ";
      format = "$symbol [$ram( \| $swap)]($style) ";
      disabled = true;
    };

    meson = {
      symbol = "󰔷 ";
      format = "[$symbol$project]($style) ";
    };

    nim = {
      symbol = "󰆥 ";
      format = "[$symbol($version )]($style)";
    };

    nix_shell = {
      symbol = " ";
      format = "[$symbol$state]($style) ";
      impure_msg = "i";
      pure_msg = "p";
      unknown_msg = "u";
    };

    nodejs = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    ocaml = {
      format = "[$symbol($version )(\($switch_indicator$switch_name\) )]($style)";
    };

    opa = {
      format = "[$symbol($version )]($style)";
    };

    openstack = {
      format = "[$symbol$cloud(\($project\))]($style) ";
    };

    os = {
      disabled = true;
      symbols = {
        Alpaquita = " ";
        Alpine = " ";
        Amazon = " ";
        Android = " ";
        Arch = " ";
        Artix = " ";
        CentOS = " ";
        Debian = " ";
        DragonFly = " ";
        Emscripten = " ";
        EndeavourOS = " ";
        Fedora = " ";
        FreeBSD = " ";
        Garuda = "󰛓 ";
        Gentoo = " ";
        HardenedBSD = "󰞌 ";
        Illumos = "󰈸 ";
        Linux = " ";
        Mabox = " ";
        Macos = " ";
        Manjaro = " ";
        Mariner = " ";
        MidnightBSD = " ";
        Mint = " ";
        NetBSD = " ";
        NixOS = " ";
        OpenBSD = "󰈺 ";
        openSUSE = " ";
        OracleLinux = "󰌷 ";
        Pop = " ";
        Raspbian = " ";
        Redhat = " ";
        RedHatEnterprise = " ";
        Redox = "󰀘 ";
        Solus = "󰠳 ";
        SUSE = " ";
        Ubuntu = " ";
        Unknown = " ";
        Windows = "󰍲 ";
      };
    };

    package = {
      symbol = "󰏗 ";
      format = "[$symbol$version]($style) ";
    };

    perl = {
      format = "[$symbol($version )]($style)";
    };

    php = {
      format = "[$symbol($version )]($style)";
    };

    pijul_channel = {
      symbol = " ";
      format = "[$symbol$channel]($style) ";
    };

    pulumi = {
      format = "[$symbol($username@)$stack]($style) ";
    };

    purescript = {
      format = "[$symbol($version )]($style)";
    };

    python = {
      symbol = " ";
      format = "[$symbol$pyenv_prefix($version )(\($virtualenv\) )]($style)";
    };

    rlang = {
      symbol = "󰟔 ";
      format = "[$symbol($version )]($style)";
    };

    raku = {
      format = "[$symbol($version-$vm_version )]($style)";
    };

    red = {
      format = "[$symbol($version )]($style)";
    };

    ruby = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    rust = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    scala = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
    };

    spack = {
      symbol = "🅢 ";
      format = "[$symbol$environment]($style) ";
    };

    swift = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };

    terraform = {
      format = "[$symbol$workspace]($style) ";
    };

    time = {
      format = "[$time]($style) ";
    };

    username = {
      format = "[$user]($style)@";
      show_always = true;
    };

    vagrant = {
      format = "[$symbol($version )]($style)";
    };

    vlang = {
      format = "[$symbol($version )]($style)";
    };

    zig = {
      format = "[$symbol($version )]($style)";
    };
  };
}
