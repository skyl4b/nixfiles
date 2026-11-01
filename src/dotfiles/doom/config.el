;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-vibrant)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Documents/notes/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Don't ask for confirmation before exiting emacs
(setq confirm-kill-emacs nil)

;; Don't default to system clipboard with evil
(setq select-enable-clipboard nil)

(after! evil
  (evil-define-operator my/clipboard-yank (beg end type)
    "Yank text to the system clipboard."
    (interactive "<R>")
    (evil-yank beg end type ?+))
  ;; Bind SPC + y to clipboard yank
  (map! :leader
        :nv
        :desc "Yank to clipboard"  "y" #'my/clipboard-yank))

;; Keep terminal window title updated
(setq xterm-set-window-title t)

;; Prefer a steady cursor over a blinking one
(setq visible-cursor nil)

;; Evil cursor shapes.
(after! evil
  (setq evil-normal-state-cursor 'box
        evil-insert-state-cursor 'bar
        evil-visual-state-cursor 'box
        evil-emacs-state-cursor 'hbar))

(use-package! evil-terminal-cursor-changer
  :hook (tty-setup . evil-terminal-cursor-changer-activate))

;; Kitty keyboard protocol.
(use-package! kkp
  :hook (tty-setup . global-kkp-mode))

;; Terminal mouse.
(add-hook 'tty-setup-hook #'xterm-mouse-mode)

;; Native TTY child-frame tooltips.
(when (featurep 'tty-child-frames)
  (add-hook 'tty-setup-hook #'tty-tip-mode))

;; Set most colorful mode for syntax highlighting
(after! treesit
  (setq treesit-font-lock-level 4))

;; Configure automatic tree-sitter highlighting for all available languages
(use-package! treesit-auto
  :custom
  (treesit-auto-install t)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

;; Set transparency in the GUI
(when (display-graphic-p)
  (set-frame-parameter nil 'alpha-background 90)
  (add-to-list 'default-frame-alist '(alpha-background . 90)))

;; Set transparency in the Terminal
(unless (display-graphic-p)
  (set-face-background 'default "unspecified-bg"))

;; Set transparency in the ghostel buffer
(after! ghostel
  (add-hook 'ghostel-mode-hook
            (defun my/ghostel-transparent-bg ()
              (unless (display-graphic-p)
                (face-remap-add-relative
                 'default :background "unspecified-bg")))))

;; Show modeline on ghostel buffer (not-popup)
(after! ghostel
  (remove-hook 'ghostel-mode-hook
               #'mode-line-invisible-mode))

;; Enable native tabs globally
(setq tab-bar-show 1)
; Show tab bar only when multiple tabs exist
(tab-bar-mode +1)

;; Move Doom's toggle menu from SPC t to SPC T.
(after! general
  (let ((toggle-map (lookup-key doom-leader-map (kbd "t"))))
    (define-key doom-leader-map (kbd "T") toggle-map)
    (define-key doom-leader-map (kbd "t") nil)))
(after! which-key
  (which-key-add-key-based-replacements
    "SPC T" "toggle"))

;; Tab management (collections of windows).
(map! :leader
  (:prefix ("t" . "tab")
   :desc "Switch tab"   "t" #'tab-switch
   :desc "New tab"      "n" #'tab-new
   :desc "Close tab"    "d" #'tab-close
   :desc "Rename tab"   "r" #'tab-rename
   :desc "Previous tab" "[" #'tab-previous
   :desc "Next tab"     "]" #'tab-next
   :desc "Undo close"   "u" #'tab-undo))
(map! :map evil-motion-state-map ;; Evil-style tab switching
   :after hl-todo
   :desc "Next tab"     "] t" #'tab-next
   :desc "Previous tab" "[ t" #'tab-previous)

;; Enable mouse-wheel scrolling.
(mouse-wheel-mode +1)

;; Enable the kitty graphics protocol.
(use-package! kitty-graphics
  :defer t)

;; HACK: conflict with kkp initialization
(after! kkp
  (add-hook 'kkp-terminal-setup-complete-hook
            (lambda ()
              (unless (display-graphic-p)
                (require 'kitty-graphics)
                (kitty-graphics-setup)
                ;; HACK: conflict with dashboard initialization
                (run-with-idle-timer
                 0.005 nil #'redraw-display)))))

;; Chess bindings
(after! chess-display
  (set-keymap-parent
   (evil-get-auxiliary-keymap
    chess-display-mode-map 'normal t)
   chess-display-mode-map)

  (map! :map chess-display-mode-map
        :n "/" #'chess-display-pass))

;; Make C-x passthrough to the terminal.
(after! evil-ghostel
  (evil-define-key* 'insert evil-ghostel-mode-map
    (kbd "C-x")
    (lambda ()
      (interactive)
      (ghostel-send-key "x" "ctrl"))))
