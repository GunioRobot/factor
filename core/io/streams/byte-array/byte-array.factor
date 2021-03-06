USING: byte-arrays byte-vectors kernel io.encodings io.streams.string
sequences io namespaces io.encodings.private ;
IN: io.streams.byte-array

: <byte-writer> ( encoding -- stream )
    512 <byte-vector> swap <encoder> ;

: with-byte-writer ( encoding quot -- byte-array )
    >r <byte-writer> r> [ stdio get ] compose with-stream*
    dup encoder? [ encoder-stream ] when >byte-array ; inline

: <byte-reader> ( byte-array encoding -- stream )
    >r >byte-vector dup reverse-here r> <decoder> ;

: with-byte-reader ( byte-array encoding quot -- )
    >r <byte-reader> r> with-stream ; inline
