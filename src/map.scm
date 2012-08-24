;; this is the standard, without focus or last optimizations, just plain persistent map in log(n) / log (lbf) access time

;; TODO change ids
(##namespace ("persistent.map#"))
(##include "~~/lib/gambit#.scm")

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

(define-type persistent-map-exception
  extender: define-persistent-map-exception
  id: 1fc40b57-3c90-4464-a518-7a27cdf6461e
  (procedure read-only: unprintable:))

(define-persistent-map-exception persistent-map-key-not-found-exception
  id: f494ed52-42f8-4edf-ae82-35c61e07ec05
  (arguments read-only: unprintable:))

(define-persistent-map-exception persistent-map-type-exception
  id: ad201dc5-8cb1-4127-978b-f64b8bfbd10a
  (arguments read-only: unprintable:)
  (arg-num read-only: unprintable:))

(define-macro (key-not-found-error p a)
  `(raise (make-persistent-map-key-not-found-exception ,p ,a)))

(define-macro (type-error p a n)
  `(raise (make-persistent-map-type-exception ,p ,a ,n)))

(define-type persistent-map 
  prefix: macro-
  constructor: macro-make-persistent-map
  id: 0a731ff2-dfd8-4869-927f-4b6bfc49d19b
  predicate: macro-persistent-map?
  macros:
  (lbf read-only: unprintable:)
  (hash read-only: unprintable:)
  (eq read-only: unprintable:)
  (tree read-only:)
  (length read-only:)
  ;cache
)

(define *absent* (list 'absent))

(define-macro (bit-set j n)
  `(bitwise-ior ,n (arithmetic-shift 1 ,j)))

(define (tree-set pm k v)
  (let*((make-hash (macro-persistent-map-hash pm))
	(eq (macro-persistent-map-eq pm))
	(lbf (macro-persistent-map-lbf pm))
	(-lbf (- lbf))
	(hash (make-hash k))	
	(bf (arithmetic-shift lbf 1)))
    
    (define (path-set depth n)
      (cond
       ((vector? n) (node-set depth n))
       ((pair? n) (leave-set depth n))
       (else (cons 1 (cons k v)))))
    
    (define (node-set depth n)
      (let ((h0 (extract-bit-field lbf (* depth lbf) hash))
	    (bitmap (vector-ref n 0)))
	(if (bit-set? h0 bitmap)
	    (node-set-deeper depth n bitmap h0)
	    (node-set-current depth n bitmap h0))))

    (define (node-set-current depth n bitmap h0)
      (let*((n1 (make-vector (+ 1 (vector-length n))))
	    (bitmap1 (bit-set h0 bitmap)))

	(vector-set! n1 0 bitmap1)
	(vector-set! n1 (vector-length n) (cons k v))
	
	(do ((j 1 (+ j 1))
	     (j-1 0 j))
	    ((> j-1 lbf) (cons 1 n1))
	  (if (bit-set? j-1 bitmap) 
	      (let((i (bit-count (extract-bit-field j 0 bitmap)))
		   (i1 (bit-count (extract-bit-field j 0 bitmap1))))
		(vector-set! n1 i1 (vector-ref n i)))))))

    (define (node-set-deeper depth n bitmap h0)
      (let*((n1 (vector-copy n))
	    (p (+ h0 1))
	    (res (path-set (+ depth 1) (vector-ref n p)))
	    (delta (car res))
	    (c (cdr res)))
	(vector-set! n1 p c)
	(cons delta n1)))
	   
    (define (leave-set depth n)
      (let((k0 (car n)))
	(if (eq k0 k) (cons 0 (cons k v))
	    (let*((hash0 (make-hash k0))
		  (h0 (extract-bit-field lbf (* depth lbf) hash0)))
	      (node-set depth (vector (arithmetic-shift 1 h0) n))))))

    ;; main 
    (path-set 0 (macro-persistent-map-tree pm))))

(define (tree-ref pm k d)
  (let*((make-hash (macro-persistent-map-hash pm))
	(eq (macro-persistent-map-eq pm))
	(lbf (macro-persistent-map-lbf pm))
	(-lbf (- lbf))
	(hash (make-hash k)))

    (define-macro (fail)
      `(if (eq? d *absent*) 
	   (key-not-found-error persistent-map-ref (list pm k))
	   d))
    
    (define (path-ref depth n)
      (cond
       ((vector? n) (node-ref depth n))
       ((pair? n) (leave-ref depth n))
       (else (fail))))

    (define (leave-ref depth n)
      (if (eq (car n) k) 
	  (cdr n)
	  (fail)))

    (define (node-ref depth n)
      (let((h0 (extract-bit-field lbf (* depth lbf) hash))
	   (bitmap (vector-ref n 0)))
	(if (bit-set? h0 bitmap)
	    (path-ref (+ depth 1) (vector-ref n (+ h0 1)))
	    (fail))))

    (path-ref 0 (macro-persistent-map-tree pm))))

(define (tree-reduce fn i n)
  (cond
   ((vector? n) (node-reduce fn i n))
   ((pair? n) (fn i n))
   (else i)))

(define (node-reduce fn i n)
  (do ((j 1 (+ j 1))
       (i i (tree-reduce fn i (vector-ref n j))))
      ((>= j (vector-length n)) i)))
  
(define (node-for-each fn n)
  (do ((j 1 (+ j 1)))
      ((>= j (vector-length n)))
    (tree-for-each fn (vector-ref n j))))

(define (tree-for-each fn n)
  (cond
   ((vector? n) (node-for-each fn n))
   ((pair? n) (fn (car n) (cdr n)))))


(define (unsafe-set pm k v)
  (let*((res (tree-set pm k v))
	(delta (car res))
	(tree (cdr res)))  
    (macro-make-persistent-map
     (macro-persistent-map-lbf pm)
     (macro-persistent-map-hash pm)
     (macro-persistent-map-eq pm)
     tree
     (+ delta (macro-persistent-map-length pm)))))
  
(define (unsafe-ref pm k d)
  (tree-ref pm k d))

(define (unsafe-for-each fn pm)
   (tree-for-each fn (macro-persistent-map-tree pm)))

;; (define (unsafe->list pm)
;;   (tree->list (macro-persistent-map-tree pm)))

(define (snoc a b) (cons b a))

(define (unsafe-reduce fn i pm)
  (tree-reduce fn i (macro-persistent-map-tree pm)))
  
(define (make-persistent-map #!key (eq eq?) (hash eq?-hash) (lbf 5))
  (macro-make-persistent-map lbf hash eq #f 0))

(define (persistent-map? pm)
  (macro-persistent-map? pm))

(define (persistent-map-length pm)
  (cond
   ((macro-persistent-map? pm) (macro-persistent-map-length pm))
   (else (type-error persistent-map-length (list pm) 0))))

;; TODO make v optional, if not present remove k from map
(define (persistent-map-set pm k v)
  (cond
   ((macro-persistent-map? pm) (unsafe-set pm k v))
   (else (type-error persistent-map-set (list pm k v) 0))))

(define (persistent-map-ref pm k #!optional (default *absent*))
  (cond
   ((macro-persistent-map? pm) (unsafe-ref pm k default))
   ((eq? default *absent*) (type-error persistent-map-ref (list pm k) 0))
   (else (type-error persistent-map-ref (list pm k v) 0))))

(define (persistent-map-for-each fn pm)
  (cond
   ((macro-persistent-map? pm) (unsafe-for-each fn pm))
   (else (type-error persistent-map-set (list pm k v) 0))))
  
(define (persistent-map-reduce fn i pm)
  (cond
   ((macro-persistent-map? pm) (unsafe-reduce fn i pm))
   (else (type-error persistent-map-reduce (list fn i pm) 2))))
  
(define (persistent-map->list pm)
  (cond
   ((macro-persistent-map? pm) (unsafe-reduce snoc '() pm))
   (else (type-error persistent-map->list (list pm) 0))))
	 
(define (list->persistent-map ps)
  (cond
   ((list? ps) (unsafe-list->map ps))
   (else (type-error persistent-map->list (list ps) 0))))

(define persistent-map-merge)
   
(define pm (make-persistent-map lbf: 2))

(define pm1 (persistent-map-set pm 0 'zero))

(define pm2 (persistent-map-set pm1 1 'uno))

(define pm3 (persistent-map-set pm2 2 'due))

(define pm4 (persistent-map-set pm3 3 'tre))

(define pm5 (persistent-map-set pm4 4 'quattro))

(define pm6 (persistent-map-set pm5 k: 'duecento))

(pp pm6)
(pp (time (persistent-map-ref pm6 1)))

;; (persistent-map-for-each (lambda (key value) (pp (list key: key value: value))) pm6)

(define (flip fn) (lambda (a b) (fn b a)))

;; (pp (persistent-map->list pm6))
