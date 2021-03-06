! Copyright (C) 2006, 2007 Alex Chapman
! See http://factorcode.org/license.txt for BSD license.
USING: alarms arrays calendar kernel ui.gadgets ui.gadgets.labels
ui.gadgets.worlds ui.gadgets.status-bar ui.gestures ui.render ui
tetris.game tetris.gl sequences system math math.parser namespaces ;
IN: tetris

TUPLE: tetris-gadget tetris alarm ;

: <tetris-gadget> ( tetris -- gadget )
    tetris-gadget construct-gadget
    [ set-tetris-gadget-tetris ] keep ;

M: tetris-gadget pref-dim* drop { 200 400 } ;

: update-status ( gadget -- )
    dup tetris-gadget-tetris [
        "Level: " % dup tetris-level #
        " Score: " % tetris-score #
    ] "" make swap show-status ;

M: tetris-gadget draw-gadget* ( gadget -- )
    [
        dup rect-dim dup first swap second rot tetris-gadget-tetris draw-tetris
    ] keep update-status ;

: new-tetris ( gadget -- )
    dup tetris-gadget-tetris <new-tetris> swap set-tetris-gadget-tetris ;

tetris-gadget H{
    { T{ key-down f f "UP" }     [ tetris-gadget-tetris rotate-right ] }
    { T{ key-down f f "d" }      [ tetris-gadget-tetris rotate-left ] }
    { T{ key-down f f "f" }      [ tetris-gadget-tetris rotate-right ] }
    { T{ key-down f f "e" }      [ tetris-gadget-tetris rotate-left ] } ! dvorak d
    { T{ key-down f f "u" }      [ tetris-gadget-tetris rotate-right ] } ! dvorak f
    { T{ key-down f f "LEFT" }   [ tetris-gadget-tetris move-left ] }
    { T{ key-down f f "RIGHT" }  [ tetris-gadget-tetris move-right ] }
    { T{ key-down f f "DOWN" }   [ tetris-gadget-tetris move-down ] }
    { T{ key-down f f " " }      [ tetris-gadget-tetris move-drop ] }
    { T{ key-down f f "p" }      [ tetris-gadget-tetris toggle-pause ] }
    { T{ key-down f f "n" }      [ new-tetris ] }
} set-gestures

: tick ( gadget -- )
    dup tetris-gadget-tetris maybe-update relayout-1 ;

M: tetris-gadget graft* ( gadget -- )
    dup [ tick ] curry 100 milliseconds from-now 100 milliseconds add-alarm
    swap set-tetris-gadget-alarm ;

M: tetris-gadget ungraft* ( gadget -- )
    [ tetris-gadget-alarm cancel-alarm f ] keep set-tetris-gadget-alarm ;

: tetris-window ( -- ) 
    [
        <default-tetris> <tetris-gadget>
        "Tetris" open-status-window
    ] with-ui ;

MAIN: tetris-window
