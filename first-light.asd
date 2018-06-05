(asdf:defsystem #:first-light
  :description "An experimental game engine."
  :author ("Michael Fiano <mail@michaelfiano.com>"
           "Peter Keller <psilord@cs.wisc.edu>")
  :maintainer ("Michael Fiano <mail@michaelfiano.com>"
               "Peter Keller <psilord@cs.wisc.edu>")
  :license "MIT"
  :homepage "https://github.com/hackertheory/first-light"
  :bug-tracker "https://github.com/hackertheory/first-light/issues"
  :source-control (:git "git@github.com:hackertheory/first-light.git")
  :version "0.1.0"
  :encoding :utf-8
  :long-description #.(uiop:read-file-string (uiop/pathname:subpathname *load-pathname* "README.md"))
  :depends-on (#:closer-mop
               #:defpackage-plus
               #:cl-ppcre
               #:split-sequence
               #:simple-logger
               #:cl-graph
               #:jsown
               #:cl-opengl
               #:cl-tga
               #:golden-utils
               #:parsley
               #:shadow
               #:umbra
               #:gamebox-math.vari
               #:gamebox-frame-manager)
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "common")
   (:file "logging")
   (:file "context")
   (:file "host")
   (:file "extensions")
   (:file "settings")
   (:file "components")
   (:file "core-state")
   (:file "display")
   (:file "actor")
   (:file "call-flow")
   (:file "type-dag")
   (:file "scene")
   (:file "viewport")
   (:file "image")
   (:file "texture")
   (:file "materials")
   (:file "shaders")
   (:file "mesh")
   (:file "engine")
   (:file "components/transform")
   (:file "components/camera")
   (:file "components/camera-following")
   (:file "components/camera-tracking")
   (:file "components/mesh-renderer")
   (:file "components/mesh")))
