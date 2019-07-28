(in-package #:first-light.components)

(define-component static-mesh ()
  ((location :default nil)
   (index :default 0)
   (data :default nil))
  ((:cached-mesh-data equalp eql)))

(defmethod on-component-initialize ((self static-mesh))
  (with-accessors ((context context) (location location) (index index)
                   (data data))
      self
    (unless location
      (error "A mesh component must have a location set."))
    (let ((path (apply #'find-resource context (a:ensure-list location))))
      (with-shared-storage
          (context context)
          ((cached-mesh mesh-present-p
                        ('static-mesh :cached-mesh-data location index)
                        (%fl:load-static-mesh path index)))
        (setf data cached-mesh)))))
