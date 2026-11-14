set throttle off
set renderer none
set mute on
set ::tot 0; set ::race 0; set ::last 0; set ::rf 0
proc tick {} { if {$::race == 0} { keymatrixdown 7 0x80; after time 0.2 {keymatrixup 7 0x80}; after time 1.0 tick } }
after time 6 tick
proc T {} { format %.2f [machine_info time] }
# llamador de RST 18h: dirección de retorno en la pila
debug set_bp 0x0C89 {} { incr ::tot; set sp [reg sp]; set r [expr {[debug read memory $sp]+256*[debug read memory [expr {$sp+1}]]}]
  set t [machine_info time]
  if {![info exists ::n($r)]} { set ::n($r) 0; set ::t0($r) $t }
  incr ::n($r); set ::t1($r) $t }
debug set_bp 0x87D7 {} { puts stderr "[T] semaforo (87D7)" }
debug set_bp 0xA812 {} { puts stderr "[T] menu (A812)" }
debug set_bp 0x8919 {} { incr ::rf; if {$::race == 0} { set ::race 1; puts stderr "[T] primera imagen de carrera" } }
after time $::env(TMAX) { puts stderr "[T] fin; imagenes de carrera $::rf"
  foreach r [lsort [array names ::n]] { puts stderr [format "  RST18 desde %04X: %5d veces, de %.1f a %.1f s, %.1f ms entre llamadas" [expr {$r-1}] $::n($r) $::t0($r) $::t1($r) [expr {$::n($r)>1 ? 1000.0*($::t1($r)-$::t0($r))/($::n($r)-1) : 0}]] }
  exit }
