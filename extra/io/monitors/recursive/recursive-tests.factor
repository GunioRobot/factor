USING: accessors math kernel namespaces continuations
io.files io.monitors io.monitors.recursive io.backend
concurrency.mailboxes
tools.test ;
IN: io.monitors.recursive.tests

\ pump-thread must-infer

SINGLETON: mock-io-backend

TUPLE: counter i ;

SYMBOL: dummy-monitor-created
SYMBOL: dummy-monitor-disposed

TUPLE: dummy-monitor < monitor ;

M: dummy-monitor dispose
    drop dummy-monitor-disposed get [ 1+ ] change-i drop ;

M: mock-io-backend (monitor)
    nip
    over exists? [
        dummy-monitor construct-monitor
        dummy-monitor-created get [ 1+ ] change-i drop
    ] [
        "Does not exist" throw
    ] if ;

M: mock-io-backend link-info
    global [ link-info ] bind ;

[ ] [ 0 counter construct-boa dummy-monitor-created set ] unit-test
[ ] [ 0 counter construct-boa dummy-monitor-disposed set ] unit-test

[ ] [
    mock-io-backend io-backend [
        "" resource-path <mailbox> <recursive-monitor> dispose
    ] with-variable
] unit-test

[ t ] [ dummy-monitor-created get i>> 0 > ] unit-test

[ t ] [ dummy-monitor-created get i>> dummy-monitor-disposed get i>> = ] unit-test

[ "doesnotexist" temp-file delete-tree ] ignore-errors

[
    mock-io-backend io-backend [
        "doesnotexist" temp-file <mailbox> <recursive-monitor> dispose
    ] with-variable
] must-fail

[ ] [
    mock-io-backend io-backend [
        "" resource-path <mailbox> <recursive-monitor>
        [ dispose ] [ dispose ] bi
    ] with-variable
] unit-test
