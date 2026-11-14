set throttle off
set renderer none
set mute on
array set ::w {}
proc hit {zone} { set pc [reg pc]; if {$zone eq "cache" && (($pc >= 0x11A0 && $pc < 0x12B0) || ($pc >= 0x3785 && $pc < 0x3830))} return; set k "$zone pc=[format %04X $pc]"; if {![info exists ::w($k)]} { set ::w($k) 0 }; incr ::w($k) }
after time 3 {
  debug set_watchpoint write_mem {0x1C00 0x1FFF} {} {hit fastrow}
  debug set_watchpoint write_mem {0x3785 0x3BFF} {} {hit gear+fastb}
  debug set_watchpoint write_mem {0x1036 0x115F} {} {hit hooks}
  debug set_watchpoint write_mem {0x1900 0x197F} {} {hit cache}
  debug set_watchpoint write_mem {0x11A0 0x12FF} {} {hit glyph}
}
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 30 {keymatrixdown 8 0x20}
foreach {t k} {33 0x10 37 0x80 41 0x10 46 0x80 52 0x10 58 0x80 64 0x10 70 0x80 76 0x10 82 0x80} {
  after time $t "keymatrixdown 8 $k"; after time [expr {$t+1.5}] "keymatrixup 8 $k" }
after time 36 {keymatrixdown 8 0x01}
after time 36.3 {keymatrixup 8 0x01}
# tras el fin de carrera: tablas, menú y segunda partida
foreach t {135 137 150 152 160} { after time $t {keymatrixdown 7 0x80}; after time [expr {$t+0.3}] {keymatrixup 7 0x80} }
after time 200 { puts stderr "escrituras inesperadas: [array get ::w]"; exit }
