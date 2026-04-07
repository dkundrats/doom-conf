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
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


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

;; --- LSP Mode ---
(after! lsp-mode
  (setq lsp-rust-analyzer-cargo-watch-command "clippy"
        lsp-eldoc-render-all t
        lsp-idle-delay 0.6
        lsp-response-timeout 30
        lsp-inlay-hint-enable t
        lsp-rust-analyzer-display-lifetime-elision-hints-enable "skip_trivial"
        lsp-rust-analyzer-display-chaining-hints t
        lsp-rust-analyzer-display-lifetime-elision-hints-use-parameter-names nil
        lsp-rust-analyzer-display-closure-return-type-hints t
        lsp-rust-analyzer-display-parameter-hints nil
        lsp-disabled-clients '(jedi)))

(after! lsp-ui
  (setq lsp-ui-doc-enable t
        lsp-ui-doc-position 'at-point
        lsp-ui-sideline-enable t))

;; --- Python (basedpyright) ---
(after! lsp-pyright
  (setq lsp-pyright-langserver-command "basedpyright"
        lsp-pyright-typechecking-mode "basic"
        lsp-pyright-multi-root nil
        lsp-pyright-use-library-code-for-types t
        lsp-pyright-venv-path nil))

;; --- Rust ---
(setq rustic-cargo-bin "~/.cargo/bin/cargo")
(after! rustic
  (setq rustic-analyzer-command '("rust-analyzer")))

;; Disable flycheck in rust-mode (rely on rust-analyzer diagnostics)
(add-hook 'rustic-mode-hook (lambda () (flycheck-mode -1)))

;; --- Direnv integration ---
(after! direnv
  (setq direnv-always-show-summary nil))

;; --- LSP helper functions ---
(defun my/restart-lsp-with-current-env ()
  "Kill LSP session and restart with current environment."
  (interactive)
  (when lsp-mode
    (lsp-workspace-shutdown (lsp-workspaces))
    (lsp)))

(defun my/lsp-reset-python-env ()
  "Force reset of Python LSP with current environment."
  (interactive)
  (direnv-update-directory-environment)
  (lsp-restart-workspace))

;; --- Keybindings ---
(map! :leader
      :desc "Reset Python LSP env" "c r" #'my/lsp-reset-python-env
      :desc "LSP describe at point" "c d" #'lsp-describe-thing-at-point
      :desc "Eldoc buffer"          "c e" #'eldoc-doc-buffer)

;; Folding in python
(add-hook 'python-mode-hook #'hs-minor-mode)

;; Tramp
(after! tramp
  (setq tramp-default-method "ssh"))

;; --- Disable everything noisy for remote buffers ---
;; Prevents the reentrant TRAMP freeze. No LSP, no flycheck, no format, no
;; vc, no projectile, no direnv. Just plain editing.
(defun my/tramp-quiet-hooks ()
  "Disable noisy minor modes in remote buffers."
  (when (file-remote-p default-directory)
    (setq-local vc-handled-backends nil)
    (setq-local flycheck-checker nil)
    (flycheck-mode -1)
    (setq-local +format-with nil)
    (remove-hook 'before-save-hook #'+format-buffer-h t)))
(add-hook 'find-file-hook #'my/tramp-quiet-hooks -90)

(defadvice! my/no-lsp-remote-a (orig-fn &rest args)
  :around #'lsp
  (unless (file-remote-p default-directory)
    (apply orig-fn args)))

(defadvice! my/no-projectile-remote-a (orig-fn &rest args)
  :around #'projectile-project-root
  (unless (file-remote-p default-directory)
    (apply orig-fn args)))

(defadvice! my/no-direnv-remote-a (orig-fn &rest args)
  :around #'direnv-update-directory-environment
  (unless (file-remote-p default-directory)
    (apply orig-fn args)))

(defadvice! my/no-rustic-flycheck-remote-a (orig-fn &rest args)
  :around #'rustic-flycheck-setup
  (unless (file-remote-p default-directory)
    (apply orig-fn args)))

;; Vterm
(map! "C-c v" (cmd! (vterm (generate-new-buffer-name "*vterm*"))))
(set-popup-rule! "^\\*vterm" :ignore t)
(after! vterm
  (define-key vterm-mode-map (kbd "C-x o") #'other-window))