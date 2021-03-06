! Copyright (C) 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel math sequences vectors classes classes.algebra
combinators arrays words assocs parser namespaces definitions
prettyprint prettyprint.backend quotations arrays.lib
debugger io compiler.units kernel.private effects accessors
hashtables sorting shuffle ;
IN: multi-methods

! PART I: Converting hook specializers
: canonicalize-specializer-0 ( specializer -- specializer' )
    [ \ f or ] map ;

SYMBOL: args

SYMBOL: hooks

SYMBOL: total

: canonicalize-specializer-1 ( specializer -- specializer' )
    [
        [ class? ] subset
        [ length <reversed> [ 1+ neg ] map ] keep zip
        [ length args [ max ] change ] keep
    ]
    [
        [ pair? ] subset
        [ keys [ hooks get push-new ] each ] keep
    ] bi append ;

: canonicalize-specializer-2 ( specializer -- specializer' )
    [
        >r
        {
            { [ dup integer? ] [ ] }
            { [ dup word? ] [ hooks get index ] }
        } cond args get + r>
    ] assoc-map ;

: canonicalize-specializer-3 ( specializer -- specializer' )
    >r total get object <array> dup <enum> r> update ;

: canonicalize-specializers ( methods -- methods' hooks )
    [
        [ >r canonicalize-specializer-0 r> ] assoc-map

        0 args set
        V{ } clone hooks set

        [ >r canonicalize-specializer-1 r> ] assoc-map

        hooks [ natural-sort ] change

        [ >r canonicalize-specializer-2 r> ] assoc-map

        args get hooks get length + total set

        [ >r canonicalize-specializer-3 r> ] assoc-map

        hooks get
    ] with-scope ;

: drop-n-quot ( n -- quot ) \ drop <repetition> >quotation ;

: prepare-method ( method n -- quot )
    [ 1quotation ] [ drop-n-quot ] bi* prepend ;

: prepare-methods ( methods -- methods' prologue )
    canonicalize-specializers
    [ length [ prepare-method ] curry assoc-map ] keep
    [ [ get ] curry ] map concat [ ] like ;

! Part II: Topologically sorting specializers
: maximal-element ( seq quot -- n elt )
    dupd [
        swapd [ call 0 < ] 2curry subset empty?
    ] 2curry find [ "Topological sort failed" throw ] unless* ;
    inline

: topological-sort ( seq quot -- newseq )
    >r >vector [ dup empty? not ] r>
    [ dupd maximal-element >r over delete-nth r> ] curry
    [ ] unfold nip ; inline

: classes< ( seq1 seq2 -- -1/0/1 )
    [
        {
            { [ 2dup eq? ] [ 0 ] }
            { [ 2dup [ class< ] 2keep swap class< and ] [ 0 ] }
            { [ 2dup class< ] [ -1 ] }
            { [ 2dup swap class< ] [ 1 ] }
            [ 0 ]
        } cond 2nip
    ] 2map [ zero? not ] find nip 0 or ;

: sort-methods ( alist -- alist' )
    [ [ first ] bi@ classes< ] topological-sort ;

! PART III: Creating dispatch quotation
: picker ( n -- quot )
    {
        { 0 [ [ dup ] ] }
        { 1 [ [ over ] ] }
        { 2 [ [ pick ] ] }
        [ 1- picker [ >r ] swap [ r> swap ] 3append ]
    } case ;

: (multi-predicate) ( class picker -- quot )
    swap "predicate" word-prop append ;

: multi-predicate ( classes -- quot )
    dup length <reversed>
    [ picker 2array ] 2map
    [ drop object eq? not ] assoc-subset
    dup empty? [ drop [ t ] ] [
        [ (multi-predicate) ] { } assoc>map
        unclip [ swap [ f ] \ if 3array append [ ] like ] reduce
    ] if ;

: argument-count ( methods -- n )
    keys 0 [ length max ] reduce ;

ERROR: no-method arguments generic ;

: make-default-method ( methods generic -- quot )
    >r argument-count r> [ >r narray r> no-method ] 2curry ;

: multi-dispatch-quot ( methods generic -- quot )
    [ make-default-method ]
    [ drop [ >r multi-predicate r> ] assoc-map reverse ]
    2bi alist>quot ;

! Generic words
PREDICATE: generic < word
    "multi-methods" word-prop >boolean ;

: methods ( word -- alist )
    "multi-methods" word-prop >alist ;

: make-generic ( generic -- quot )
    [
        [ methods prepare-methods % sort-methods ] keep
        multi-dispatch-quot %
    ] [ ] make ;

: update-generic ( word -- )
    dup make-generic define ;

! Methods
PREDICATE: method-body < word
    "multi-method-generic" word-prop >boolean ;

M: method-body stack-effect
    "multi-method-generic" word-prop stack-effect ;

M: method-body crossref?
    drop t ;

: method-word-name ( specializer generic -- string )
    [ word-name % "-" % unparse % ] "" make ;

: method-word-props ( specializer generic -- assoc )
    [
        "multi-method-generic" set
        "multi-method-specializer" set
    ] H{ } make-assoc ;

: <method> ( specializer generic -- word )
    [ method-word-props ] 2keep
    method-word-name f <word>
    [ set-word-props ] keep ;

: with-methods ( word quot -- )
    over >r >r "multi-methods" word-prop
    r> call r> update-generic ; inline

: reveal-method ( method classes generic -- )
    [ set-at ] with-methods ;

: method ( classes word -- method )
    "multi-methods" word-prop at ;

: create-method ( classes generic -- method )
    2dup method dup [
        2nip
    ] [
        drop [ <method> dup ] 2keep reveal-method
    ] if ;

: niceify-method [ dup \ f eq? [ drop f ] when ] map ;

M: no-method error.
    "Type check error" print
    nl
    "Generic word " write dup generic>> pprint
    " does not have a method applicable to inputs:" print
    dup arguments>> short.
    nl
    "Inputs have signature:" print
    dup arguments>> [ class ] map niceify-method .
    nl
    "Available methods: " print
    generic>> methods canonicalize-specializers drop sort-methods
    keys [ niceify-method ] map stack. ;

: forget-method ( specializer generic -- )
    [ delete-at ] with-methods ;

: method>spec ( method -- spec )
    [ "multi-method-specializer" word-prop ]
    [ "multi-method-generic" word-prop ] bi prefix ;

: define-generic ( word -- )
    dup "multi-methods" word-prop [
        drop
    ] [
        [ H{ } clone "multi-methods" set-word-prop ]
        [ update-generic ]
        bi
    ] if ;

! Syntax
: GENERIC:
    CREATE define-generic ; parsing

: parse-method ( -- quot classes generic )
    parse-definition [ 2 tail ] [ second ] [ first ] tri ;

: create-method-in ( specializer generic -- method )
    create-method dup save-location f set-word ;

: CREATE-METHOD
    scan-word scan-object swap create-method-in ;

: (METHOD:) CREATE-METHOD parse-definition ;

: METHOD: (METHOD:) define ; parsing

! For compatibility
: M:
    scan-word 1array scan-word create-method-in
    parse-definition
    define ; parsing

! Definition protocol. We qualify core generics here
USE: qualified
QUALIFIED: syntax

syntax:M: generic definer drop \ GENERIC: f ;

syntax:M: generic definition drop f ;

PREDICATE: method-spec < array
    unclip generic? >r [ class? ] all? r> and ;

syntax:M: method-spec where
    dup unclip method [ ] [ first ] ?if where ;

syntax:M: method-spec set-where
    unclip method set-where ;

syntax:M: method-spec definer
    unclip method definer ;

syntax:M: method-spec definition
    unclip method definition ;

syntax:M: method-spec synopsis*
    unclip method synopsis* ;

syntax:M: method-spec forget*
    unclip method forget* ;

syntax:M: method-body definer
    drop \ METHOD: \ ; ;

syntax:M: method-body synopsis*
    dup definer.
    [ "multi-method-generic" word-prop pprint-word ]
    [ "multi-method-specializer" word-prop pprint* ] bi ;
