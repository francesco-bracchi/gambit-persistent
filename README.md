# Persistent Vectors and maps

This library provides 3 data structures, 
+ Vectors, 
+ Maps, 
+ Vectors with zipper.

## Install

1. Download The from https://github.com/francesco-bracchi/gambit-persistent.git

    git clone https://github.com/francesco-bracchi/gambit-persistent.git

1. Compile it 

    cd gambit-persistent;
    make

1. Install it

    sudo make install

If you don't want to install system wide, do not run make install, copy
the `build` directory created by make somewhere, then instruct gsi/gsc to refer
to this directory as persistent. For example:

    mkdir ~/.gambit-libs
    cp -r build ~/.gambit-libs/persistent
    gsi -:~~persistent=~/.gambit-libs/persistent

## Usage

    gsi ~~persistent/persistent test-vector.scm

where *test.scm* is

    (include "~~persistent/vector#.scm")
    (define vect (list->persistent-vector `(0 1 2 3 4 5 6 7 8 9)))
    ;; vect is a persistent vector

    (include "~~persistent/map#.scm")
    (define map (list->persistent-map `((a . 10) (b . 20) (c . 30))))
    ;; map is a persistent map

    (include "~~persistent/zipper-vector#.scm")
    (define zipvect (list->persistent-vector `(0 1 2 3 4 5 6 7 8 9)))
    ;; zipvect is a vector with zipper.

Pay attention on the fact that *zipper-vector#.scm* and *vector#.scm*
are exporting the same namespace interface and will produce name clash.

## Data Structures

### Persistent Vector

This data type is a persistent vector.

the internal representation is a tree with nodes that have bf (branching factor) 
branches each. 

If you think at the vector index as a binary number, the first log2(bf) bits 
corresponds to the branch at root, the second block of bits of the same length
to the branch in the second level and so on.

Values are stored in the leaves.

This configuration, for a reasonable branching factor (by default 32) can be 
bound to a constant (if we want to store 2^32 elements, with branching factor of 16
32 / 4 = 8 is the height of the tree, therefore it needs 8 steps to reach an 
element.

#### length
returns the number of elements contained in the vector

    (persistent-vector-length <persistent-vector>)
    ;; -> int

the operation is performed in `O(1)`


### get

    (persistent-vector-ref <persistent-vector> j) 
    ;; -> value

this operation is performed in `O(log<k>(n))` where `k` is the branching factor,
and `n` is the total number of element in the vector. the default branching factor
is 32.

### set
this operation is performed (as get) in `O(log<k>(n))` where `k` is the branching factor,
and `n` is the total number of element in the vector. the default branching factor
is 32.

    (persistent-vector-set <persistent-vector> j <value>)
    ;; -> <persistent-vector>

### map/for-each 

these operations apply the same function to the whole vector, in one case returning
a new vector, in the other ignoring it

    (persistent-vector-map <function> <persistent-vector> <vectors> ...)
    ;; -> <persistent-vector>
    (persistent-vector-for-each <function> <persistent-vector> <vectors> ...)
    ;; -> undefined

### push

This operation changes the length of the vector, and adds a new element at
the end (i.e. at the `(persistent-vector-length <persistent-vector>)` position.

This operation is performed (as get) in `O(log<k>(n))` where `k` is the branching factor,
and `n` is the total number of element in the vector. the default branching factor
is 32.

    (persistent-vector-push <persistent-vector> <value>
    ;; -> <persistent-vector>

## Persistent Map

** TBD **

## Zipper Vector

    (include "~~persistent/zipper-vector#.scm")
    (define zipvect (list->persistent-vector `(0 1 2 3 4 5 6 7 8 9)))
    ;; zipvect is a vector with zipper.

this library provide the same features of Vector, but the uses a zipper to bookmark 
the last insertion point. This means that it will be faster than normal vector in 
updating elements in sequential indexes. In some scenario it give advantages on normal
persistent vector.
