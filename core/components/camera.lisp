(in-package :first-light.components)

(define-component camera ()
  ((activep :default nil)
   (view :default (flm:mat4 1))
   (projection :default (flm:mat4 1))
   (mode :default :perspective)
   (clip-near :default 0.1)
   (clip-far :default 1024)
   (fovy :default (* 90 (/ pi 180)))
   (zoom :default 1)
   (transform :default nil)))

(defmethod initialize-component ((component camera) (context context))
  (with-accessors ((mode mode) (actor actor) (transform transform)) component
    (make-projection mode component context)
    (setf transform (actor-component-by-type actor 'transform))
    (push component (cameras (core-state context)))))

(defmethod destroy-component ((component camera) (context context))
  (fl.util:deletef (cameras (core-state context)) component)
  (setf (active-camera context) nil))

(defmethod make-projection ((mode (eql :perspective)) camera (context context))
  (with-accessors ((zoom zoom) (proj projection) (near clip-near) (far clip-far) (fovy fovy)) camera
    (flm:set-projection/perspective (/ fovy zoom)
                                    (/ (option context :window-width)
                                       (option context :window-height))
                                    near
                                    far
                                    proj)))

(defmethod make-projection ((mode (eql :orthographic)) camera (context context))
  (with-accessors ((zoom zoom) (proj projection) (near clip-near) (far clip-far)) camera
    (let ((w (/ (option context :window-width) (zoom camera) 2))
          (h (/ (option context :window-height) (zoom camera) 2)))
      (flm:set-projection/orthographic (- w) w (- h) h near far proj))))

(defgeneric compute-camera-view (camera context)
  (:method ((camera camera) (context context))
    (with-accessors ((view view) (transform transform)) camera
      (let* ((model (model transform))
             (eye (flm:get-translation model))
             (target (flm:+ eye (flm:negate (flm:vec3 (flm:get-column model 2)))))
             (up (flm:vec3 (flm:get-column model 1))))
        (flm:set-view eye target up view)))))

(defun find-active-camera (core-state)
  (dolist (camera (cameras core-state))
    (when (activep camera)
      (return-from find-active-camera camera))))

(defun zoom-camera (display direction)
  (let* ((core-state (core-state display))
         (camera (find-active-camera core-state)))
    (with-accessors ((zoom zoom) (mode mode)) camera
      (setf zoom (fl.util:clamp (+ zoom (/ direction 2)) 1 10))
      (make-projection mode camera (context core-state)))))
