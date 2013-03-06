(##namespace 
 ("persistent.map#"

  ;; exceptions
  persistent-map-exception?
  persistent-map-exception-procedure

  persistent-map-key-not-found-exception?
  persistent-map-key-not-found-exception-procedure
  persistent-map-key-not-found-exception-arguments

  persistent-map-type-exception?
  persistent-map-type-exception-procedure
  persistent-map-type-exception-arguments
  persistent-map-type-exception-arg-num

  ;; constructors
  make-persistent-map
  persistent-map?
  persistent-map-length
  persistent-map-set
  persistent-map-ref
  persistent-map-reduce
  persistent-map-for-each
  persistent-map-keys
  persistent-map-values
  persistent-map-merge
  persistent-map->list
  list->persistent-map
  ))
