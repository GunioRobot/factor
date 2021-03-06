! Copyright (C) 2006, 2007 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel cpu.ppc.architecture cpu.ppc.assembler
kernel.private namespaces math sequences generic arrays
generator generator.registers generator.fixup system layouts
cpu.architecture alien ;
IN: cpu.ppc.allot

: load-zone-ptr ( reg -- )
    "nursery" f pick %load-dlsym dup 0 LWZ ;

: %allot ( header size -- )
    #! Store a pointer to 'size' bytes allocated from the
    #! nursery in r11.
    8 align ! align the size
    12 load-zone-ptr ! nusery -> r12
    11 12 cell LWZ ! nursery.here -> r11
    11 11 pick ADDI ! increment r11
    11 12 cell STW ! r11 -> nursery.here
    11 11 rot SUBI ! old value
    type-number tag-fixnum 12 LI ! compute header
    12 11 0 STW ! store header
    ;

: %store-tagged ( reg tag -- )
    >r dup fresh-object v>operand 11 r> tag-number ORI ;

: %allot-float ( reg -- )
    #! exits with tagged ptr to object in r12, untagged in r11
    float 16 %allot
    11 8 STFD
    12 11 float tag-number ORI
    f fresh-object ;

M: ppc %box-float ( dst src -- )
    [ v>operand ] bi@ %allot-float 12 MR ;

: %allot-bignum ( #digits -- )
    #! 1 cell header, 1 cell length, 1 cell sign, + digits
    #! length is the # of digits + sign
    bignum over 3 + cells %allot
    1+ v>operand 12 LI ! compute the length
    12 11 cell STW ! store the length
    ;

: %allot-bignum-signed-1 ( reg -- )
    #! on entry, reg is a 30-bit quantity sign-extended to
    #! 32-bits.
    #! exits with tagged ptr to bignum in reg
    [
        { "end" "non-zero" "pos" "store" } [ define-label ] each
        ! is it zero?
        0 over v>operand 0 CMPI
        "non-zero" get BNE
        0 >bignum over load-literal
        "end" get B
        ! it is non-zero
        "non-zero" resolve-label
        1 %allot-bignum
        ! is the fixnum negative?
        0 over v>operand 0 CMPI
        "pos" get BGE
        1 12 LI
        ! store negative sign
        12 11 2 cells STW
        ! negate fixnum
        dup v>operand dup -1 MULI
        "store" get B
        "pos" resolve-label
        0 12 LI
        ! store positive sign
        12 11 2 cells STW
        "store" resolve-label
        ! store the number
        dup v>operand 11 3 cells STW
        ! tag the bignum, store it in reg
        bignum %store-tagged
        "end" resolve-label
    ] with-scope ;

M: ppc %box-alien ( dst src -- )
    { "end" "f" } [ define-label ] each
    0 over v>operand 0 CMPI
    "f" get BEQ
    alien 4 cells %allot
    ! Store offset
    v>operand 11 3 cells STW
    f v>operand 12 LI
    ! Store expired slot
    12 11 1 cells STW
    ! Store underlying-alien slot
    12 11 2 cells STW
    ! Store tagged ptr in reg
    dup object %store-tagged
    "end" get B
    "f" resolve-label
    f v>operand swap v>operand LI
    "end" resolve-label ;
