let
  # Git filtering excludes Pixi and scratch data; encode checkout paths for URI use.
  checkout = builtins.replaceStrings
    [ "%" " " "#" "?" ] [ "%25" "%20" "%23" "%3F" ]
    (toString ../..);
in
(builtins.getFlake "git+file://${checkout}").inputs
