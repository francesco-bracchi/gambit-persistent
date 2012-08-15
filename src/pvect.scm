;; this is the standard, without focus or last optimizations, just plain persistent vector in log(n) / log (lbf) access time

(##namespace ("pvect.pvect#"))
(##include "~~/lib/gambit#.scm")

(namespace ("pvect.pvect#" map))

(declare (standard-bindings)
	 (extended-bindings)
	 (block)
	 (safe))
			    
(define-type pvect 
  (length read-only:)
  (lbf read-only: unprintable:)
  (tree read-only: unprintable:))

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

(define (pvect-max pv)
  (- (pvect-length pv) 1))

(define (pvect-depth pv)
  (let*((mx (pvect-max pv))
	(bit-len (max (- (integer-length mx) 1) 0))
	(lbf (pvect-lbf pv)))
    (floor (/ bit-len lbf))))

(define (pvect-bf pv)
  (arithmetic-shift 1 (pvect-lbf pv)))

(define (pvect-mask pv)
  (- (pvect-bf pv) 1))

(define (pvect-k pv)
  (let((lbf (pvect-lbf pv)))
    (lambda (j d)
      (extract-bit-field lbf (* d lbf) j))))

(define (pvect-r pv)
  (let((lbf (pvect-lbf pv)))
    (lambda (j d)
      (extract-bit-field (* d lbf) 0 j))))

(define (vector-for pv j)
  (let((k (pvect-k pv))
       (r (pvect-r pv)))
       (do ((d (pvect-depth pv) (- d 1))
	 (j j (r j d))
	 (tree (pvect-tree pv) (vector-ref tree (k j d))))
	((<= d 0) tree))))


(define (initialize pv init)
  (make-pvect (pvect-length pv)
	      (pvect-lbf pv) 
	      (build-tree pv init)))

(define (make-vector-init size init)
  (do ((v (make-vector size))
       (j 0 (+ j 1)))
      ((>= j size) v)
    (vector-set! v j (init j))))

(define (build-tree pv init)
  (let((k (pvect-k pv))
       (r (pvect-r pv))
       (lbf (pvect-lbf pv)))
    (let build ((d (pvect-depth pv))
		(l (pvect-length pv))
		(offset 0))
      (if (<= d 0) (make-vector-init l (lambda (j) (init (+ j offset))))
	  (let*((m (- l 1))
		(k0 (k m d))
		(r0 (r m d))
		(s0 (arithmetic-shift 1 (* lbf d))))
	    (make-vector-init 
	     (+ k0 1) 
	     (lambda (j) (build (- d 1)
				(if (= j k0) (+ 1 r0) s0)
				(+ offset (* j s0))))))))))

(define (pvect-ref pv j)
  (vector-ref (vector-for pv j) (bitwise-and j (pvect-mask pv))))

(define (pvect-set pv j v)
  (make-pvect (pvect-length pv)
	      (pvect-lbf pv)
	      (tree-set pv j v)))

(define (vector-set tree j v)
  (let((copy (vector-copy tree)))
    (vector-set! copy j v)
    copy))

(define (tree-set pv j v)
  (let((k (pvect-k pv))
       (r (pvect-r pv)))
    (let set ((d (pvect-depth pv))
	      (j j)
	      (tree (pvect-tree pv)))
      (let((k0 (k j d))
	   (r0 (r j d)))
	(if (<= d 0) (vector-set tree k0 v)
	  (vector-set tree k0 (set (- d 1) r0 (vector-ref tree k0))))))))

(define (some? t? vs)
  (let some ((vs vs) (j 0))
    (cond 
     ((null? vs) #f)
     ((t? (car vs)) j)
     (else (some (cdr vs) (+ j 1))))))

(define (slow-map fn v vs)
  (make (pvect-length v) lbf: (pvect-lbf v) init: (lambda (j)  (apply fn (cons (ref v j) (##map (lambda (v) (ref v j)) vs))))))

(define (fast-map fn v vs)
  (make-pvect (pvect-length v)
	      (pvect-lbf v)
	      (tree-map (pvect-depth v) fn (pvect-tree v) (##map pvect-tree vs))))

(define (tree-map d fn t ts)
  (make-vector-init 
   (vector-length t)
   (if (= d 0) 
       (lambda (j) (apply fn (cons (vector-ref t j) (##map (lambda (t) (vector-ref t j)) ts))))
       (lambda (j) (tree-map (- d 1) fn (vector-ref t j) (##map (lambda (t) (vector-ref t j)) ts))))))
  
(define (pvect-foreach fn pv)
  (tree-foreach fn pv))

(define (tree-foreach fn pv)
  (let((bf (pvect-bf pv)))
    (let foreach ((d (pvect-depth pv))
		  (offset 0)
		  (tree (pvect-tree pv)))
      (if (= d 0)
	  (vector-foreach (lambda (j v) (fn (+ j offset) (vector-ref tree j))) tree)
	  (vector-foreach (lambda (j v) (foreach (- d 1) (+ offset (* j bf d)) (vector-ref tree j))) tree)))))

(define (vector-foreach fn v)
  (do ((j 0 (+ j 1)))
      ((>= j (vector-length v)))
    (fn j (vector-ref v j))))

(define (pvect-push pv v)
  (make-pvect (+ 1 (pvect-length pv)) 
	      (pvect-lbf pv) 
	      (or (tree-push pv v)
		  (top-singleton pv v))))
	      

(define (top-singleton pv v)
  (vector (pvect-tree pv) (tree-singleton (pvect-depth pv) v)))

(define (tree-singleton d v)
  (if (<= d 1) (vector v)
      (vector (tree-singleton (- d 1) v))))

(define (tree-push pv v)
  (let((lbf (pvect-lbf pv))
       (bf (pvect-bf pv)))
    (let push ((d (pvect-depth pv))
	       (tree (pvect-tree pv)))
      (let((l (vector-length tree)))
	(cond
	 ;; can't push here, slot is full
	 ((and (= d 0) (= l bf)) #f)

	 ;; can push in the leave
	 ((= d 0) (make-vector-init (+ 1 l) (lambda (j) (if (< j l) (vector-ref tree j) v))))
	 
	 ;; push in rightmost branch
	 (else
	  (cond 
	   ((push (- d 1) (vector-ref tree (- l 1))) =>
	    ;; push succeded
	    (lambda (r) (make-vector-init l (lambda (j) (if (< j (- 1 l)) (vector-ref tree j) r)))))
	   ((= l bf)
	    ;; push failed and this branch is already full
	    #f)
	   (else 
	    ;; push failed but got slot to add a new branch
	    (make-vector-init (+ 1 l) (lambda (j) (if < j l) (vector-ref tree j) (tree-singleton d v)))))))))))
		     
(define (tree->reverse-vector-list d tree rs)
  (if (= d 0) (cons tree rs)
      (do ((rs rs (tree->reverse-vector-list (- d 1) (vector-ref tree j) rs))
	   (j 0 (+ j 1)))
	  ((>= j (vector-length tree)) rs))))

;; external interface

;; creation
(define (make size #!key (lbf 5) (init 0))
  (initialize (make-pvect size lbf #f) (if (procedure? init) init (lambda (j) init))))

(define (pvect . vs)
  (list->pvect vs))

;; get
(define (ref pv j)
  (cond
   ((not (pvect? pv)) (type-error ref (list pv j) 0))
   ((not (integer? j)) (type-error ref (list pv j) 1))
   ((< j 0) (range-error ref (list pv j) 1))
   ((>= j (pvect-length pv)) (range-error ref (list pv j) 1))
   (else (pvect-ref pv j))))

;; set
(define (set pv j v)
  (cond
   ((not (pvect? pv)) (type-error ref (list pv j v) 0))
   ((not (integer? j)) (type-error ref (list pv j v) 1))
   ((<= j 0) (range-error ref (list pv j v) 1))
   ((>= j (pvect-length pv)) (range-error ref (list pv j v) 1))
   (else (pvect-set pv j v))))

;; map
(define (map fn v . vs)
  (cond
   ((not (procedure? fn)) (type-error `(,fn ,v ,@vs) 0))
   ((not (pvect? v)) (type-error `(,fn ,v ,@vs) 1))
   ((some? (lambda (v0) (not (pvect? v0))) vs) => (lambda (j) (type-error `(,fn ,v ,@vs) (+ 2 j))))
   ((some? (lambda (v0) (not (= (pvect-length v) (pvect-length v0)))) vs) => (lambda (j) (range-error `(,fn ,v ,@vs) (+ 2 j))))
   ((some? (lambda (v0) (not (= (pvect-lbf v) (pvect-lbf v0)))) vs) (slow-map fn v vs))
   (else (fast-map fn v vs))))

;; foreach 
(define (for-each fn v)
  (cond
   ((not (procedure? fn)) (type-error `(,fn ,v) 0))
   ((not (pvect? v)) (type-error `(,fn ,v) 1))
   (else (pvect-foreach fn v))))

;; push 
(define (push pv v)
  (if (not (pvect? pv)) (type-error (list pv v) 0)
      (pvect-push pv v)))

;; conversion
(define (vector->pvect v #!key (lbf 5))
  (make (vector-length v) 
    lbf: lbf
    init: (lambda (j) (vector-ref v j))))

(define (pvect->vector pv)
  (apply vector-append (reverse (tree->reverse-vector-list (pvect-depth pv) (pvect-tree pv) '()))))
  
(define (list->pvect l)
  (vector->pvect (list->vector l)))

(define (pvect->list pv)
  (vector->list (pvect->vector pv)))


(define (id x) x)
(for-each (lambda (j val) (pp `(j: ,j val: ,val))) (make 50 init: id))

;; (pp (pvect->vector (map (lambda (x y) (+ x y))
;; 			(make 10 init: id lbf: 3)
;; 			(make 10 init: id))))

;; (pp (pvect->vector (push (make 24 init: id) 'x)))
