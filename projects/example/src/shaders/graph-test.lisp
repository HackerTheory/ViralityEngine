(in-package :first-light.shader)

(defun graph-test/frag ((uv :vec2)
                        &uniform
                        (time :float))
  (let* ((dim (vec2 (1+ (sin time)) (+ 2 (sin time))))
         (uv (+ (* uv (- (.y dim) (.x dim)))
                (vec2 (.x dim) -0.5))))
    (graph
     (lambda ((x :float))
       (* (sin (* x x x)) (sin x)))
     (* 4 uv)
     (vec4 0 1 0 0.5)
     (vec4 1 1 1 0.02)
     10)))

(define-shader graph-test (:version 430)
  (:vertex (unlit/vert-only-uv1 :vec3 :vec3 :vec4 :vec4 :vec2 :vec2 :vec4 :vec4))
  (:fragment (graph-test/frag :vec2)))