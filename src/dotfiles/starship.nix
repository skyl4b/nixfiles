{ ... }: {
  enable = true;

  # Starship configuration
  settings = {
    # Set user-defined pallete
    palette = "catppuccin_mocha";

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

    # Palette tables should be last in the config ⚓️
    palettes = {
      catppuccin_macchiato = {
        rosewater = "#f4dbd6";
        flamingo = "#f0c6c6";
        pink = "#f5bde6";
        mauve = "#c6a0f6";
        red = "#ed8796";
        maroon = "#ee99a0";
        peach = "#f5a97f";
        yellow = "#eed49f";
        green = "#a6da95";
        teal = "#8bd5ca";
        sky = "#91d7e3";
        sapphire = "#7dc4e4";
        blue = "#8aadf4";
        lavender = "#b7bdf8";
        text = "#cad3f5";
        subtext1 = "#b8c0e0";
        subtext0 = "#a5adcb";
        overlay2 = "#939ab7";
        overlay1 = "#8087a2";
        overlay0 = "#6e738d";
        surface2 = "#5b6078";
        surface1 = "#494d64";
        surface0 = "#363a4f";
        base = "#24273a";
        mantle = "#1e2030";
        crust = "#181926";
      };

      catppuccin_frappe = {
        rosewater = "#f2d5cf";
        flamingo = "#eebebe";
        pink = "#f4b8e4";
        mauve = "#ca9ee6";
        red = "#e78284";
        maroon = "#ea999c";
        peach = "#ef9f76";
        yellow = "#e5c890";
        green = "#a6d189";
        teal = "#81c8be";
        sky = "#99d1db";
        sapphire = "#85c1dc";
        blue = "#8caaee";
        lavender = "#babbf1";
        text = "#c6d0f5";
        subtext1 = "#b5bfe2";
        subtext0 = "#a5adce";
        overlay2 = "#949cbb";
        overlay1 = "#838ba7";
        overlay0 = "#737994";
        surface2 = "#626880";
        surface1 = "#51576d";
        surface0 = "#414559";
        base = "#303446";
        mantle = "#292c3c";
        crust = "#232634";
      };

      catppuccin_latte = {
        rosewater = "#dc8a78";
        flamingo = "#dd7878";
        pink = "#ea76cb";
        mauve = "#8839ef";
        red = "#d20f39";
        maroon = "#e64553";
        peach = "#fe640b";
        yellow = "#df8e1d";
        green = "#40a02b";
        teal = "#179299";
        sky = "#04a5e5";
        sapphire = "#209fb5";
        blue = "#1e66f5";
        lavender = "#7287fd";
        text = "#4c4f69";
        subtext1 = "#5c5f77";
        subtext0 = "#6c6f85";
        overlay2 = "#7c7f93";
        overlay1 = "#8c8fa1";
        overlay0 = "#9ca0b0";
        surface2 = "#acb0be";
        surface1 = "#bcc0cc";
        surface0 = "#ccd0da";
        base = "#eff1f5";
        mantle = "#e6e9ef";
        crust = "#dce0e8";
      };

      catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };
}
