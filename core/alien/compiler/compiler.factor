! Copyright (C) 2006, 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: arrays generator generator.registers generator.fixup
hashtables kernel math namespaces sequences words
inference.state inference.backend inference.dataflow system
math.parser classes alien.arrays alien.c-types alien.structs
alien.syntax cpu.architecture alien inspector quotations assocs
kernel.private threads continuations.private libc combinators
compiler.errors continuations layouts accessors ;
IN: alien.compiler

TUPLE: #alien-node < node return parameters abi ;

TUPLE: #alien-callback < #alien-node quot xt ;

TUPLE: #alien-indirect < #alien-node ;

TUPLE: #alien-invoke < #alien-node library function ;

: large-struct? ( ctype -- ? )
    dup c-struct? [
        heap-size struct-small-enough? not
    ] [
        drop f
    ] if ;

: alien-node-parameters* ( node -- seq )
    dup parameters>>
    swap return>> large-struct? [ "void*" prefix ] when ;

: alien-node-return* ( node -- ctype )
    return>> dup large-struct? [ drop "void" ] when ;

: c-type-stack-align ( type -- align )
    dup c-type-stack-align? [ c-type-align ] [ drop cell ] if ;

: parameter-align ( n type -- n delta )
    over >r c-type-stack-align align dup r> - ;

: parameter-sizes ( types -- total offsets )
    #! Compute stack frame locations.
    [
        0 [
            [ parameter-align drop dup , ] keep stack-size +
        ] reduce cell align
    ] { } make ;

: return-size ( ctype -- n )
    #! Amount of space we reserve for a return value.
    dup large-struct? [ heap-size ] [ drop 0 ] if ;

: alien-stack-frame ( node -- n )
    alien-node-parameters* parameter-sizes drop ;

: alien-invoke-frame ( node -- n )
    #! One cell is temporary storage, temp@
    dup return>> return-size
    swap alien-stack-frame +
    cell + ;

: set-stack-frame ( n -- )
    dup [ frame-required ] when* \ stack-frame set ;

: with-stack-frame ( n quot -- )
    swap set-stack-frame
    call
    f set-stack-frame ; inline

GENERIC: reg-size ( register-class -- n )

M: int-regs reg-size drop cell ;

M: single-float-regs reg-size drop 4 ;

M: double-float-regs reg-size drop 8 ;

GENERIC: reg-class-variable ( register-class -- symbol )

M: reg-class reg-class-variable ;

M: float-regs reg-class-variable drop float-regs ;

GENERIC: inc-reg-class ( register-class -- )

M: reg-class inc-reg-class
    dup reg-class-variable inc
    fp-shadows-int? [ reg-size stack-params +@ ] [ drop ] if ;

M: float-regs inc-reg-class
    dup call-next-method
    fp-shadows-int? [ reg-size cell /i int-regs +@ ] [ drop ] if ;

: reg-class-full? ( class -- ? )
    [ reg-class-variable get ] [ param-regs length ] bi >= ;

: spill-param ( reg-class -- n reg-class )
    stack-params get
    >r reg-size stack-params +@ r>
    stack-params ;

: fastcall-param ( reg-class -- n reg-class )
    [ reg-class-variable get ] [ inc-reg-class ] [ ] tri ;

: alloc-parameter ( parameter -- reg reg-class )
    c-type-reg-class dup reg-class-full?
    [ spill-param ] [ fastcall-param ] if
    [ param-reg ] keep ;

: (flatten-int-type) ( size -- )
    cell /i "void*" c-type <repetition> % ;

GENERIC: flatten-value-type ( type -- )

M: object flatten-value-type , ;

M: struct-type flatten-value-type ( type -- )
    stack-size cell align (flatten-int-type) ;

M: long-long-type flatten-value-type ( type -- )
    stack-size cell align (flatten-int-type) ;

: flatten-value-types ( params -- params )
    #! Convert value type structs to consecutive void*s.
    [
        0 [
            c-type
            [ parameter-align (flatten-int-type) ] keep
            [ stack-size cell align + ] keep
            flatten-value-type
        ] reduce drop
    ] { } make ;

: each-parameter ( parameters quot -- )
    >r [ parameter-sizes nip ] keep r> 2each ; inline

: reverse-each-parameter ( parameters quot -- )
    >r [ parameter-sizes nip ] keep r> 2reverse-each ; inline

: reset-freg-counts ( -- )
    { int-regs float-regs stack-params } [ 0 swap set ] each ;

: with-param-regs ( quot -- )
    #! In quot you can call alloc-parameter
    [ reset-freg-counts call ] with-scope ; inline

: move-parameters ( node word -- )
    #! Moves values from C stack to registers (if word is
    #! %load-param-reg) and registers to C stack (if word is
    #! %save-param-reg).
    >r
    alien-node-parameters*
    flatten-value-types
    r> [ >r alloc-parameter r> execute ] curry each-parameter ;
    inline

: if-void ( type true false -- )
    pick "void" = [ drop nip call ] [ nip call ] if ; inline

: alien-invoke-stack ( node extra -- )
    over parameters>> length + dup reify-curries
    over consume-values
    dup return>> "void" = 0 1 ?
    swap produce-values ;

: (make-prep-quot) ( parameters -- )
    dup empty? [
        drop
    ] [
        unclip c-type c-type-prep %
        \ >r , (make-prep-quot) \ r> ,
    ] if ;

: make-prep-quot ( node -- quot )
    parameters>>
    [ <reversed> (make-prep-quot) ] [ ] make ;

: unbox-parameters ( offset node -- )
    parameters>> [
        %prepare-unbox >r over + r> unbox-parameter
    ] reverse-each-parameter drop ;

: prepare-box-struct ( node -- offset )
    #! Return offset on C stack where to store unboxed
    #! parameters. If the C function is returning a structure,
    #! the first parameter is an implicit target area pointer,
    #! so we need to use a different offset.
    return>> dup large-struct?
    [ heap-size %prepare-box-struct cell ] [ drop 0 ] if ;

: objects>registers ( node -- )
    #! Generate code for unboxing a list of C types, then
    #! generate code for moving these parameters to register on
    #! architectures where parameters are passed in registers.
    [
        [ prepare-box-struct ] keep
        [ unbox-parameters ] keep
        \ %load-param-reg move-parameters
    ] with-param-regs ;

: box-return* ( node -- )
    return>> [ ] [ box-return ] if-void ;

M: alien-invoke-error summary
    drop
    "Words calling ``alien-invoke'' must be compiled with the optimizing compiler." ;

: pop-parameters pop-literal nip [ expand-constants ] map ;

: stdcall-mangle ( symbol node -- symbol )
    "@"
    swap parameters>> parameter-sizes drop
    number>string 3append ;

TUPLE: no-such-library name ;

M: no-such-library summary
    drop "Library not found" ;

M: no-such-library compiler-error-type
    drop +linkage+ ;

: no-such-library ( name -- )
    \ no-such-library construct-boa
    compiling-word get compiler-error ;

TUPLE: no-such-symbol name ;

M: no-such-symbol summary
    drop "Symbol not found" ;

M: no-such-symbol compiler-error-type
    drop +linkage+ ;

: no-such-symbol ( name -- )
    \ no-such-symbol construct-boa
    compiling-word get compiler-error ;

: check-dlsym ( symbols dll -- )
    dup dll-valid? [
        dupd [ dlsym ] curry contains?
        [ drop ] [ no-such-symbol ] if
    ] [
        dll-path no-such-library drop
    ] if ;

: alien-invoke-dlsym ( node -- symbols dll )
    dup function>> dup pick stdcall-mangle 2array
    swap library>> library dup [ dll>> ] when
    2dup check-dlsym ;

\ alien-invoke [
    ! Four literals
    4 ensure-values
    #alien-invoke construct-empty
    ! Compile-time parameters
    pop-parameters >>parameters
    pop-literal nip >>function
    pop-literal nip >>library
    pop-literal nip >>return
    ! Quotation which coerces parameters to required types
    dup make-prep-quot recursive-state get infer-quot
    ! Set ABI
    dup library>>
    library [ abi>> ] [ "cdecl" ] if*
    >>abi
    ! Add node to IR
    dup node,
    ! Magic #: consume exactly the number of inputs
    0 alien-invoke-stack
] "infer" set-word-prop

M: #alien-invoke generate-node
    dup alien-invoke-frame [
        end-basic-block
        %prepare-alien-invoke
        dup objects>registers
        %prepare-var-args
        dup alien-invoke-dlsym %alien-invoke
        dup %cleanup
        box-return*
        iterate-next
    ] with-stack-frame ;

M: alien-indirect-error summary
    drop "Words calling ``alien-indirect'' must be compiled with the optimizing compiler." ;

\ alien-indirect [
    ! Three literals and function pointer
    4 ensure-values
    4 reify-curries
    #alien-indirect construct-empty
    ! Compile-time parameters
    pop-literal nip >>abi
    pop-parameters >>parameters
    pop-literal nip >>return
    ! Quotation which coerces parameters to required types
    dup make-prep-quot [ dip ] curry recursive-state get infer-quot
    ! Add node to IR
    dup node,
    ! Magic #: consume the function pointer, too
    1 alien-invoke-stack
] "infer" set-word-prop

M: #alien-indirect generate-node
    dup alien-invoke-frame [
        ! Flush registers
        end-basic-block
        ! Save registers for GC
        %prepare-alien-invoke
        ! Save alien at top of stack to temporary storage
        %prepare-alien-indirect
        dup objects>registers
        %prepare-var-args
        ! Call alien in temporary storage
        %alien-indirect
        dup %cleanup
        box-return*
        iterate-next
    ] with-stack-frame ;

! Callbacks are registered in a global hashtable. If you clear
! this hashtable, they will all be blown away by code GC, beware
SYMBOL: callbacks

callbacks global [ H{ } assoc-like ] change-at

: register-callback ( word -- ) dup callbacks get set-at ;

M: alien-callback-error summary
    drop "Words calling ``alien-callback'' must be compiled with the optimizing compiler." ;

: callback-bottom ( node -- )
    xt>> [ word-xt drop <alien> ] curry
    recursive-state get infer-quot ;

\ alien-callback [
    4 ensure-values
    #alien-callback construct-empty dup node,
    pop-literal nip >>quot
    pop-literal nip >>abi
    pop-parameters >>parameters
    pop-literal nip >>return
    gensym dup register-callback >>xt
    callback-bottom
] "infer" set-word-prop

: box-parameters ( node -- )
    alien-node-parameters* [ box-parameter ] each-parameter ;

: registers>objects ( node -- )
    [
        dup \ %save-param-reg move-parameters
        "nest_stacks" f %alien-invoke
        box-parameters
    ] with-param-regs ;

TUPLE: callback-context ;

: current-callback 2 getenv ;

: wait-to-return ( token -- )
    dup current-callback eq? [
        drop
    ] [
        yield wait-to-return
    ] if ;

: do-callback ( quot token -- )
    init-catchstack
    dup 2 setenv
    slip
    wait-to-return ; inline

: prepare-callback-return ( ctype -- quot )
    return>> {
        { [ dup "void" = ] [ drop [ ] ] }
        { [ dup large-struct? ] [ heap-size [ memcpy ] curry ] }
        [ c-type c-type-prep ]
    } cond ;

: wrap-callback-quot ( node -- quot )
    [
        [ quot>> ] [ prepare-callback-return ] bi append ,
        [ callback-context construct-empty do-callback ] %
    ] [ ] make ;

: %unnest-stacks ( -- ) "unnest_stacks" f %alien-invoke ;

: callback-unwind ( node -- n )
    {
        { [ dup abi>> "stdcall" = ] [ alien-stack-frame ] }
        { [ dup return>> large-struct? ] [ drop 4 ] }
        [ drop 0 ]
    } cond ;

: %callback-return ( node -- )
    #! All the extra book-keeping for %unwind is only for x86.
    #! On other platforms its an alias for %return.
    dup alien-node-return*
    [ %unnest-stacks ] [ %callback-value ] if-void
    callback-unwind %unwind ;

: generate-callback ( node -- )
    dup xt>> dup [
        init-templates
        %save-word-xt
        %prologue-later
        dup alien-stack-frame [
            dup registers>objects
            dup wrap-callback-quot %alien-callback
            %callback-return
        ] with-stack-frame
    ] with-generator ;

M: #alien-callback generate-node
    end-basic-block generate-callback iterate-next ;
