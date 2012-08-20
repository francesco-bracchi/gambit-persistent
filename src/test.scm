(load "vector")
(load "zipper-vector")

;; (include "vector#.scm")
;; (include "zipper-vector#.scm")

(define *top* (expt 2 20))

(display "creation:\n")

(define-macro (dotimes m . b)
  (let((j (gensym 'j)))
    `(do ((,j 0 (+ ,j 1)))
	 ((>= ,j ,m) 'ok)
       ,@b)))

(define *pv0* (persistent.vector#make-persistent-vector *top* init: (lambda (x) x)))
(define *pv1* (persistent.vector.zipper#make-persistent-vector *top* init: (lambda (x) x)))

(display "tree:")
(time (dotimes 20 (persistent.vector#make-persistent-vector *top* init: (lambda (x) x))))

(display "zipper:")
(time (dotimes 20 (persistent.vector.zipper#make-persistent-vector *top* init: (lambda (x) x))))

(newline)
(display "random set:\n")


(display "tree:")
(time 
 (dotimes 1000000
	  (set! *pv0* (persistent.vector#persistent-vector-set *pv0* (random-integer *top*) 'ciao))))

(display "zipper:")
(time 
 (dotimes 1000000
	  (set! *pv1* (persistent.vector.zipper#persistent-vector-set *pv1* (random-integer *top*) 'ciao))))



(newline)
(display "push:\n")
(display "tree:")
(time 
 (dotimes 1000000
	  (set! *pv0* (persistent.vector#persistent-vector-push *pv0* 'ciao))))

(display "zipper:")
(time 
 (dotimes 1000000
	  (set! *pv1* (persistent.vector.zipper#persistent-vector-push *pv1* 'ciao))))


(newline)
(display "localized set:\n")

(display "tree:")
(time 
 (dotimes 500
	  (let*((lo (random-integer *top*))
		(hi (+ lo (min 10000 (random-integer (- *top* lo))))))
	    (do ((j lo (+ j 1))
		 (pv *pv0* (persistent.vector#persistent-vector-set pv j 'ciao)))
		((>= j hi) pv)))))

(display "zipper:")
(time 
 (dotimes 500
	  (let*((lo (random-integer *top*))
		(hi (+ lo (min 10000 (random-integer (- *top* lo))))))
	    (do ((j lo (+ j 1))
		 (pv *pv1* (persistent.vector.zipper#persistent-vector-set pv j 'ciao)))
		((>= j hi) pv)))))
