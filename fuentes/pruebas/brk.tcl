set throttle off
set renderer none
set mute on
set ::c 0
proc v {} { expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]} }
proc tick {} { if {$::c == 0} { keymatrixdown 7 0x80; after time 0.2 {keymatrixup 7 0x80}; after time 1.0 tick } }
after time 6 tick
debug set_bp 0x8919 {} { incr ::c
  if {$::c == 1} { keymatrixdown 8 0x20 }
  if {$::c == 80} { puts stderr "acelerando: v=[v]"; keymatrixdown 8 0x40 }
  if {$::c > 80 && $::c < 95} { puts -nonewline stderr "[v] " }
  if {$::c == 95} { puts stderr "tras 15 imagenes de cursor abajo: v=[v]"; exit } }
