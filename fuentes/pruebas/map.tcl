set throttle off
set renderer none
set mute on
proc dump {n} { set f [open $::env(OUT)/vram_$n.bin wb]; puts -nonewline $f [debug read_block VRAM 0 16384]; close $f }
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 30 {keymatrixdown 8 0x20}
set ::t0 0
debug set_bp 0xA770 {} { set ::t0 [machine_info time]; set ::steps [reg b]; keymatrixup 8 0x20 }
debug set_bp 0x86DA {} { if {$::t0 > 0} { puts stderr "recorrido pintado: $::steps pasos en [format %.2f [expr {[machine_info time]-$::t0}]] s (t=[format %.0f [machine_info time]])"; dump $::env(NAME); exit } }
after time 200 { puts stderr "no llegó"; exit }
