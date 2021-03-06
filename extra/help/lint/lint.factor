! Copyright (C) 2006, 2007 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: sequences parser kernel help help.markup help.topics
words strings classes tools.vocabs namespaces io
io.streams.string prettyprint definitions arrays vectors
combinators splitting debugger hashtables sorting effects vocabs
vocabs.loader assocs editors continuations classes.predicate
macros combinators.lib sequences.lib math ;
IN: help.lint

: check-example ( element -- )
    1 tail [
        1 head* "\n" join 1vector
        [
            use [ clone ] change
            [ eval>string ] with-datastack
        ] with-scope peek "\n" ?tail drop
    ] keep
    peek assert= ;

: check-examples ( word element -- )
    nip \ $example swap elements [ check-example ] each ;

: extract-values ( element -- seq )
    \ $values swap elements dup empty? [
        first 1 tail [ first ] map prune natural-sort
    ] unless ;

: effect-values ( word -- seq )
    stack-effect dup effect-in swap effect-out append [
        {
            { [ dup word? ] [ word-name ] }
            { [ dup integer? ] [ drop "object" ] }
            { [ dup string? ] [ ] }
        } cond
    ] map prune natural-sort ;

: contains-funky-elements? ( element -- ? )
    {
        $shuffle
        $values-x/y
        $predicate
        $class-description
        $error-description
    } swap [ elements f like ] curry contains? ;

: check-values ( word element -- )
    {
        [ over "declared-effect" word-prop ]
        [ dup contains-funky-elements? not ]
        [ over macro? not ]
        [
            2dup extract-values >array
            >r effect-values >array
            r> assert=
            t
        ]
    } && 3drop ;

: check-see-also ( word element -- )
    nip \ $see-also swap elements [
        1 tail dup prune [ length ] bi@ assert=
    ] each ;

: vocab-exists? ( name -- ? )
    dup vocab swap "all-vocabs" get member? or ;

: check-modules ( word element -- )
    nip \ $vocab-link swap elements [
        second
        vocab-exists? [ "Missing vocabulary" throw ] unless
    ] each ;

: check-rendering ( word element -- )
    [ help ] with-string-writer drop ;

: all-word-help ( words -- seq )
    [ word-help ] subset ;

TUPLE: help-error topic ;

: <help-error> ( topic delegate -- error )
    { set-help-error-topic set-delegate } help-error construct ;

M: help-error error.
    "In " write dup help-error-topic ($link) nl
    delegate error. ;

: check-something ( obj quot -- )
    flush [ <help-error> , ] recover ; inline

: check-word ( word -- )
    dup word-help [
        [
            dup word-help [
                2dup check-examples
                2dup check-values
                2dup check-see-also
                2dup check-modules
                2dup drop check-rendering
            ] assert-depth 2drop
        ] check-something
    ] [ drop ] if ;

: check-words ( words -- ) [ check-word ] each ;

: check-article ( article -- )
    [
        [ dup check-rendering ] assert-depth drop
    ] check-something ;

: group-articles ( -- assoc )
    articles get keys
    vocabs [ dup vocab-docs-path swap ] H{ } map>assoc
    H{ } clone [
        [
            >r >r dup >link where ?first r> at r> [ ?push ] change-at
        ] 2curry each
    ] keep ;

: check-vocab ( vocab -- seq )
    "Checking " write dup write "..." print
    [
        dup words [ check-word ] each
        "vocab-articles" get at [ check-article ] each
    ] { } make ;

: run-help-lint ( prefix -- alist )
    [
        all-vocabs-seq [ vocab-name ] map "all-vocabs" set
        articles get keys "group-articles" set
        child-vocabs
        [ dup check-vocab ] { } map>assoc
        [ nip empty? not ] assoc-subset
    ] with-scope ;

: typos. ( assoc -- )
    dup empty? [
        drop
        "==== ALL CHECKS PASSED" print
    ] [
        [
            swap vocab-heading.
            [ error. nl ] each
        ] assoc-each
    ] if ;

: help-lint ( prefix -- ) run-help-lint typos. ;

: help-lint-all ( -- ) "" help-lint ;

: unlinked-words ( words -- seq )
    all-word-help [ article-parent not ] subset ;

: linked-undocumented-words ( -- seq )
    all-words
    [ word-help not ] subset
    [ article-parent ] subset
    [ "predicating" word-prop not ] subset ;

MAIN: help-lint
