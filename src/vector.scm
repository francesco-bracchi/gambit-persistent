;; this is the standard, without focus or last optimizations, just plain persistent vector in log(n) / log (lbf) access time

(##namespace ("persistent.vector#"))
(##include "~~/lib/gambit#.scm")

(##namespace ("persistent.vector#" length))
(declare (standard-bindings)
	 (extended-bindings)
	 (block)
	 (fixnum)
	 (inline-primitives)
	 (not safe)
	 (not debug)
	 (not debug-location)
	 (not debug-source)
	 (not debug-environments))

(define-type persistent-vector-exception
  extender: define-persistent-vector-exception
  id: 5c88ff96-b623-48d5-b313-5a5ceddb974c
  (procedure read-only: unprintable:)
  (arguments read-only: unprintable:)
  (arg-num read-only: unprintable:))

(define-persistent-vector-exception persistent-vector-range-exception)
(define-persistent-vector-exception persistent-vector-type-exception)

(define (range-error p a n)
  (raise (make-persistent-vector-range-exception p a n)))

(define (type-error p a n)
  (raise (make-persistent-vector-type-exception p a n)))


(define-type persistent-vector 
  prefix: macro-
  constructor: make
  id: 0a731ff2-dfd8-4869-927f-4b6bfc49d19b
  predicate: pv?
  macros:
  (length read-only: unprintable:)
  (lbf read-only: unprintable:)
  (tree read-only: unprintable:))

(define-macro (length pv) `(macro-persistent-vector-length ,pv))

(define-macro (lbf pv) `(macro-persistent-vector-lbf ,pv))

(define-macro (tree pv) `(macro-persistent-vector-tree ,pv))

(define-macro (top pv)
  `(max 0 (- (length ,pv) 1)))


(define-macro (bf pv) `(arithmetic-shift 1 (lbf ,pv)))

(define-macro (mask pv) `(- (bf ,pv) 1))

(define (k pv)
  (let((lbf (lbf pv)))
    (lambda (j d)
      (extract-bit-field lbf (* d lbf) j))))

(define (r pv)
  (let((lbf (lbf pv)))
    (lambda (j d)
      (extract-bit-field (* d lbf) 0 j))))

;; (define (depth pv)
;;   (let*((mx (top pv))
;; 	(bit-len (integer-length mx))
;; 	(lbf (lbf pv)))
;;     (quotient bit-len lbf)))

(define (depth pv)
  (quotient (integer-length (- (length pv) 1))
	    (lbf pv)))


;; (define (vector-for pv j)
;;   (let((k (k pv))
;;        (r (r pv)))
;;     (do ((d (depth pv) (- d 1))
;; 	 (j j (r j d))
;; 	 (t (tree pv) (vector-ref t (k j d))))
;; 	((<= d 0) t))))

(define (vector-for pv j)
  (let((k (k pv))
       (r (r pv)))
    (let vector-for ((d (depth pv))
		     (j j)
		     (t (tree pv)))
      (if (<= d 0) t
	  (vector-for (- d 1) 
		      (r j d)
		      (vector-ref t (k j d)))))))

(define (initialize pv init)
  (make (length pv)
    (lbf pv) 
    (make-tree pv init)))

(define (unsafe-make size lbf init)
  (initialize (make size lbf #f) 
	      (if (procedure? init) init (lambda (j) init))))

(define (make-vector&init size init)
  (do ((v (make-vector size))
       (j 0 (+ j 1)))
      ((>= j size) v)
    (vector-set! v j (init j))))

(define (make-tree pv init)
  (let((k (k pv))
       (r (r pv))
       (lbf (lbf pv)))
    (let make-tree ((d (depth pv))
		    (l (length pv))
		    (offset 0))
      (if (<= d 0) (make-vector&init l (lambda (j) (init (+ j offset))))
	  (let*((m (- l 1))
		(k0 (k m d))
		(r0 (r m d))
		(s0 (arithmetic-shift 1 (* lbf d))))
	    (make-vector&init 
	     (+ k0 1) 
	     (lambda (j) (make-tree (- d 1)
				    (if (= j k0) (+ 1 r0) s0)
				    (+ offset (* j s0))))))))))

(define (unsafe-ref pv j)
  (vector-ref (vector-for pv j) (bitwise-and j (mask pv))))

(define (vector-set t j v)
  (let((copy (vector-copy t)))
    (vector-set! copy j v)
    copy))

(define (tree-set pv j v)
  (let((k (k pv))
       (r (r pv)))
    (let set ((d (depth pv))
	      (j j)
	      (t (tree pv)))
      (let((k0 (k j d))
	   (r0 (r j d)))
	(if (<= d 0) (vector-set t k0 v)
	    (vector-set t k0 (set (- d 1) r0 (vector-ref t k0))))))))

(define (unsafe-set pv j v)
  (make (length pv) (lbf pv) (tree-set pv j v)))

(define (slow-map fn v vs)
  (make-persistent-vector 
   (length v) 
   lbf: (lbf v) 
   init: (lambda (j)
	   (apply fn (cons (unsafe-ref v j) (map (lambda (v) (unsafe-ref v j)) 
						 vs))))))

(define (tree-map d fn t ts)
  (make-vector&init 
   (vector-length t)
   (if (= d 0) 
       (lambda (j) (apply fn (cons (vector-ref t j) (map (lambda (t) (vector-ref t j)) ts))))
       (lambda (j) (tree-map (- d 1) fn (vector-ref t j) (map (lambda (t) (vector-ref t j)) ts))))))

(define (fast-map fn v vs)
  (make-persistent-vector 
   (length v)
   lbf: (lbf v)
   init: (tree-map (depth v) fn (tree v) (map (lambda (v) (tree v)) vs))))


(define (unsafe-for-each fn pv)
  (tree-for-each fn pv))

(define (tree-for-each fn pv)
  (let((bf (bf pv)))
    (let for-each ((d (depth pv))
		   (offset 0)
		   (t (tree pv)))
      (if (= d 0)
	  (vector-for-each (lambda (j v) (fn (+ j offset) (vector-ref t j))) t)
	  (vector-for-each (lambda (j v) (for-each (- d 1) (+ offset (* j bf d)) (vector-ref t j))) t)))))

(define (vector-for-each fn v)
  (do ((j 0 (+ j 1)))
      ((>= j (vector-length v)))
    (fn j (vector-ref v j))))

(define (unsafe-push pv v)
  (make (+ 1 (length pv)) 
    (lbf pv) 
    (or (tree-push pv v) (tree-slidedown pv v))))


(define (tree-slidedown pv v)
  (vector (tree pv) (tree-list (depth pv) v)))

(define (tree-list d v)
  (if (<= d 1) (vector v)
      (vector (tree-list (- d 1) v))))

(define (tree-push pv v)
  (let((lbf (lbf pv))
       (bf (bf pv)))
    (let push ((d (depth pv))
	       (t (tree pv)))
      (let((l (vector-length t)))
	(cond
	 ;; we are in a leaf but can't push
	 ((and (= d 0) (= l bf)) #f)
	 
	 ;; we are in a leaf and can push
	 ((= d 0) (make-vector&init (+ 1 l) (lambda (j) (if (< j l) (vector-ref t j) v))))

	 ;; we are in a node, so try to push in the rightmost branch
	 ((push (- d 1) (vector-ref t (- l 1))) =>
	  (lambda (r) (make-vector&init l (lambda (j) (if (< j (- 1 l)) (vector-ref t j) r)))))
	 
	 ;; we are in a node, pushing downwards failed, if we have enough rooms we can create a new branch
	 ((< l bf)
	  (make-vector&init (+ 1 l) (lambda (j) (if < j l) (vector-ref t j) (tree-list d v))))

	 ;; otherwise fail
	 (else #f))))))

(define (tree->reverse-vector-list d t rs)
  (if (= d 0) (cons t rs)
      (do ((rs rs (tree->reverse-vector-list (- d 1) (vector-ref t j) rs))
	   (j 0 (+ j 1)))
	  ((>= j (vector-length t)) rs))))

(define (some? t? vs)
  (let some ((vs vs) (j 0))
    (cond 
     ((null? vs) #f)
     ((t? (car vs)) j)
     (else (some (cdr vs) (+ j 1))))))

;; external interface

;; test
(define (persistent-vector? pv) (pv? pv))
  
;; creation
(define (make-persistent-vector size #!key (lbf 5) (init 0))
  (cond
   ((not (integer? size)) (type-error make-persistent-vector (list size lbf init) 0))
   ((< size 0) (range-error make-persistent-vector (list size lbf init) 0))
   ((not (integer? lbf)) (type-error make-persistent-vector (list size lbf init) 1))
   ((<= lbf 0) (range-error make-persistent-vector (list size lbf init) 1))
   (else (unsafe-make size lbf init))))

(define (persistent-vector . vs)
  (list->persistent-vector vs))

;; length
(define (persistent-vector-length pv) 
  (if (not (pv? pv)) (type-error persistent-vector-length (list pv) 0)
      (length pv)))

;; get
(define (persistent-vector-ref pv j)
  (cond
   ((not (pv? pv)) (type-error persistent-vector-ref (list pv j) 0))
   ((not (integer? j)) (type-error persistent-vector-ref (list pv j) 1))
   ((< j 0) (range-error persistent-vector-ref (list pv j) 1))
   ((>= j (length pv)) (range-error persistent-vector-ref (list pv j) 1))
   (else (unsafe-ref pv j))))

;; set
(define (persistent-vector-set pv j v)
  (cond
   ((not (pv? pv)) (type-error persistent-vector-set (list pv j v) 0))
   ((not (integer? j)) (type-error persistent-vector-set (list pv j v) 1))
   ((<= j 0) (range-error persistent-vector-set (list pv j v) 1))
   ((>= j (length pv)) (range-error persistent-vector-set (list pv j v) 1))
   (else (unsafe-set pv j v))))

;; map
(define (persistent-vector-map fn v . vs)
  (cond
   ((not (procedure? fn)) (type-error persistent-vector-map `(,fn ,v ,@vs) 0))
   ((not (pv? v)) (type-error persistent-vector-map `(,fn ,v ,@vs) 1))
   ((some? (lambda (v0) (not (pv? v0))) vs) => (lambda (j) (type-error persistent-vector-map `(,fn ,v ,@vs) (+ 2 j))))
   ((some? (lambda (v0) (not (= (length v) (length v0)))) vs) => (lambda (j) (range-error persistent-vector-map `(,fn ,v ,@vs) (+ 2 j))))
   ((some? (lambda (v0) (not (= (lbf v) (lbf v0)))) vs) (slow-map fn v vs))
   (else (fast-map fn v vs))))

;; for-each 
(define (persistent-vector-for-each fn v)
  (cond
   ((not (procedure? fn)) (type-error persistent-vector-for-each `(,fn ,v) 0))
   ((not (pv? v)) (type-error persistent-vector-for-each `(,fn ,v) 1))
   (else (unsafe-for-each fn v))))

;; push 
(define (persistent-vector-push pv v)
  (if (not (pv? pv)) (type-error persistent-vector-push (list pv v) 0)
      (persistent-vector-push pv v)))

;; conversion
(define (vector->persistent-vector v #!key (lbf 5))
  (make-persistent-vector 
   (vector-length v) 
   lbf: lbf
   init: (lambda (j) (vector-ref v j))))

(define (persistent-vector->vector pv)
  (apply vector-append (reverse (tree->reverse-vector-list (depth pv) (tree pv) '()))))

(define (list->persistent-vector l)
  (vector->persistent-vector (list->vector l)))

(define (persistent-vector->list pv)
  (vector->list (persistent-vector->vector pv)))

