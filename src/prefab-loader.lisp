(in-package #:first-light.prefab)

(defun make-actors (context prefab)
  (let ((actors (u:dict #'equalp))
        (root))
    (u:do-hash (path node (parse-tree prefab))
      (with-slots (%name %id %display-id) node
        (let ((actor (make-actor context
                                 :prefab-node node
                                 :id %id
                                 :display-id (or %display-id %name))))
          (setf (u:href actors path) actor)
          (unless (parent node)
            (setf root actor)))))
    (values actors
            root)))

(defun make-actor-components (context actors)
  (let ((components (u:dict)))
    (u:do-hash-values (actor actors)
      (u:do-hash (type table (components-table (prefab-node actor)))
        (unless (u:href components actor)
          (setf (u:href components actor) (u:dict)))
        (u:do-hash (id data table)
          (unless (u:href components actor type)
            (setf (u:href components actor type) (u:dict #'equalp)))
          (let ((component (make-component context type)))
            (unless (u:href components actor type id)
              (setf (u:href components actor type id) (u:dict)))
            (setf (u:href components actor type id component) data)
            (attach-component actor component)))))
    (u:do-hash (actor actor-table components)
      (u:do-hash-values (id-table actor-table)
        (u:do-hash-values (component-table id-table)
          (u:do-hash (component data component-table)
            ;; Now, for each argument value itself, we adjust the exact
            ;; lexical scope it closed over with enough stuff for REF to
            ;; work.
            (flet ((%init-injected-ref-environment (v)
                     (funcall (env-injection-control-func v)
                              :actors actors)
                     (funcall (env-injection-control-func v)
                              :components components)
                     (funcall (env-injection-control-func v)
                              :current-actor actor)
                     (funcall (env-injection-control-func v)
                              :current-component component)))
              (let ((args (loop :for (k v) :on (getf data :args) :by #'cddr
                                :append
                                (list k (progn
                                          ;; Set up the injected REF environment
                                          ;; specific to >THIS< argument value
                                          ;; which may have been replaced per
                                          ;; policy rules, etc, etc, etc
                                          (%init-injected-ref-environment v)
                                          (funcall (thunk v) context))))))

                (apply #'reinitialize-instance
                       component :actor actor args)))))))))

(defun make-actor-relationships (context prefab actors parent)
  (let ((parent (or parent (scene-tree (core context))))
        (root (u:href actors (path (root prefab)))))
    (u:do-hash-values (actor actors)
      (let ((node (prefab-node actor)))
        (u:do-hash-values (child (children node))
          (fl.comp:transform-add-child
           (actor-component-by-type actor 'fl.comp:transform)
           (actor-component-by-type (u:href actors (path child))
                                    'fl.comp:transform)))))
    (fl.comp:transform-add-child
     (actor-component-by-type parent 'fl.comp:transform)
     (actor-component-by-type root 'fl.comp:transform))))

(defun make-factory (prefab)
  (lambda (core &key parent)
    (u:mvlet* ((context (context core))
               (actors root (make-actors context prefab)))
      (make-actor-components context actors)
      (make-actor-relationships context prefab actors parent)
      (u:do-hash-values (actor actors)
        (spawn-actor actor))
      root)))

(defun load-prefab (core spec parent)
  (destructuring-bind (name library &key ttl) spec
    (let* ((prefab (find-prefab name library))
           (actor (funcall (func prefab) core :parent parent)))
      (destroy-after-time actor :ttl ttl)
      actor)))

(defun make-prefab-instance (core prefab-descriptor &key parent)
  (let (roots)
    (dolist (spec prefab-descriptor)
      (push (load-prefab core spec parent) roots))
    (nreverse roots)))
