(in-package :first-light.example)

;;; Materials

(fl:define-material graph
  (:profiles (fl.materials:u-mvpt)
   :shader fl.gpu.user:graph))

(fl:define-material 3d-graph
  (:profiles (fl.materials:u-mvpt)
   :shader fl.gpu.user:3d-graph-1
   :instances 1000
   :attributes (:depth :always)
   :uniforms
   ((:size 1)
    (:min 0)
    (:by 1))))

;;; Prefabs

(fl:define-prefab "graph" (:library examples :context context)
  (("camera" :copy "/cameras/ortho"))
  (("graph" :copy "/mesh")
   (fl.comp:transform :scale (m:vec3 (/ (fl:option context :window-width) 2)
                                     (/ (fl:option context :window-height) 2)
                                     0))
   (fl.comp:render :material 'graph)))

(fl:define-prefab "3d-graph-1" (:library examples)
  (("camera" :copy "/cameras/perspective")
   (fl.comp:transform :translate (m:vec3 0 70 100))
   (fl.comp:camera (:policy :new-args) :zoom 2)
   (fl.comp:tracking-camera :target-actor (fl:ref "/3d-graph-1/graph")))
  (("graph" :copy "/mesh")
   (fl.comp:render :material '(3d-graph
                               3d-graph-1
                               :shader fl.gpu.user:3d-graph-1
                               :instances 100000
                               :uniforms ((:size 0.5))))))

(fl:define-prefab "3d-graph-2" (:library examples)
  (("camera" :copy "/cameras/perspective")
   (fl.comp:transform :translate (m:vec3 0 50 100))
   (fl.comp:camera (:policy :new-args) :zoom 2)
   (fl.comp:tracking-camera :target-actor (fl:ref "/3d-graph-2/graph")))
  (("graph" :copy "/mesh")
   (fl.comp:render :material '(3d-graph
                               3d-graph-2
                               :shader fl.gpu.user:3d-graph-2
                               :instances 100000
                               :uniforms ((:size 1))))))