set throttle off
set renderer none
set mute on
set ::go 0
proc dump {n} { set f [open $::env(OUT)/$n.bin wb]; puts -nonewline $f [debug read_block VRAM 0 0x4000]; close $f }
proc key {t r m {d 0.2}} { after time $t "keymatrixdown $r $m"; after time [expr {$t+$d}] "keymatrixup $r $m" }
proc v {} { expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]} }
proc tab {} { set s ""; for {set i 0x17F4} {$i<0x1800} {incr i} { append s [format %02X [debug read memory $i]] " " }; return "$s freno=[format %02X/%02X [debug read memory 0x38FA] [debug read memory 0x3900]]" }
debug set_bp 0xA812 {$::go == 0} { set ::go 1
  puts stderr "antes:   [tab]"
  key 0.5 0 0x04
  # O, P, H, Q, A (freno), M, ESC
  set t 1.2
  foreach {r m} {4 0x10 4 0x20 3 0x20 4 0x40 2 0x40 4 0x04 7 0x04} { key $t $r $m; set t [expr {$t+0.6}] }
  after time 3.4 { dump brake }
  after time 6 { dump fin; exit }
  key 6.5 7 0x80
  after time 14 { keymatrixdown 4 0x40 }
  after time 24 { puts stderr "acelerando con Q: v=[v]"; keymatrixdown 8 0x40 }
  after time 26 { puts stderr "tras 2 s de cursor abajo (ya no frena): v=[v]"; keymatrixup 8 0x40; keymatrixdown 2 0x40 }
  after time 28 { puts stderr "tras 2 s de A (freno nuevo): v=[v]"; exit } }
after time 200 { puts stderr "sin menu"; exit }
