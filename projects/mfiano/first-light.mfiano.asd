(asdf:defsystem #:first-light.mfiano
  :author ("Michael Fiano <michael.fiano@gmail.com>")
  :maintainer ("Michael Fiano <michael.fiano@gmail.com>")
  :license "MIT"
  :version "0.1.0"
  :depends-on (#:first-light
               #:defpackage-plus)
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "resources")
   (:module "shaders"
    :components
    ((:file "mesh-test")
     (:file "noise-test-playground")))
   (:file "materials")))
