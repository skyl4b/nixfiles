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
    file-picker.hidden = false;
    shell = [ "bash" "-l" "-c" ];
    soft-wrap.enable = true;
  };

  keys.normal = {
    V = [ "extend_to_line_bounds" "select_mode" ];
    C-h = "move_char_left";
    C-l = "move_char_right";
    C-s = [ "save_selection" ":w" ];
    Z.Z = ":wq";
    "#" = "toggle_comments";

    # Force empty line single selection
    x = [ "extend_to_line_bounds" "select_mode" ];

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
    ret = [ "insert_newline" "commit_undo_checkpoint" ];
  };
  keys.select = {
    x = [ "extend_line" ];
    ";" = [ "collapse_selection" "normal_mode" ];
    "#" = "toggle_comments";
  };
}
