! Copyright (C) 2007, 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: arrays generic assocs hashtables
kernel kernel.private math namespaces sequences words
quotations strings alien layouts system combinators
math.bitfields words.private cpu.architecture ;
IN: generator.fixup

: no-stack-frame -1 ; inline

TUPLE: frame-required n ;

: frame-required ( n -- ) \ frame-required construct-boa , ;

: stack-frame-size ( code -- n )
    no-stack-frame [
        dup frame-required? [ frame-required-n max ] [ drop ] if
    ] reduce ;

GENERIC: fixup* ( frame-size obj -- frame-size )

: code-format 22 getenv ;

: compiled-offset ( -- n ) building get length code-format * ;

TUPLE: label offset ;

: <label> ( -- label ) label construct-empty ;

M: label fixup*
    compiled-offset swap set-label-offset ;

: define-label ( name -- ) <label> swap set ;

: resolve-label ( label/name -- ) dup label? [ get ] unless , ;

: if-stack-frame ( frame-size quot -- )
    swap dup no-stack-frame =
    [ 2drop ] [ stack-frame swap call ] if ; inline

M: word fixup*
    {
        { \ %prologue-later [ dup [ %prologue ] if-stack-frame ] }
        { \ %epilogue-later [ dup [ %epilogue ] if-stack-frame ] }
    } case ;

SYMBOL: relocation-table
SYMBOL: label-table

! Relocation classes
: rc-absolute-cell     0 ;
: rc-absolute          1 ;
: rc-relative          2 ;
: rc-absolute-ppc-2/2  3 ;
: rc-relative-ppc-2    4 ;
: rc-relative-ppc-3    5 ;
: rc-relative-arm-3    6 ;
: rc-indirect-arm      7 ;
: rc-indirect-arm-pc   8 ;

: rc-absolute? ( n -- ? )
    dup rc-absolute-cell =
    over rc-absolute =
    rot rc-absolute-ppc-2/2 = or or ;

! Relocation types
: rt-primitive 0 ;
: rt-dlsym     1 ;
: rt-literal   2 ;
: rt-dispatch  3 ;
: rt-xt        4 ;
: rt-here      5 ;
: rt-label     6 ;

TUPLE: label-fixup label class ;

: label-fixup ( label class -- ) \ label-fixup construct-boa , ;

M: label-fixup fixup*
    dup label-fixup-class rc-absolute?
    [ "Absolute labels not supported" throw ] when
    dup label-fixup-label swap label-fixup-class
    compiled-offset 4 - rot 3array label-table get push ;

TUPLE: rel-fixup arg class type ;

: rel-fixup ( arg class type -- ) \ rel-fixup construct-boa , ;

: (rel-fixup) ( arg class type offset -- pair )
    pick rc-absolute-cell = cell 4 ? -
    >r { 0 8 16 } bitfield r>
    2array ;

M: rel-fixup fixup*
    dup rel-fixup-arg
    over rel-fixup-class
    rot rel-fixup-type
    compiled-offset (rel-fixup)
    relocation-table get push-all ;

M: frame-required fixup* drop ;

M: integer fixup* , ;

: push-new* ( obj table -- n )
    2dup swap [ eq? ] curry find drop
    [ 2nip ] [ dup length >r push r> ] if* ;

SYMBOL: literal-table

: add-literal ( obj -- n ) literal-table get push-new* ;

: string>symbol ( str -- alien )
    [ os wince? [ string>u16-alien ] [ string>char-alien ] if ]
    over string? [ call ] [ map ] if ;

: add-dlsym-literals ( symbol dll -- )
    >r string>symbol r> 2array literal-table get push-all ;

: rel-dlsym ( name dll class -- )
    >r literal-table get length >r
    add-dlsym-literals
    r> r> rt-dlsym rel-fixup ;

: rel-word ( word class -- )
    >r add-literal r> rt-xt rel-fixup ;

: rel-primitive ( word class -- )
    >r word-def first r> rt-primitive rel-fixup ;

: rel-literal ( literal class -- )
    >r add-literal r> rt-literal rel-fixup ;

: rel-this ( class -- )
    0 swap rt-label rel-fixup ;

: rel-here ( class -- )
    0 swap rt-here rel-fixup ;

: init-fixup ( -- )
    V{ } clone relocation-table set
    V{ } clone label-table set ;

: resolve-labels ( labels -- labels' )
    [
        first3 label-offset
        [ "Unresolved label" throw ] unless*
        3array
    ] map concat ;

: fixup ( code -- literals relocation labels code )
    [
        init-fixup
        dup stack-frame-size swap [ fixup* ] each drop

        literal-table get >array
        relocation-table get >array
        label-table get resolve-labels
    ] { } make ;
