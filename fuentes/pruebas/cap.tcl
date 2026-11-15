set throttle off
set renderer none
set mute on
set ::f [open $::env(OUT) wb]
set ::c 0; set ::ei 0
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
debug set_bp 0x9571 {} { incr ::c
  if {[reg iff]} { incr ::ei }
  puts -nonewline $::f [debug read_block memory 0 0x10000] }
after time 30 {keymatrixdown 8 0x20}
foreach {t k} {33 0x10 37 0x80 41 0x10 46 0x80 52 0x10 58 0x80 64 0x10 70 0x80 76 0x10 82 0x80 95 0x10 101 0x80 108 0x10 115 0x80} {
  after time $t "keymatrixdown 8 $k"; after time [expr {$t+1.5}] "keymatrixup 8 $k" }
after time 36 {keymatrixdown 8 0x01}
after time 36.3 {keymatrixup 8 0x01}
after time 60 {keymatrixup 8 0x20; keymatrixdown 8 0x40}
after time 63 {keymatrixup 8 0x40; keymatrixdown 8 0x20}
after time 125 { close $::f; puts stderr "frames=$::c con_EI=$::ei"; exit }
