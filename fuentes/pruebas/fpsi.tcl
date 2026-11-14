set throttle off
set renderer none
set mute on
set ::c 0; set ::ta 0; set ::i 0; set ::ia 0
debug set_bp 0x38 {} { incr ::i }
proc tick {} { if {$::c == 0} { keymatrixdown 7 0x80; after time 0.2 {keymatrixup 7 0x80}; after time 1.0 tick } }
after time 6 tick
debug set_bp $::env(TAIL) {[reg a]==160} { incr ::c
  if {$::c == 1} { keymatrixdown 8 0x20 }
  if {$::c == 40} { set ::ta [machine_info time]; set ::ia $::i }
  if {$::c == 140} { set dt [expr {[machine_info time]-$::ta}]; puts stderr "int/s=[format %.1f [expr {($::i-$::ia)/$dt}]] [format %.2f [expr {100.0/$dt}]] img/s (v=[expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]}] km/h, marcha=[debug read memory 0xB507], t=[format %.0f [machine_info time]] s)"; exit } }
after time 150 { puts stderr "int/s=[format %.1f [expr {($::i-$::ia)/$dt}]] no llegó: c=$::c"; exit }
