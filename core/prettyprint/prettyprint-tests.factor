USING: arrays definitions io.streams.string io.streams.duplex
kernel math namespaces parser prettyprint prettyprint.config
prettyprint.sections sequences tools.test vectors words
effects splitting generic.standard prettyprint.private
continuations generic compiler.units tools.walker ;
IN: prettyprint.tests

[ "4" ] [ 4 unparse ] unit-test
[ "1.0" ] [ 1.0 unparse ] unit-test
[ "1267650600228229401496703205376" ] [ 1 100 shift unparse ] unit-test

[ "+" ] [ \ + unparse ] unit-test

[ "\\ +" ] [ [ \ + ] first unparse ] unit-test

[ "{ }" ] [ { } unparse ] unit-test

[ "{ 1 2 3 }" ] [ { 1 2 3 } unparse ] unit-test

[ "\"hello\\\\backslash\"" ]
[ "hello\\backslash" unparse ]
unit-test

! [ "\"\\u123456\"" ]
! [ "\u123456" unparse ]
! unit-test

[ "\"\\e\"" ]
[ "\e" unparse ]
unit-test

[ "f" ] [ f unparse ] unit-test
[ "t" ] [ t unparse ] unit-test

[ "SBUF\" hello world\"" ] [ SBUF" hello world" unparse ] unit-test


[ "( a b -- c d )" ] [
    { "a" "b" } { "c" "d" } <effect> effect>string
] unit-test

[ "( -- c d )" ] [
    { } { "c" "d" } <effect> effect>string
] unit-test

[ "( a b -- )" ] [
    { "a" "b" } { } <effect> effect>string
] unit-test

[ "( -- )" ] [
    { } { } <effect> effect>string
] unit-test

[ "W{ \\ + }" ] [ [ W{ \ + } ] first unparse ] unit-test

[ ] [ \ fixnum see ] unit-test

[ ] [ \ integer see ] unit-test

[ ] [ \ generic see ] unit-test

[ ] [ \ duplex-stream see ] unit-test

[ "[ \\ + ]" ] [ [ \ + ] unparse ] unit-test
[ "[ \\ [ ]" ] [ [ \ [ ] unparse ] unit-test
    
[ t ] [
    100 \ dup <array> unparse-short
    "{" head?
] unit-test

: foo ( a -- b ) dup * ; inline

[ "USING: kernel math ;\nIN: prettyprint.tests\n: foo ( a -- b ) dup * ; inline\n" ]
[ [ \ foo see ] with-string-writer ] unit-test

: bar ( x -- y ) 2 + ;

[ "USING: math ;\nIN: prettyprint.tests\n: bar ( x -- y ) 2 + ;\n" ]
[ [ \ bar see ] with-string-writer ] unit-test

: blah 
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop
    drop ;

[ "drop ;" ] [
    \ blah f "inferred-effect" set-word-prop
    [ \ blah see ] with-string-writer "\n" ?tail drop 6 tail*
] unit-test

: check-see ( expect name -- )
    [
        use [ clone ] change

        [
            [ parse-fresh drop ] with-compilation-unit
            [
                "prettyprint.tests" lookup see
            ] with-string-writer "\n" split 1 head*
        ] keep =
    ] with-scope ;

: method-test
    {
        "IN: prettyprint.tests"
        "GENERIC: method-layout"
        ""
        "USING: math prettyprint.tests ;"
        "M: complex method-layout"
        "    \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""
        "    ;"
        ""
        "USING: math prettyprint.tests ;"
        "M: fixnum method-layout ;"
        ""
        "USING: math prettyprint.tests ;"
        "M: integer method-layout ;"
        ""
        "USING: kernel prettyprint.tests ;"
        "M: object method-layout ;"
    } ;

[ t ] [
    "method-layout" method-test check-see
] unit-test

: retain-stack-test
    {
        "USING: io kernel sequences words ;"
        "IN: prettyprint.tests"
        ": retain-stack-layout ( x -- )"
        "    dup stream-readln stream-readln"
        "    >r [ define ] map r>"
        "    define ;"
    } ;

[ t ] [
    "retain-stack-layout" retain-stack-test check-see
] unit-test

: soft-break-test
    {
        "USING: kernel math sequences strings ;"
        "IN: prettyprint.tests"
        ": soft-break-layout ( x y -- ? )"
        "    over string? ["
        "        over hashcode over hashcode number="
        "        [ sequence= ] [ 2drop f ] if"
        "    ] [ 2drop f ] if ;"
    } ;

[ t ] [
    "soft-break-layout" soft-break-test check-see
] unit-test

: another-retain-layout-test
    {
        "USING: kernel sequences ;"
        "IN: prettyprint.tests"
        ": another-retain-layout ( seq1 seq2 quot -- newseq )"
        "    -rot 2dup dupd min-length [ each drop roll ] map"
        "    >r 3drop r> ; inline"
    } ;

[ t ] [
    "another-retain-layout" another-retain-layout-test check-see
] unit-test

: another-soft-break-test
    {
        "USING: namespaces parser sequences ;"
        "IN: prettyprint.tests"
        ": another-soft-break-layout ( node -- quot )"
        "    parse-error-file"
        "    [ <reversed> \"hello world foo\" suffix ] [ ] make ;"
    } ;

[ t ] [
    "another-soft-break-layout" another-soft-break-test
    check-see
] unit-test

: string-layout
    {
        "USING: io kernel parser ;"
        "IN: prettyprint.tests"
        ": string-layout-test ( error -- )"
        "    \"Expected \" write dup unexpected-want expected>string write"
        "    \" but got \" write unexpected-got expected>string print ;"
    } ;


[ t ] [
    "string-layout-test" string-layout check-see
] unit-test

! Define dummy words for the below...
: <NSRect> ( a b c d -- e ) ;
: <PixelFormat> ( -- fmt ) ;
: send ( obj -- ) ;

\ send soft "break-after" set-word-prop

: final-soft-break-test
    {
        "USING: kernel sequences ;"
        "IN: prettyprint.tests"
        ": final-soft-break-layout ( class dim -- view )"
        "    >r \"alloc\" send 0 0 r>"
        "    first2 <NSRect>"
        "    <PixelFormat> \"initWithFrame:pixelFormat:\" send"
        "    dup 1 \"setPostsBoundsChangedNotifications:\" send"
        "    dup 1 \"setPostsFrameChangedNotifications:\" send ;"
    } ;

[ t ] [
    "final-soft-break-layout" final-soft-break-test check-see
] unit-test

: narrow-test
    {
        "USING: arrays combinators continuations kernel sequences ;"
        "IN: prettyprint.tests"
        ": narrow-layout ( obj -- )"
        "    {"
        "        { [ dup continuation? ] [ append ] }"
        "        { [ dup not ] [ drop reverse ] }"
        "        { [ dup pair? ] [ delete ] }"
        "    } cond ;"
    } ;

[ t ] [
    "narrow-layout" narrow-test check-see
] unit-test

: another-narrow-test
    {
        "IN: prettyprint.tests"
        ": another-narrow-layout ( -- obj )"
        "    H{"
        "        { 1 2 }"
        "        { 3 4 }"
        "        { 5 6 }"
        "        { 7 8 }"
        "        { 9 10 }"
        "        { 11 12 }"
        "        { 13 14 }"
        "    } ;"
    } ;

[ t ] [
    "another-narrow-layout" another-narrow-test check-see
] unit-test

: class-see-test
    {
        "IN: prettyprint.tests"
        "TUPLE: class-see-layout ;"
        ""
        "IN: prettyprint.tests"
        "GENERIC: class-see-layout ( x -- y )"
        ""
        "USING: prettyprint.tests ;"
        "M: class-see-layout class-see-layout ;"
    } ;

[ t ] [
    "class-see-layout" class-see-test check-see
] unit-test

[ ] [ \ effect-in synopsis drop ] unit-test

! Regression
[ t ] [
    "IN: prettyprint.tests\nGENERIC: generic-decl-test ( a -- b ) flushable\n"
    dup eval
    "generic-decl-test" "prettyprint.tests" lookup
    [ see ] with-string-writer =
] unit-test

[ [ + ] ] [
    [ \ + (step-into-execute) ] (remove-breakpoints)
] unit-test

[ [ (step-into-execute) ] ] [
    [ (step-into-execute) ] (remove-breakpoints)
] unit-test

[ [ 2 2 + . ] ] [
    [ 2 2 \ + (step-into-execute) . ] (remove-breakpoints)
] unit-test

[ [ 2 2 + . ] ] [
    [ 2 break 2 \ + (step-into-execute) . ] (remove-breakpoints)
] unit-test

[ ] [ 1 \ + curry unparse drop ] unit-test

[ ] [ 1 \ + compose unparse drop ] unit-test

GENERIC: generic-see-test-with-f ( obj -- obj )

M: f generic-see-test-with-f ;

[ "USING: prettyprint.tests ;\nM: f generic-see-test-with-f ;\n" ] [
    [ { POSTPONE: f generic-see-test-with-f } see ] with-string-writer
] unit-test

[ "USING: prettyprint.tests ;\nM: f generic-see-test-with-f ;\n" ] [
    [ \ f \ generic-see-test-with-f method see ] with-string-writer
] unit-test

PREDICATE: predicate-see-test < integer even? ;

[ "USING: math ;\nIN: prettyprint.tests\nPREDICATE: predicate-see-test < integer even? ;\n" ] [
    [ \ predicate-see-test see ] with-string-writer
] unit-test

[ ] [ \ compose see ] unit-test
[ ] [ \ curry see ] unit-test
