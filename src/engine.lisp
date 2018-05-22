(in-package :fl.core)

;; This is a toplevel variable that is treated as a true global, rather than a special variable.
;; NOTE; This is purely used for debugging, and should definitely not be used for user code or
;; running multiple core-state objects.
(defvar *core-state*)

(defun run-prologue (core-state)
  "The prologue is a function defined in the user's project, that if it exists, is called before any
setup procedure occurs when starting the engine."
  (let ((prologue-func (au:ensure-symbol 'prologue (user-package core-state))))
    (when (fboundp prologue-func)
      (setf (state (context core-state)) (funcall prologue-func (context core-state))))))

(defun run-epilogue (core-state)
  "The epilogue is a function defined in the user's project, that if it exists, is called before any
tear-down procedure occurs when stopping the engine."
  (let ((epilogue-func (au:ensure-symbol 'epilogue (user-package core-state))))
    (when (fboundp epilogue-func)
      (funcall epilogue-func (context core-state)))))

(defun prepare-engine (scene-name)
  "Bring up the engine on the main thread, while keeping the REPL unblocked for interactive
development."
  (sdl2:in-main-thread ()
    (let* ((*package* (find-package :fl.core))
           (user-package (au:make-keyword (package-name (symbol-package scene-name))))
           (core-state (make-core-state :default-scene scene-name :user-package user-package)))
      (prepare-extensions core-state (get-extension-path user-package))
      (load-scene core-state scene-name)
      (make-display core-state)
      (prepare-shader-programs core-state)
      (resolve-all-textures core-state)
      (resolve-all-materials core-state)
      (run-prologue core-state)
      core-state)))

(defun start-engine (scene-name)
  "Start the engine by running the specified scene."
  (kit.sdl2:init)
  (kit.sdl2:start)
  (setf *core-state* (prepare-engine scene-name)))

(defun stop-engine (core-state)
  "Stop the engine, making sure to call any user-define epilogue function first, and finally
cleaning up."
  (unwind-protect
       (with-cfg (title) (context core-state)
         (run-epilogue core-state)
         (quit-display (display core-state))
         (simple-logger:emit :engine.quit title))
    (makunbound '*core-state*)))

#+sbcl
(defmacro profile (scene-name duration)
  "Profile the scene `SCENE-NAME` for the given `DURATION` in seconds, all packages that begin with
  'FL.', along with some key third-party library packages."
  (let ((packages (remove-if-not
                   (lambda (x) (au:string-starts-with? x "FL."))
                   (mapcar #'package-name (list-all-packages)))))
    `(let ((engine (start-engine ,scene-name)))
       (sb-profile:unprofile)
       (sb-profile:profile ,@packages "AU" "BOX.FRAME" "SHADOW" "CL-OPENGL")
       (sleep ,duration)
       (sb-profile:report)
       (sb-profile:unprofile)
       (sb-profile:reset)
       (stop-engine engine))))
