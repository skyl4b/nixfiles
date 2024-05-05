{
  theme = "catppuccin_transparent";

  editor = {
    auto-format = false;
    bufferline = "multiple";
    color-modes = true;
    cursor-shape.insert = "bar";
    cursorline = true;
    indent-guides.render = true;
    insert-final-newline = true;
    line-number = "relative";
    lsp = {
      display-inlay-hints = true;
      display-messages = false;
    };
    true-color = true;
    file-picker = {
      hidden = false;
      git-ignore = false;
    };
    shell = [ "bash" "-l" "-c" ];
    soft-wrap.enable = true;
  };

  keys.normal = {
    V = [ "extend_to_line_bounds" "select_mode" ];
    C-h = "move_char_left";
    C-l = "move_char_right";
    C-s = [ "save_selection" ":w" ];
    Z.Z = ":wq";

    # Force empty line single selection
    x = [ "extend_to_line_bounds" "select_mode" ];

    # Jumplist manipulation
    "'" = {
      a = [ "save_selection" ];
      n = [ "jump_forward" ];
      p = [ "jump_backward" ];
      j = [ "jumplist_picker" ];
    };

    # Smart tab extras
    tab = "move_parent_node_end";
    S-tab = "move_parent_node_start";
  };

  keys.insert = {
    j.k = "normal_mode";
    C-h = "move_char_left";
    C-l = "move_char_right";
    C-s = [ "save_selection" ":w" ];
    ret = [ "insert_newline" "commit_undo_checkpoint" ];

    # Smart tab extras
    S-tab = "move_parent_node_start";
  };

  keys.select = {
    x = [ "extend_line" ];
    ";" = [ "collapse_selection" "normal_mode" ];

    # Smart tab extras
    tab = "extend_parent_node_end";
    S-tab = "extend_parent_node_start";
  };
}
