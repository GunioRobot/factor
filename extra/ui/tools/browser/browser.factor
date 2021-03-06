! Copyright (C) 2006, 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: debugger ui.tools.workspace help help.topics kernel
models ui.commands ui.gadgets ui.gadgets.panes
ui.gadgets.scrollers ui.gadgets.tracks ui.gestures
ui.gadgets.buttons compiler.units assocs words vocabs ;
IN: ui.tools.browser

TUPLE: browser-gadget pane history ;

: show-help ( link help -- )
    dup browser-gadget-history add-history
    >r >link r> browser-gadget-history set-model ;

: <help-pane> ( browser-gadget -- gadget )
    browser-gadget-history
    [ [ dup help ] try drop ] <pane-control> ;

: init-history ( browser-gadget -- )
    "handbook" >link <history>
    swap set-browser-gadget-history ;

: <browser-gadget> ( -- gadget )
    browser-gadget construct-empty
    dup init-history [
        toolbar,
        g <help-pane> g-> set-browser-gadget-pane
        <scroller> 1 track,
    ] { 0 1 } build-track ;

M: browser-gadget call-tool* show-help ;

M: browser-gadget tool-scroller
    browser-gadget-pane find-scroller ;

M: browser-gadget graft*
    dup add-definition-observer
    delegate graft* ;

M: browser-gadget ungraft*
    dup delegate ungraft*
    remove-definition-observer ;

: showing-definition? ( defspec assoc -- ? )
    [ key? ] 2keep
    [ >r dup word-link? [ link-name ] when r> key? ] 2keep
    >r dup vocab-link? [ vocab ] when r> key?
    or or ;

M: browser-gadget definitions-changed ( assoc browser -- )
    browser-gadget-history
    dup model-value rot showing-definition?
    [ notify-connections ] [ drop ] if ;

: help-action ( browser-gadget -- link )
    browser-gadget-history model-value >link ;

: com-follow browser-gadget call-tool ;

: com-back browser-gadget-history go-back ;

: com-forward browser-gadget-history go-forward ;

: com-documentation "handbook" swap show-help ;

: com-vocabularies "vocab-index" swap show-help ;

: browser-help "ui-browser" help-window ;

\ browser-help H{ { +nullary+ t } } define-command

browser-gadget "toolbar" f {
    { T{ key-down f { A+ } "b" } com-back }
    { T{ key-down f { A+ } "f" } com-forward }
    { T{ key-down f { A+ } "h" } com-documentation }
    { T{ key-down f { A+ } "v" } com-vocabularies }
    { T{ key-down f f "F1" } browser-help }
} define-command-map
