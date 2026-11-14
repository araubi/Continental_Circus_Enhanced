set throttle off
set renderer none
set mute on
set ::f [open $::env(OUT)/frames.bin wb]
set ::c 0; set ::tf 0
catch { debug probe set_bp VDP.tooFastVramAccess {} { incr ::tf } } ::perr
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
debug set_bp $::env(TAIL) {[reg a]==160} { incr ::c
  puts -nonewline $::f [binary format ccc [debug read memory $::env(N1)] [debug read memory $::env(N12)] [debug read memory $::env(SKIP)]]
  puts -nonewline $::f [debug read_block memory 0xE200 0x1600]
  puts -nonewline $::f [debug read_block VRAM 0x0400 0x1400] }
after time 30 {keymatrixdown 8 0x20}
# volantazos, cambio de marcha y freno para variar el horizonte y la carretera
foreach {t k} {33 0x10 37 0x80 41 0x10 46 0x80 52 0x10 58 0x80 64 0x10 70 0x80 76 0x10 82 0x80} {
  after time $t "keymatrixdown 8 $k"; after time [expr {$t+1.5}] "keymatrixup 8 $k" }
after time 36 {keymatrixdown 8 0x01}
after time 36.3 {keymatrixup 8 0x01}
after time 60 {keymatrixup 8 0x20; keymatrixdown 8 0x40}
after time 63 {keymatrixup 8 0x40; keymatrixdown 8 0x20}
after time 90 { close $::f; puts stderr "frames=$::c tooFast=$::tf probe=$::perr"; exit }
