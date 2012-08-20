(##namespace 
 ("persistent.vector.zipper#"
  ;; creators
  persistent-vector
  make-persistent-vector

  ;; predicates
  persistent-vector?

  ;; actions
  persistent-vector-length
  persistent-vector-ref
  persistent-vector-set
  persistent-vector-map
  persistent-vector-for-each
  persistent-vector-push
  
  ;; conversions
  persistent-vector->vector
  vector->persistent-vector
  
  persistent-vector->list
  list->persistent-vector
  
  persistent-vector->string
  string->persistent-vector
  ))
