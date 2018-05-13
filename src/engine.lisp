(in-package :fl.core)

(defun prepare-engine (package)
  (let ((*package* (find-package :fl.core))
        (core-state (make-core-state :user-package package)))
    (prepare-extensions core-state (get-extension-path package))
    (load-default-scene core-state)
    (make-display core-state)
    (prepare-shader-programs core-state)
    (resolve-all-textures core-state)
    (resolve-all-materials core-state)
    core-state))

(defun start-engine (&optional override-scene)
  (let ((user-package-name (au:make-keyword (package-name *package*))))
    (when (eq user-package-name :fl.core)
      (error "Cannot start the engine from the :FL.CORE package."))
    (kit.sdl2:init)
    (prog1 (sdl2:in-main-thread ()
             (let ((*override-scene* override-scene))
               (prepare-engine user-package-name)))
      (kit.sdl2:start))))

(defun stop-engine (core-state)
  (with-cfg (title) (context core-state)
    (quit-display (display core-state))
    (simple-logger:emit :engine.quit title)))

#+sbcl
(defmacro profile (seconds)
  `(progn
     (let ((display (display (start-engine))))
       (sb-profile:unprofile)
       (sb-profile:profile
        "FIRST-LIGHT"
        "FIRST-LIGHT-EXAMPLE"
	"FL.COMP.TRANSFORM"
	"FL.COMP.CAMERA"
	"FL.COMP.FOLLOWING-CAMERA"
	"FL.COMP.TRACKING-CAMERA"
	"FL.COMP.MESH"
	"FL.COMP.MESH-RENDERER"
	"FL.SHADERS"
	"FL.MATERIALS"
	"FL.TEXTURES"
        "BOX.FRAME")
       (sleep ,seconds)
       (sb-profile:report)
       (sb-profile:unprofile)
       (sb-profile:reset)
       (stop-engine (core-state display)))))
