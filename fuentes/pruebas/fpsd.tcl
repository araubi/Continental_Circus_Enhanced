set throttle off
set renderer none
set mute on
set ::c 0; set ::ta 0
proc tick {} { if {$::c == 0} { keymatrixdown 7 0x80; after time 0.2 {keymatrixup 7 0x80}; after time 1.0 tick } }
after time 6 tick
if {$::env(OLD)} { debug set_bp 0x1500 {} { if {[debug read memory $::env(V_PITNOW)]} { debug write memory $::env(V_FORCE) 6 } } }
debug set_bp $::env(TAIL) {[reg a]==160} { incr ::c
  if {$::c == 1} { keymatrixdown 8 0x20 }
  if {$::c == 30} { debug write memory 0xB513 0x80 }
  if {$::c == 60} { set ::ta [machine_info time] }
  if {$::c == 260} { set dt [expr {[machine_info time]-$::ta}]; puts stderr "[format %.2f [expr {200.0/$dt}]] img/s (humo=[expr {[debug read memory 0xB519]>>7}], v=[expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]}])"; exit } }
after time 150 { puts stderr "no llegó: c=$::c"; exit }
