(in-package #:virality.contrib.actions)

(defmethod action:on-update (action (type (eql 'sprite-animate)))
  (a:when-let* ((actor (v:actor (action:renderer (action:manager action))))
                (sprite (v:component-by-type actor 'comp.sprite:sprite)))
    (comp.sprite:update-sprite-index sprite (action:step action))))

(defmethod action:on-finish (action (type (eql 'sprite-animate)))
  (when (action:repeat-p action)
    (action:replace action 'sprite-animate)))
