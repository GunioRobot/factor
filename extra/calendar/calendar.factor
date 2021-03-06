! Copyright (C) 2007 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.

USING: arrays kernel math math.functions namespaces sequences
strings system vocabs.loader calendar.backend threads
accessors combinators locals classes.tuple ;
IN: calendar

TUPLE: timestamp year month day hour minute second gmt-offset ;

C: <timestamp> timestamp

TUPLE: duration year month day hour minute second ;

C: <duration> duration

: gmt-offset-duration ( -- duration )
    0 0 0 gmt-offset <duration> ;

: <date> ( year month day -- timestamp )
    0 0 0 gmt-offset-duration <timestamp> ;

: month-names
    {
        "Not a month" "January" "February" "March" "April" "May" "June"
        "July" "August" "September" "October" "November" "December"
    } ;

: month-abbreviations
    {
        "Not a month"
        "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"
    } ;

: day-names
    {
        "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"
    } ;

: day-abbreviations2 { "Su" "Mo" "Tu" "We" "Th" "Fr" "Sa" } ;
: day-abbreviations3 { "Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat" } ;

: average-month 30+5/12 ; inline
: months-per-year 12 ; inline
: days-per-year 3652425/10000 ; inline
: hours-per-year 876582/100 ; inline
: minutes-per-year 5259492/10 ; inline
: seconds-per-year 31556952 ; inline

<PRIVATE

SYMBOL: a
SYMBOL: b
SYMBOL: c
SYMBOL: d
SYMBOL: e
SYMBOL: y
SYMBOL: m

PRIVATE>

:: julian-day-number ( year month day -- n )
    #! Returns a composite date number
    #! Not valid before year -4800
    [let* | a [ 14 month - 12 /i ]
            y [ year 4800 + a - ]
            m [ month 12 a * + 3 - ] |
        day 153 m * 2 + 5 /i + 365 y * +
        y 4 /i + y 100 /i - y 400 /i + 32045 -
    ] ;

:: julian-day-number>date ( n -- year month day )
    #! Inverse of julian-day-number
    [let* | a [ n 32044 + ]
            b [ 4 a * 3 + 146097 /i ]
            c [ a 146097 b * 4 /i - ]
            d [ 4 c * 3 + 1461 /i ]
            e [ c 1461 d * 4 /i - ]
            m [ 5 e * 2 + 153 /i ] |
        100 b * d + 4800 -
        m 10 /i + m 3 +
        12 m 10 /i * -
        e 153 m * 2 + 5 /i - 1+
    ] ;

: >date< ( timestamp -- year month day )
    [ year>> ] [ month>> ] [ day>> ] tri ;

: >time< ( timestamp -- hour minute second )
    [ hour>> ] [ minute>> ] [ second>> ] tri ;

: instant ( -- dt ) 0 0 0 0 0 0 <duration> ;
: years ( n -- dt ) instant swap >>year ;
: months ( n -- dt ) instant swap >>month ;
: days ( n -- dt ) instant swap >>day ;
: weeks ( n -- dt ) 7 * days ;
: hours ( n -- dt ) instant swap >>hour ;
: minutes ( n -- dt ) instant swap >>minute ;
: seconds ( n -- dt ) instant swap >>second ;
: milliseconds ( n -- dt ) 1000 / seconds ;

GENERIC: leap-year? ( obj -- ? )

M: integer leap-year? ( year -- ? )
    dup 100 mod zero? 400 4 ? mod zero? ;

M: timestamp leap-year? ( timestamp -- ? )
    year>> leap-year? ;

<PRIVATE

GENERIC: +year ( timestamp x -- timestamp )
GENERIC: +month ( timestamp x -- timestamp )
GENERIC: +day ( timestamp x -- timestamp )
GENERIC: +hour ( timestamp x -- timestamp )
GENERIC: +minute ( timestamp x -- timestamp )
GENERIC: +second ( timestamp x -- timestamp )

: /rem ( f n -- q r )
    #! q is positive or negative, r is positive from 0 <= r < n
    [ / floor >integer ] 2keep rem ;

: float>whole-part ( float -- int float )
    [ floor >integer ] keep over - ;

: adjust-leap-year ( timestamp -- timestamp )
    dup day>> 29 = over month>> 2 = pick leap-year? not and and
    [ 3 >>month 1 >>day ] when ;

: unless-zero >r dup zero? [ drop ] r> if ; inline

M: integer +year ( timestamp n -- timestamp )
    [ [ + ] curry change-year adjust-leap-year ] unless-zero ;

M: real +year ( timestamp n -- timestamp )
    [ float>whole-part swapd days-per-year * +day swap +year ] unless-zero ;

: months/years ( n -- months years )
    12 /rem dup zero? [ drop 1- 12 ] when swap ; inline

M: integer +month ( timestamp n -- timestamp )
    [ over month>> + months/years >r >>month r> +year ] unless-zero ;

M: real +month ( timestamp n -- timestamp )
    [ float>whole-part swapd average-month * +day swap +month ] unless-zero ;

M: integer +day ( timestamp n -- timestamp )
    [
        over >date< julian-day-number + julian-day-number>date
        >r >r >>year r> >>month r> >>day
    ] unless-zero ;

M: real +day ( timestamp n -- timestamp )
    [ float>whole-part swapd 24 * +hour swap +day ] unless-zero ;

: hours/days ( n -- hours days )
    24 /rem swap ;

M: integer +hour ( timestamp n -- timestamp )
    [ over hour>> + hours/days >r >>hour r> +day ] unless-zero ;

M: real +hour ( timestamp n -- timestamp )
    float>whole-part swapd 60 * +minute swap +hour ;

: minutes/hours ( n -- minutes hours )
    60 /rem swap ;

M: integer +minute ( timestamp n -- timestamp )
    [ over minute>> + minutes/hours >r >>minute r> +hour ] unless-zero ;

M: real +minute ( timestamp n -- timestamp )
    [ float>whole-part swapd 60 * +second swap +minute ] unless-zero ;

: seconds/minutes ( n -- seconds minutes )
    60 /rem swap >integer ;

M: number +second ( timestamp n -- timestamp )
    [ over second>> + seconds/minutes >r >>second r> +minute ] unless-zero ;

: (time+)
    [ second>> +second ] keep
    [ minute>> +minute ] keep
    [ hour>>   +hour   ] keep
    [ day>>    +day    ] keep
    [ month>>  +month  ] keep
    [ year>>   +year   ] keep ; inline

: +slots [ bi@ + ] curry 2keep ; inline

PRIVATE>

GENERIC# time+ 1 ( time dt -- time )

M: timestamp time+
    >r clone r> (time+) drop ;

M: duration time+
    dup timestamp? [
        swap time+
    ] [
        [ year>> ] +slots
        [ month>> ] +slots
        [ day>> ] +slots
        [ hour>> ] +slots
        [ minute>> ] +slots
        [ second>> ] +slots
        2drop <duration>
    ] if ;

: dt>years ( dt -- x )
    #! Uses average month/year length since dt loses calendar
    #! data
    0 swap
    [ year>> + ] keep
    [ month>> months-per-year / + ] keep
    [ day>> days-per-year / + ] keep
    [ hour>> hours-per-year / + ] keep
    [ minute>> minutes-per-year / + ] keep
    second>> seconds-per-year / + ;

M: duration <=> [ dt>years ] compare ;

: dt>months ( dt -- x ) dt>years months-per-year * ;
: dt>days ( dt -- x ) dt>years days-per-year * ;
: dt>hours ( dt -- x ) dt>years hours-per-year * ;
: dt>minutes ( dt -- x ) dt>years minutes-per-year * ;
: dt>seconds ( dt -- x ) dt>years seconds-per-year * ;
: dt>milliseconds ( dt -- x ) dt>seconds 1000 * ;

GENERIC: time- ( time1 time2 -- time )

: convert-timezone ( timestamp duration -- timestamp )
    over gmt-offset>> over = [ drop ] [
        [ over gmt-offset>> time- time+ ] keep >>gmt-offset
    ] if ;

: >local-time ( timestamp -- timestamp )
    gmt-offset-duration convert-timezone ;

: >gmt ( timestamp -- timestamp )
    instant convert-timezone ;

M: timestamp <=> ( ts1 ts2 -- n )
    [ >gmt tuple-slots ] compare ;

: (time-) ( timestamp timestamp -- n )
    [ >gmt ] bi@
    [ [ >date< julian-day-number ] bi@ - 86400 * ] 2keep
    [ >time< >r >r 3600 * r> 60 * r> + + ] bi@ - + ;

M: timestamp time-
    #! Exact calendar-time difference
    (time-) seconds ;

: before ( dt -- -dt )
    [ year>>   neg ] keep
    [ month>>  neg ] keep
    [ day>>    neg ] keep
    [ hour>>   neg ] keep
    [ minute>> neg ] keep
      second>> neg
    <duration> ;

M: duration time-
    before time+ ;

: <zero> 0 0 0 0 0 0 instant <timestamp> ;

: valid-timestamp? ( timestamp -- ? )
    clone instant >>gmt-offset
    dup <zero> time- <zero> time+ = ;

: unix-1970 ( -- timestamp )
    1970 1 1 0 0 0 instant <timestamp> ; foldable

: millis>timestamp ( n -- timestamp )
    >r unix-1970 r> milliseconds time+ ;

: timestamp>millis ( timestamp -- n )
    unix-1970 (time-) 1000 * >integer ;

: gmt ( -- timestamp )
    #! GMT time, right now
    unix-1970 millis milliseconds time+ ;

: now ( -- timestamp ) gmt >local-time ;

: from-now ( dt -- timestamp ) now swap time+ ;
: ago ( dt -- timestamp ) now swap time- ;

: day-counts { 0 31 28 31 30 31 30 31 31 30 31 30 31 } ; inline

: zeller-congruence ( year month day -- n )
    #! Zeller Congruence
    #! http://web.textfiles.com/computers/formulas.txt
    #! good for any date since October 15, 1582
    >r dup 2 <= [ 12 + >r 1- r> ] when
    >r dup [ 4 /i + ] keep [ 100 /i - ] keep 400 /i + r>
        [ 1+ 3 * 5 /i + ] keep 2 * + r>
    1+ + 7 mod ;

GENERIC: days-in-year ( obj -- n )

M: integer days-in-year ( year -- n ) leap-year? 366 365 ? ;
M: timestamp days-in-year ( timestamp -- n ) year>> days-in-year ;

GENERIC: days-in-month ( obj -- n )

M: array days-in-month ( obj -- n )
    first2 dup 2 = [
        drop leap-year? 29 28 ?
    ] [
        nip day-counts nth
    ] if ;

M: timestamp days-in-month ( timestamp -- n )
    >date< drop 2array days-in-month ;

GENERIC: day-of-week ( obj -- n )

M: timestamp day-of-week ( timestamp -- n )
    >date< zeller-congruence ;

M: array day-of-week ( array -- n )
    first3 zeller-congruence ;

GENERIC: day-of-year ( obj -- n )

M: array day-of-year ( array -- n )
    first3
    3dup day-counts rot head-slice sum +
    swap leap-year? [
        -roll
        pick 3 1 <date> >r <date> r>
        after=? [ 1+ ] when
    ] [
        >r 3drop r>
    ] if ;

M: timestamp day-of-year ( timestamp -- n )
    >date< 3array day-of-year ;

: day-offset ( timestamp m -- timestamp n )
    over day-of-week - ; inline

: day-this-week ( timestamp n -- timestamp )
    day-offset days time+ ;

: sunday ( timestamp -- timestamp ) 0 day-this-week ;
: monday ( timestamp -- timestamp ) 1 day-this-week ;
: tuesday ( timestamp -- timestamp ) 2 day-this-week ;
: wednesday ( timestamp -- timestamp ) 3 day-this-week ;
: thursday ( timestamp -- timestamp ) 4 day-this-week ;
: friday ( timestamp -- timestamp ) 5 day-this-week ;
: saturday ( timestamp -- timestamp ) 6 day-this-week ;

: beginning-of-day ( timestamp -- new-timestamp )
    clone
    0 >>hour
    0 >>minute
    0 >>second ; inline

: beginning-of-month ( timestamp -- new-timestamp )
    beginning-of-day 1 >>day ;

: beginning-of-week ( timestamp -- new-timestamp )
    beginning-of-day sunday ;

: beginning-of-year ( timestamp -- new-timestamp )
    beginning-of-month 1 >>month ;

: time-since-midnight ( timestamp -- duration )
    dup beginning-of-day time- ;

M: timestamp sleep-until timestamp>millis sleep-until ;

M: duration sleep from-now sleep-until ;

{
    { [ os unix? ] [ "calendar.unix" ] }
    { [ os windows? ] [ "calendar.windows" ] }
} cond require
