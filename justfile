#!/usr/bin/env -S just --justfile

set tempdir := "/tmp"

# Keep test state under Pixi unless a writable scratch root is supplied.
export NIXFILES_TEST_ROOT := env("NIXFILES_TEST_ROOT", justfile_directory() / ".pixi/nix-test")
export NIXFILES_CHECKOUT := justfile_directory()
export NIXFILES_STORE := env("NIXFILES_STORE", "auto")

# Choose the recipe to run interactively
_default:
    -@just --choose

import 'src/scripts/nix.just'
import 'src/scripts/install.just'
import 'src/scripts/dotfiles.just'
import 'src/scripts/doom.just'
import 'src/scripts/machine.just'
import 'test/core.just'
import 'test/baseline.just'
import 'test/git.just'
import 'test/terminals.just'
import 'test/yazi-direnv.just'
import 'test/starship-gitui.just'
import 'test/cli-tools.just'
import 'test/desktop-tools.just'
import 'test/input-remapper.just'
import 'test/doom.just'
import 'test/zsh.just'
import 'test/install-workflows.just'
import 'test/workflows.just'
import 'test/portable.just'
import 'test/support.just'
