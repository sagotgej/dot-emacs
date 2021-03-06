;;; My helper/useful functions

(defun python-shell-restart ()
  (interactive)
  (let ((buffer-process)
	(buffer-beginning (current-buffer))
	(window-beginning (selected-window)))
    (switch-to-buffer "*Python*")
    (setq buffer-process (get-buffer-process (current-buffer)))
    (if buffer-process (set-process-query-on-exit-flag buffer-process nil))
    (kill-buffer "*Python*")
    (run-python)
    (switch-to-buffer "*Python*")
    (setq buffer-process (get-buffer-process (current-buffer)))
    (set-process-query-on-exit-flag buffer-process t)
    ;; Rearanging windows
    (select-window window-beginning)
    (switch-to-buffer buffer-beginning)
    ;; Opening python in other window if there is one
    (my-open-buffer-split-below "*Python*")
    (select-window window-beginning)
    (switch-to-buffer buffer-beginning)))

(defun my-open-buffer-split-below (buffer)
  (let ((window-beginning (selected-window)))
    (if (= (count-windows) 1)
	(split-window-below))
    (other-window 1)
    (switch-to-buffer buffer)
    (select-window window-beginning)))
  
(defun pwd-kill ()
  "Add the current directory to kill ring."
  (interactive)
  (message (expand-file-name default-directory))
  (kill-new (expand-file-name default-directory)))

(defun python-copy-next-docstring ()
  "Copy next Python docstring."
  (interactive)
  (let (beg-docstring end-docstring)
    (save-excursion
      (search-forward "\"\"\"")
      (move-beginning-of-line nil)
      (setq beg-docstring (point))
      (search-forward "\"\"\"" nil nil 2)
      (forward-line)
      (move-beginning-of-line nil)
      (setq end-docstring (point)))
    (kill-ring-save beg-docstring end-docstring)))

(defun pytest-command-at-point ()
  (interactive)
  (let* ((function-name (symbol-name (symbol-at-point)))
	(command (concat "pytest " buffer-file-name "::" function-name)))
    (if (get-buffer "*pytest-shell*")
	(progn
	  (my-open-buffer-split-below "*pytest-shell*")
	  (other-window 1)
	  (switch-to-buffer "*pytest-shell*")
	  (insert command)
	  (comint-send-input))
      (shell-command (concat "pytest " buffer-file-name "::" function-name)))))


(defun kill-ring-save-up-to-char (arg char)
  (interactive "p\ncSave up to char: ")
  (barf-if-buffer-read-only)
  (let ((buffer-modified (buffer-modified-p)))
    (save-excursion
      (zap-up-to-char arg char)
      (yank)
      (restore-buffer-modified-p buffer-modified))))

(defun my/display-line-length ()
  (interactive)
  (message (number-to-string (- (line-end-position) (line-beginning-position)))))

(defun my-transpose-tuple (str)
  "Transpose a Python tuple. The input string should look like \"(1, 1.02, variable)\"."
  (when (not (char-equal ?\( (aref str 0)))
    (error "Error in tuple format: %c instead of ( at str pos 0" (aref str 0)))
  (when (not (char-equal ?\) (aref str (- (length str) 1))))
    (error "Error in tuple format: %c instead of ) at str pos -1" (aref str (- (length str) 1))))
  (let (tuple-words tuple-words-trim res)
    (setq tuple-words (split-string (substring str 1 -1) ","))
    (dolist (it tuple-words tuple-words-trim)
      (setq tuple-words-trim (append tuple-words-trim `(,(string-trim it)))))
    (setq tuple-words (reverse tuple-words-trim))
    (setq res "(")
    (dolist (it tuple-words res)
      (when (char-equal ?\( (aref it 0))
	(error "Error: nested tuple transposition is not supported"))
      (setq res (concat res it ", ")))
    (setq res (substring res 0 -2))
    (concat res ")")))

(defun my-transpose-tuple-at-point ()
  "Transpose a Python tuple at point. The point should be inside of a Python tuple."
  (interactive)
  (let (init-point point-tuple-beg point-tuple-end tuple)
    (setq init-point (point))
    (re-search-backward "(")
    (setq point-tuple-beg (point))
    (re-search-forward ")")
    (setq point-tuple-end (point))
    (setq tuple (buffer-substring-no-properties point-tuple-beg point-tuple-end))
    (setq tuple (my-transpose-tuple tuple))
    (delete-region point-tuple-beg point-tuple-end)
    (insert tuple)
    (set-window-point (selected-window) init-point))
  nil)

(defun yank-with-indent (&optional indent-length)
  "Yank text with indent-length spaces or with the current indent line before point."
  (interactive "P")
  (let (indent bound)
    (if indent-length
	(progn (setq indent (make-string indent-length ? ))
		     (insert indent))
      (setq indent (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
    (yank)
    (setq bound (point))
    (pop-to-mark-command)
    (while (search-forward "\n" bound t)
      (progn (replace-match (concat "\n" indent))
	     (setq bound (+ bound (length indent))))))
  (if indent-length (backward-delete-char indent-length)))

(defun my-dot-py-buffers ()
  "Returns a list of already opened buffers ending with .py"
  (let (py-buffers)
  (dolist (it (buffer-list))
    (if (string-match-p "\\.py$" (buffer-name it))
	(setq py-buffers (append (cons it nil) py-buffers))))
  py-buffers))

(defun my-blacken-dot-py-buffers ()
  "Blacken already opened buffers ending with .py"
  (interactive)
  (dolist (it (my-dot-py-buffers))
    (with-current-buffer it
      (blacken-buffer t)
      (message (concat "Blackened buffer " (buffer-name it)))))
  (message (concat "Blackened " (int-to-string (length (my-dot-py-buffers))) " buffer(s)")))

(defun my-pytest-redo ()
  (interactive)
  (if (not (string-equal "*pytest-shell*" (buffer-name (current-buffer))))
      (progn (my-open-buffer-split-below (current-buffer))
	     (other-window 1)
	     (switch-to-buffer "*pytest-shell*")))
  (if (not (string-equal "shell-mode" major-mode))
      (shell (current-buffer)))
  (goto-char (point-max))
  (comint-previous-matching-input "^pytest" 1)
  (comint-send-input))

(defun my-compile-elisp-code ()
  "Compiles my custom elisp code"
  (interactive)
  (byte-compile-file "~/.emacs.d/init.el")
  (byte-recompile-directory (expand-file-name "~/.emacs.d/src") 0)
  (dolist (it (file-expand-wildcards "~/.emacs.d/src/*.el"))
  (byte-compile-file it)))

(defun my-balance-if-larger-than-half ()
  "Balance the current window if its height is larger than half of the frame"
  (if (= (/ (frame-height) (window-height)) 1)
      (balance-windows)))

(provide 'my-helpers)
