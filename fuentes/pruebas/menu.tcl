set throttle off
set renderer none
set mute on
set ::go 0
proc dump {n} { set f [open $::env(OUT)/$n.bin wb]; puts -nonewline $f [debug read_block VRAM 0 0x4000]; close $f }
proc key {t r m} { after time $t "keymatrixdown $r $m"; after time [expr {$t+0.2}] "keymatrixup $r $m" }
debug set_bp 0xA812 {$::go == 0} { set ::go 1
  after time 0.5 { dump menu0; puts stderr "sel=[debug read memory 0x3859] istr=[debug read memory 0x3858]" }
  key 0.7 0 0x10
  after time 1.3 { dump menu1; puts stderr "sel=[debug read memory 0x3859]" }
  key 1.5 0 0x10
  after time 2.1 { dump menu2; puts stderr "sel=[debug read memory 0x3859]" }
  key 2.3 0 0x10
  after time 2.9 { puts stderr "sel=[debug read memory 0x3859]"; exit } }
after time 200 { puts stderr "sin menu"; exit }
