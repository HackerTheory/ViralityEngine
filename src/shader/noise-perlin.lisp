(in-package #:virality.shaders.noise)

;;;; Perlin noise
;;;; Original implementation by Ken Perlin
;;;; Brian Sharpe https://github.com/BrianSharpe/GPU-Noise-Lib

;;; 2D Perlin noise

(define-function perlin ((point :vec2)
                         (hash-fn (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((origin (floor point))
           (vecs (- (.xyxy point) (vec4 origin (1+ origin))))
           (hash-x hash-y (funcall hash-fn origin))
           (grad-x (- hash-x 0.5 +epsilon+))
           (grad-y (- hash-y 0.5 +epsilon+))
           (blend (virality.shaders.shaping:quintic-curve (.xy vecs)))
           (blend (vec4 blend (- 1 blend)))
           (out (dot (* (inversesqrt (+ (* grad-x grad-x) (* grad-y grad-y)))
                        (+ (* grad-x (.xzxz vecs)) (* grad-y (.yyww vecs)))
                        1.4142135)
                     (* (.zxzx blend) (.wwyy blend)))))
    (map-domain out -1 1 0 1)))

(define-function perlin ((point :vec2))
  (perlin point (lambda ((x :vec2)) (virality.shaders.hash:fast32/2-per-corner x))))

;;; 2D Perlin noise with derivatives

(define-function perlin/derivs ((point :vec2)
                                (hash-fn (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vecs (- (.xyxy point) (vec4 cell (1+ cell))))
           (hash-x hash-y (funcall hash-fn cell))
           (grad-x (- hash-x 0.5 +epsilon+))
           (grad-y (- hash-y 0.5 +epsilon+))
           (norm (inversesqrt (+ (* grad-x grad-x) (* grad-y grad-y))))
           (grad-x (* grad-x norm))
           (grad-y (* grad-y norm))
           (dotval (+ (* grad-x (.xzxz vecs)) (* grad-y (.yyww vecs))))
           (dotval0-grad0 (vec3 (.x dotval) (.x grad-x) (.x grad-y)))
           (dotval1-grad1 (vec3 (.y dotval) (.y grad-x) (.y grad-y)))
           (dotval2-grad2 (vec3 (.z dotval) (.z grad-x) (.z grad-y)))
           (dotval3-grad3 (vec3 (.w dotval) (.w grad-x) (.w grad-y)))
           (k0-gk0 (- dotval1-grad1 dotval0-grad0))
           (k1-gk1 (- dotval2-grad2 dotval0-grad0))
           (k2-gk2 (- dotval3-grad3 dotval2-grad2 k0-gk0))
           (blend (virality.shaders.shaping:quintic-curve/interpolate-derivative
                   (.xy vecs)))
           (out (+ dotval0-grad0
                   (* (.x blend) k0-gk0)
                   (* (.y blend) (+ k1-gk1 (* (.x blend) k2-gk2)))))
           (noise (map-domain (.x out) -0.70710677 0.70710677 0 1))
           (derivs (* (+ (.yz out) (+ (* (.zw blend)
                                         (vec2 (.x k0-gk0) (.x k1-gk1)))
                                      (* (.yx blend) (.xx k2-gk2))))
                      0.70710677)))
    (vec3 noise derivs)))

(define-function perlin/derivs ((point :vec2))
  (perlin/derivs point (lambda ((x :vec2))
                         (virality.shaders.hash:fast32/2-per-corner x))))

;;; 2D Perlin Surflet noise
;;; http://briansharpe.wordpress.com/2012/03/09/modifications-to-classic-perlin-noise/

(define-function perlin-surflet ((point :vec2)
                                 (hash-fn (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vecs (- (.xyxy point) (vec4 cell (1+ cell))))
           (hash-x hash-y (funcall hash-fn cell))
           (grad-x (- hash-x 0.5 +epsilon+))
           (grad-y (- hash-y 0.5 +epsilon+))
           (vecs-squared (* vecs vecs))
           (vecs-squared (+ (.xzxz vecs-squared) (.yyww vecs-squared)))
           (out (dot (virality.shaders.shaping:falloff-squared-c2
                      (min (vec4 1) vecs-squared))
                     (* (inversesqrt (+ (* grad-x grad-x) (* grad-y grad-y)))
                        (+ (* grad-x (.xzxz vecs)) (* grad-y (.yyww vecs)))
                        2.3703704))))
    (map-domain out -1 1 0 1)))

(define-function perlin-surflet ((point :vec2))
  (perlin-surflet point (lambda ((x :vec2))
                          (virality.shaders.hash:fast32/2-per-corner x))))

;;; 2D Perlin Surflet noise with derivatives

(define-function perlin-surflet/derivs ((point :vec2)
                                        (hash-fn
                                         (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vecs (- (.xyxy point) (vec4 cell (1+ cell))))
           (hash-x hash-y (funcall hash-fn cell))
           (grad-x (- hash-x 0.5 +epsilon+))
           (grad-y (- hash-y 0.5 +epsilon+))
           (norm (inversesqrt (+ (* grad-x grad-x) (* grad-y grad-y))))
           (grad-x (* grad-x norm))
           (grad-y (* grad-y norm))
           (vecs-squared (* vecs vecs))
           (m (max (- 1 (+ (.xzxz vecs-squared) (.yyww vecs-squared))) 0))
           (m2 (* m m))
           (m3 (* m m2))
           (out (dot m3 (+ (* grad-x (.xzxz vecs)) (* grad-y (.yyww vecs)))))
           (temp (* -6 m2 out))
           (noise (map-domain out -0.421875 0.421875 0 1))
           (derivs (* (vec2 (* (dot temp (.xzxz vecs)) (dot m3 grad-x))
                            (* (dot temp (.yyww vecs)) (dot m3 grad-y)))
                      1.1851852)))
    (vec3 noise derivs)))

(define-function perlin-surflet/derivs ((point :vec2))
  (perlin-surflet/derivs point (lambda ((x :vec2))
                                 (virality.shaders.hash:fast32/2-per-corner x))))

;;; 2D Perlin noise improved
;;; Ken Perlin's improved version

(define-function perlin-improved ((point :vec2)
                                  (hash-fn (function (:vec2) :vec4)))
  (let* ((cell (floor point))
         (vecs (- (.xyxy point) (vec4 cell (1+ cell))))
         (hash (- (funcall hash-fn cell) 0.5))
         (blend (virality.shaders.shaping:quintic-curve (.xy vecs)))
         (blend (vec4 blend (- 1 blend)))
         (out (dot (+ (* (.xzxz vecs) (sign hash))
                      (* (.yyww vecs) (sign (- (abs hash) 0.25))))
                   (* (.zxzx blend) (.wwyy blend)))))
    (map-domain out -1 1 0 1)))

(define-function perlin-improved ((point :vec2))
  (perlin-improved point (lambda ((x :vec2)) (virality.shaders.hash:fast32 x))))

;;; 3D Perlin noise

(define-function perlin ((point :vec3)
                         (hash-fn (function
                                   (:vec3)
                                   (:vec4 :vec4 :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (vec-1 (1- vec))
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (grad-x0 (- hash-x0 0.5 +epsilon+))
           (grad-y0 (- hash-y0 0.5 +epsilon+))
           (grad-z0 (- hash-z0 0.5 +epsilon+))
           (grad-x1 (- hash-x1 0.5 +epsilon+))
           (grad-y1 (- hash-y1 0.5 +epsilon+))
           (grad-z1 (- hash-z1 0.5 +epsilon+))
           (temp1 (* (inversesqrt (+ (* grad-x0 grad-x0)
                                     (* grad-y0 grad-y0)
                                     (* grad-z0 grad-z0)))
                     (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x0)
                        (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y0)
                        (* (.z vec) grad-z0))))
           (temp2 (* (inversesqrt (+ (* grad-x1 grad-x1)
                                     (* grad-y1 grad-y1)
                                     (* grad-z1 grad-z1)))
                     (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x1)
                        (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y1)
                        (* (.z vec-1) grad-z1))))
           (blend (virality.shaders.shaping:quintic-curve vec))
           (out (mix temp1 temp2 (.z blend)))
           (blend (vec4 (.xy blend) (- 1 (.xy blend))))
           (out (* (dot out (* (.zxzx blend) (.wwyy blend))) 1.1547005)))
    (map-domain out -1 1 0 1)))

(define-function perlin ((point :vec3))
  (perlin point (lambda ((x :vec3)) (virality.shaders.hash:fast32/3-per-corner x))))

;;; 3D Perlin noise with derivatives

(define-function perlin/derivs ((point :vec3)
                                (hash-fn
                                 (function
                                  (:vec3)
                                  (:vec4 :vec4 :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (vec-1 (1- vec))
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (grad-x0 (- hash-x0 0.5 +epsilon+))
           (grad-y0 (- hash-y0 0.5 +epsilon+))
           (grad-z0 (- hash-z0 0.5 +epsilon+))
           (grad-x1 (- hash-x1 0.5 +epsilon+))
           (grad-y1 (- hash-y1 0.5 +epsilon+))
           (grad-z1 (- hash-z1 0.5 +epsilon+))
           (norm0 (inversesqrt (+ (* grad-x0 grad-x0)
                                  (* grad-y0 grad-y0)
                                  (* grad-z0 grad-z0))))
           (norm1 (inversesqrt (+ (* grad-x1 grad-x1)
                                  (* grad-y1 grad-y1)
                                  (* grad-z1 grad-z1))))
           (grad-x0 (* grad-x0 norm0))
           (grad-y0 (* grad-y0 norm0))
           (grad-z0 (* grad-z0 norm0))
           (grad-x1 (* grad-x1 norm1))
           (grad-y1 (* grad-y1 norm1))
           (grad-z1 (* grad-z1 norm1))
           (dot0 (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x0)
                    (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y0)
                    (* (.z vec) grad-z0)))
           (dot1 (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x1)
                    (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y1)
                    (* (.z vec-1) grad-z1)))
           (dot0-grad0 (vec4 (.x dot0) (.x grad-x0) (.x grad-y0) (.x grad-z0)))
           (dot1-grad1 (vec4 (.y dot0) (.y grad-x0) (.y grad-y0) (.y grad-z0)))
           (dot2-grad2 (vec4 (.z dot0) (.z grad-x0) (.z grad-y0) (.z grad-z0)))
           (dot3-grad3 (vec4 (.w dot0) (.w grad-x0) (.w grad-y0) (.w grad-z0)))
           (dot4-grad4 (vec4 (.x dot1) (.x grad-x1) (.x grad-y1) (.x grad-z1)))
           (dot5-grad5 (vec4 (.y dot1) (.y grad-x1) (.y grad-y1) (.y grad-z1)))
           (dot6-grad6 (vec4 (.z dot1) (.z grad-x1) (.z grad-y1) (.z grad-z1)))
           (dot7-grad7 (vec4 (.w dot1) (.w grad-x1) (.w grad-y1) (.w grad-z1)))
           (k0-gk0 (- dot1-grad1 dot0-grad0))
           (k1-gk1 (- dot2-grad2 dot0-grad0))
           (k2-gk2 (- dot4-grad4 dot0-grad0))
           (k3-gk3 (- dot3-grad3 dot2-grad2 k0-gk0))
           (k4-gk4 (- dot5-grad5 dot4-grad4 k0-gk0))
           (k5-gk5 (- dot6-grad6 dot4-grad4 k1-gk1))
           (k6-gk6 (- (- dot7-grad7 dot6-grad6) (- dot5-grad5 dot4-grad4)
                      k3-gk3))
           (blend (virality.shaders.shaping:quintic-curve vec))
           (blend-deriv (virality.shaders.shaping:quintic-curve/derivative vec))
           (out (+ dot0-grad0
                   (* (.x blend) (+ k0-gk0 (* (.y blend) k3-gk3)))
                   (* (.y blend) (+ k1-gk1 (* (.z blend) k5-gk5)))
                   (* (.z blend) (+ k2-gk2 (* (.x blend)
                                              (+ k4-gk4
                                                 (* (.y blend) k6-gk6)))))))
           (noise (map-domain (.x out) -0.8660254 0.8660254 0 1))
           (derivs (* (vec3 (+ (.y out)
                               (dot (vec4 (.x k0-gk0)
                                          (* (.x k3-gk3) (.y blend))
                                          (* (vec2 (.x k4-gk4)
                                                   (* (.x k6-gk6) (.y blend)))
                                             (.z blend)))
                                    (vec4 (.x blend-deriv))))
                            (+ (.z out)
                               (dot (vec4 (.x k1-gk1)
                                          (* (.x k3-gk3) (.x blend))
                                          (* (vec2 (.x k5-gk5)
                                                   (* (.x k6-gk6) (.x blend)))
                                             (.z blend)))
                                    (vec4 (.y blend-deriv))))
                            (+ (.w out)
                               (dot (vec4 (.x k2-gk2)
                                          (* (.x k4-gk4) (.x blend))
                                          (* (vec2 (.x k5-gk5)
                                                   (* (.x k6-gk6) (.x blend)))
                                             (.y blend)))
                                    (vec4 (.x blend-deriv)))))
                      0.57735026)))
    (vec4 noise derivs)))

(define-function perlin/derivs ((point :vec3))
  (perlin/derivs point (lambda ((x :vec3))
                         (virality.shaders.hash:fast32/3-per-corner x))))

;;; 3D Perlin Surflet noise
;;; http://briansharpe.wordpress.com/2012/03/09/modifications-to-classic-perlin-noise/

(define-function perlin-surflet ((point :vec3)
                                 (hash-fn
                                  (function
                                   (:vec3)
                                   (:vec4 :vec4 :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (vec-1 (1- vec))
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (grad-x0 (- hash-x0 0.5 +epsilon+))
           (grad-y0 (- hash-y0 0.5 +epsilon+))
           (grad-z0 (- hash-z0 0.5 +epsilon+))
           (grad-x1 (- hash-x1 0.5 +epsilon+))
           (grad-y1 (- hash-y1 0.5 +epsilon+))
           (grad-z1 (- hash-z1 0.5 +epsilon+))
           (temp1 (* (inversesqrt (+ (* grad-x0 grad-x0)
                                     (* grad-y0 grad-y0)
                                     (* grad-z0 grad-z0)))
                     (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x0)
                        (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y0)
                        (* (.z vec) grad-z0))))
           (temp2 (* (inversesqrt (+ (* grad-x1 grad-x1)
                                     (* grad-y1 grad-y1)
                                     (* grad-z1 grad-z1)))
                     (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x1)
                        (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y1)
                        (* (.z vec-1) grad-z1))))
           (vec (* vec vec))
           (vec-1 (* vec-1 vec-1))
           (vecs-squared (+ (vec4 (.x vec) (.x vec-1) (.x vec) (.x vec-1))
                            (vec4 (.yy vec) (.yy vec-1))))
           (out (* (+ (dot (virality.shaders.shaping:falloff-squared-c2
                            (min (vec4 1) (+ vecs-squared (.z vec))))
                           temp1)
                      (dot (virality.shaders.shaping:falloff-squared-c2
                            (min (vec4 1) (+ vecs-squared (.z vec-1))))
                           temp2))
                   2.3703704)))
    (map-domain out -1 1 0 1)))

(define-function perlin-surflet ((point :vec3))
  (perlin-surflet point (lambda ((x :vec3))
                          (virality.shaders.hash:fast32/3-per-corner x))))

;;; 3D Perlin Surflet noise with derivatives

(define-function perlin-surflet/derivs ((point :vec3)
                                        (hash-fn
                                         (function
                                          (:vec3)
                                          (:vec4 :vec4 :vec4 :vec4 :vec4
                                                 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (vec-1 (1- vec))
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (grad-x0 (- hash-x0 0.5 +epsilon+))
           (grad-y0 (- hash-y0 0.5 +epsilon+))
           (grad-z0 (- hash-z0 0.5 +epsilon+))
           (grad-x1 (- hash-x1 0.5 +epsilon+))
           (grad-y1 (- hash-y1 0.5 +epsilon+))
           (grad-z1 (- hash-z1 0.5 +epsilon+))
           (norm0 (inversesqrt (+ (* grad-x0 grad-x0)
                                  (* grad-y0 grad-y0)
                                  (* grad-z0 grad-z0))))
           (norm1 (inversesqrt (+ (* grad-x1 grad-x1)
                                  (* grad-y1 grad-y1)
                                  (* grad-z1 grad-z1))))
           (grad-x0 (* grad-x0 norm0))
           (grad-y0 (* grad-y0 norm0))
           (grad-z0 (* grad-z0 norm0))
           (grad-x1 (* grad-x1 norm1))
           (grad-y1 (* grad-y1 norm1))
           (grad-z1 (* grad-z1 norm1))
           (grad-results0 (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x0)
                             (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y0)
                             (* (.z vec) grad-z0)))
           (grad-results1 (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) grad-x1)
                             (* (.xxyy (vec2 (.y vec) (.y vec-1))) grad-y1)
                             (* (.z vec-1) grad-z1)))
           (vec-squared (* vec vec))
           (vec-1-squared (* vec-1 vec-1))
           (vecs-squared (+ (.xyxy (vec2 (.x vec-squared) (.x vec-1-squared)))
                            (.xxyy (vec2 (.y vec-squared) (.y vec-1-squared)))))
           (m-0 (max (- 1 (+ vecs-squared (.z vec-squared))) 0))
           (m2-0 (* m-0 m-0))
           (m3-0 (* m-0 m2-0))
           (m-1 (max (- 1 (+ vecs-squared (.z vec-1-squared))) 0))
           (m2-1 (* m-1 m-1))
           (m3-1 (* m-1 m2-1))
           (temp0 (* -6 m2-0 grad-results0))
           (temp1 (* -6 m2-1 grad-results1))
           (deriv0 (vec3 (+ (dot temp0 (.xyxy (vec2 (.x vec) (.x vec-1))))
                            (dot m3-0 grad-x0))
                         (+ (dot temp0 (.xxyy (vec2 (.y vec) (.y vec-1))))
                            (dot m3-0 grad-y0))
                         (+ (dot temp0 (.zzzz vec)) (dot m3-0 grad-z0))))
           (deriv1 (vec3 (+ (dot temp1 (.xyxy (vec2 (.x vec) (.x vec-1))))
                            (dot m3-1 grad-x1))
                         (+ (dot temp1 (.xxyy (vec2 (.y vec) (.y vec-1))))
                            (dot m3-1 grad-y1))
                         (+ (dot temp1 (.zzzz vec-1)) (dot m3-1 grad-z1))))
           (noise (+ (dot m3-0 grad-results0)
                     (dot m3-1 grad-results1)))
           (noise (map-domain noise -0.421875 0.421875 0 1))
           (derivs (* (+ deriv0 deriv1) 1.1851852)))
    (vec4 noise derivs)))

(define-function perlin-surflet/derivs ((point :vec3))
  (perlin-surflet/derivs point (lambda ((x :vec3))
                                 (virality.shaders.hash:fast32/3-per-corner x))))

;;; 3D Perlin noise improved
;;; Ken Perlin's modified version

(define-function perlin-improved ((point :vec3)
                                  (hash-fn (function (:vec3) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (vec-1 (1- vec))
           (hash-low-z hash-high-z (funcall hash-fn cell))
           (hash-low-z (- hash-low-z 0.5))
           (hash-high-z (- hash-high-z 0.5))
           (grad-00 (* (.xyxy (vec2 (.x vec) (.x vec-1))) (sign hash-low-z)))
           (hash-low-z (- (abs hash-low-z) 0.25))
           (grad-01 (* (.xxyy (vec2 (.y vec) (.y vec-1))) (sign hash-low-z)))
           (grad-02 (* (.z vec) (sign (- (abs hash-low-z) 0.125))))
           (grad-10 (* (.xyxy (vec2 (.x vec) (.x vec-1))) (sign hash-high-z)))
           (hash-high-z (- (abs hash-high-z) 0.25))
           (grad-11 (* (.xxyy (vec2 (.y vec) (.y vec-1))) (sign hash-high-z)))
           (grad-12 (* (.z vec-1) (sign (- (abs hash-high-z) 0.125))))
           (grad-0 (+ grad-00 grad-01 grad-02))
           (grad-1 (+ grad-10 grad-11 grad-12))
           (blend (virality.shaders.shaping:quintic-curve vec))
           (out (mix grad-0 grad-1 (.z blend)))
           (blend (vec4 (.xy blend) (- 1 (.xy blend))))
           (out (* (dot out (* (.zxzx blend) (.wwyy blend))) (/ 2 3.0))))
    (map-domain out -1 1 0 1)))

(define-function perlin-improved ((point :vec3))
  (perlin-improved point (lambda ((x :vec3)) (virality.shaders.hash:fast32 x))))

;;; 4D Perlin noise

(define-function perlin ((point :vec4)
                         (hash-fn (function (:vec4) (:vec4 :vec4 :vec4 :vec4
                                                     :vec4 :vec4 :vec4 :vec4
                                                     :vec4 :vec4 :vec4 :vec4
                                                     :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (vec-1 (1- vec))
           (a0 a1 a2 a3 b0 b1 b2 b3 c0 c1 c2 c3 d0 d1 d2 d3
               (funcall hash-fn cell))
           (a0 (- a0 0.5 +epsilon+))
           (a1 (- a1 0.5 +epsilon+))
           (a2 (- a2 0.5 +epsilon+))
           (a3 (- a3 0.5 +epsilon+))
           (b0 (- b0 0.5 +epsilon+))
           (b1 (- b1 0.5 +epsilon+))
           (b2 (- b2 0.5 +epsilon+))
           (b3 (- b3 0.5 +epsilon+))
           (c0 (- c0 0.5 +epsilon+))
           (c1 (- c1 0.5 +epsilon+))
           (c2 (- c2 0.5 +epsilon+))
           (c3 (- c3 0.5 +epsilon+))
           (d0 (- d0 0.5 +epsilon+))
           (d1 (- d1 0.5 +epsilon+))
           (d2 (- d2 0.5 +epsilon+))
           (d3 (- d3 0.5 +epsilon+))
           (temp-a (* (inversesqrt (+ (* a0 a0) (* a1 a1) (* a2 a2) (* a3 a3)))
                      (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) a0)
                         (* (.xxyy (vec2 (.y vec) (.y vec-1))) a1)
                         (* (.z vec) a2)
                         (* (.w vec) a3))))
           (temp-b (* (inversesqrt (+ (* b0 b0) (* b1 b1) (* b2 b2) (* b3 b3)))
                      (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) b0)
                         (* (.xxyy (vec2 (.y vec) (.y vec-1))) b1)
                         (* (.z vec-1) b2)
                         (* (.w vec) b3))))
           (temp-c (* (inversesqrt (+ (* c0 c0) (* c1 c1) (* c2 c2) (* c3 c3)))
                      (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) c0)
                         (* (.xxyy (vec2 (.y vec) (.y vec-1))) c1)
                         (* (.z vec) c2)
                         (* (.w vec-1) c3))))
           (temp-d (* (inversesqrt (+ (* d0 d0) (* d1 d1) (* d2 d2) (* d3 d3)))
                      (+ (* (.xyxy (vec2 (.x vec) (.x vec-1))) d0)
                         (* (.xxyy (vec2 (.y vec) (.y vec-1))) d1)
                         (* (.z vec-1) d2)
                         (* (.w vec-1) d3))))
           (blend (virality.shaders.shaping:quintic-curve vec))
           (temp (+ temp-a (* (- temp-c temp-a) (.w blend))))
           (temp (clamp
                  (+ temp (* (- (+ temp-b (* (- temp-d temp-b) (.w blend)))
                                temp)
                             (.z blend)))
                  0 1))
           (blend (vec4 (.xy blend) (- 1 (.xy blend)))))
    (map-domain (dot temp (* (.zxzx blend) (.wwyy blend))) -1 1 0 1)))

(define-function perlin ((point :vec4))
  (perlin point (lambda ((x :vec4)) (virality.shaders.hash:fast32-2/4-per-corner x))))
