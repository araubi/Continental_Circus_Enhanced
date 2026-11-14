set throttle off
set renderer none
set mute on
set ::n 0; set ::bad 0; set ::armed 0; set ::phase 0; set ::skips 0
proc dump {n} { set f [open $::env(OUT)/vram_$n.bin wb]; puts -nonewline $f [debug read_block VRAM 0 16384]; close $f }
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
set ::f [open $::env(OUT)/hud.bin wb]
debug set_bp 0x8998 {} { set ::armed 1 }
debug set_bp 0x899B {} { if {$::armed} { set ::armed 0; incr ::n
  puts -nonewline $::f [binary format c [expr {0x30 + ([debug read memory 0xAF36] & 15)}]]
  puts -nonewline $::f [debug read_block memory 0xAF44 28]
  puts -nonewline $::f [debug read_block VRAM 0 0x300] } }
after time 30 {keymatrixdown 8 0x20}
foreach {t k} {33 0x10 37 0x80 41 0x10 46 0x80 52 0x10 58 0x80 64 0x10 70 0x80 76 0x10 82 0x80} {
  after time $t "keymatrixdown 8 $k"; after time [expr {$t+1.5}] "keymatrixup 8 $k" }
after time 36 {keymatrixdown 8 0x01}
after time 36.3 {keymatrixup 8 0x01}
after time 60 {keymatrixup 8 0x20; keymatrixdown 8 0x40}
after time 63 {keymatrixup 8 0x40; keymatrixdown 8 0x20}
after time 100 { dump t100 }
after time 115 { dump t115 }
after time 130 { close $::f; puts stderr "marcadores=$::n"; dump t130; exit }
