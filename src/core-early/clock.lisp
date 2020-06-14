(in-package #:virality)

(deftype clock () '(simple-array double-float (16)))

(defstruct (clock (:type (vector double-float))
                  (:constructor %make-clock)
                  (:predicate nil)
                  (:copier nil))
  (accumulator 0d0 :type double-float)
  (current-time (get-time) :type double-float)
  (debug-count 0d0 :type double-float)
  (debug-interval 5d0 :type double-float)
  (debug-time (get-time) :type double-float)
  (delta-buffer 0d0 :type double-float)
  (delta-time (/ 30d0) :type double-float)
  (frame-count 0d0 :type double-float)
  (frame-time 0d0 :type double-float)
  (interpolation-factor 0d0 :type double-float)
  (pause-time 0d0 :type double-float)
  (period-elapsed (get-time) :type double-float)
  (period-interval 0.25d0 :type double-float)
  (previous-time 0d0 :type double-float)
  (start-time (get-time) :type double-float)
  (total-time 0d0 :type double-float))

(defun make-clock (core)
  (let ((delta-time (float =delta= 1d0))
        (period-interval (float =period-interval= 1d0))
        (debug-interval (float =debug-interval= 1d0)))
    (setf (slot-value core '%clock)
          (%make-clock :delta-time delta-time
                       :period-interval period-interval
                       :debug-interval debug-interval))))

(defun get-time ()
  #+sbcl
  (u:mvlet ((s ms (sb-ext:get-time-of-day)))
    (+ (- s (load-time-value (sb-ext:get-time-of-day)))
       (/ ms 1d6)))
  #-sbcl
  (float (/ (get-internal-real-time) internal-time-units-per-second) 1d0))

(defun initialize-frame-time (clock)
  (let ((time (get-time)))
    (setf (clock-start-time clock) time
          (clock-current-time clock) time)))

(defun smooth-delta-time (clock refresh-rate)
  (symbol-macrolet ((frame-time (clock-frame-time clock))
                    (buffer (clock-delta-buffer clock)))
    (incf frame-time buffer)
    (let ((frame-count
            (max 1d0 (ftruncate (+ 1d0 (* frame-time refresh-rate)))))
          (previous frame-time))
      (setf frame-time (/ frame-count refresh-rate)
            buffer (- previous frame-time))
      nil)))

(defun calculate-frame-rate (clock)
  (symbol-macrolet ((debug-time (clock-debug-time clock))
                    (debug-interval (clock-debug-interval clock))
                    (debug-count (clock-debug-count clock)))
    (let* ((current-time (get-time))
           (elapsed (- current-time debug-time))
           (fps (/ debug-count debug-interval)))
      (when (and (>= elapsed debug-interval)
                 (plusp fps))
        #++(:printv "Frame rate: ~,2f fps / ~,3f ms/f" fps (/ 1000 fps))
        (setf debug-count 0d0
              debug-time current-time))
      (incf debug-count)
      nil)))

(defun clock-physics-update (core clock)
  (symbol-macrolet ((accumulator (clock-accumulator clock))
                    (delta (clock-delta-time clock)))
    (incf accumulator (clock-frame-time clock))
    (flet ((do-physics-update ()
             (execute-flow core
                           :default
                           'active-phase
                           'protocol-physics-update
                           :come-from-state-name
                           :ef-physics-update)
             (comp::process-deferred-instant-transform-updates core)
             (comp::map-nodes
              (lambda (x)
                (comp::transform-node x)
                (comp::reset-transform-replace-count x))
              (component-by-type (scene-tree core) 'comp:transform))
             (execute-flow core
                           :default
                           'active-phase
                           'physics-collisions
                           :come-from-state-name
                           :ef-physics-collisions)
             ;; TODO: Prevent an error in SBCL from producing a WARNING when
             ;; returning multiple values here. This needs more investigation.
             nil))

      ;; NOTE: On the _very first frame_, execute physics to give us something
      ;; to interpolate properly in the world BEFORE we accumulate to the first
      ;; delta amount of physics time.
      (when (< (clock-frame-count clock) 1d0)
        (do-physics-update))

      ;; Then if enough time had passed, run physics.
      (u:while (>= accumulator delta)
        (do-physics-update)
        (decf accumulator delta))

      (setf (clock-interpolation-factor clock) (/ accumulator delta))
      nil)))

(defun clock-periodic-update (clock)
  (symbol-macrolet ((current (clock-current-time clock))
                    (elapsed (clock-period-elapsed clock)))
    (let ((period-interval (clock-period-interval clock)))
      (when (>= (- current elapsed) period-interval)
        (update-repl)
        #++(:printv "Periodic update performed (every ~d seconds)"
                    period-interval)
        (setf elapsed current)))
    nil))

(defun clock-tick (core)
  (let ((display (display core))
        (clock (clock core)))
    (symbol-macrolet ((previous (clock-previous-time clock))
                      (current (clock-current-time clock))
                      (start (clock-start-time clock))
                      (pause (clock-pause-time clock)))
      (setf previous (+ current pause)
            current (- (get-time) pause)
            (clock-frame-time clock) (- current previous)
            (clock-total-time clock) (- current start)
            pause 0d0)
      (when =vsync=
        (smooth-delta-time clock (refresh-rate display)))
      (clock-physics-update core clock)
      (clock-periodic-update clock)
      (calculate-frame-rate clock))))