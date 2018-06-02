(in-package :fl.core)

(defmethod extension-file-type ((extension-type (eql 'shader-stages)))
  "shd")

(defmethod prepare-extension ((extension-type (eql 'shader-stages)) owner path)
  (load-extensions extension-type path))

(defmethod extension-file-type ((extension-type (eql 'shader-programs)))
  "prog")

(defmethod prepare-extension ((extension-type (eql 'shader-programs)) owner path)
  (shadow:reset-program-state)
  (load-extensions extension-type path))

(defun shaders-modified-hook (programs-list)
  (when (boundp '*core-state*)
    (shadow:translate-shader-programs programs-list)
    (sdl2:in-main-thread ()
      (shadow:build-shader-programs programs-list))
    (when programs-list
      (simple-logger:emit :shader.programs.updated programs-list))))

(defun prepare-shader-programs (core-state)
  (setf (shaders core-state) (shadow:build-shader-dictionary))
  (shadow:set-modify-hook #'shaders-modified-hook))

(defmacro define-shader (name (&key (version 330) (primitive :triangles)) &body body)
  `(progn
     (shadow:define-shader ,name (:version ,version :primitive ,primitive)
       ,@body)
     (export ',name)))
