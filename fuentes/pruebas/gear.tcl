set throttle off
set renderer none
set mute on
proc dump {n} { set f [open $::env(OUT)/vram_$n.bin wb]; puts -nonewline $f [debug read_block VRAM 0 16384]; close $f; puts stderr "$n: t=[format %.1f [machine_info time]] B507=[debug read memory 0xB507] v=[expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]}]" }
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 20 {dump semaforo}
after time 30 {keymatrixdown 8 0x20}
after time 36 {dump low}
after time 36.5 {keymatrixdown 8 0x01}
after time 36.9 {keymatrixup 8 0x01}
after time 40 {dump high}
after time 40.5 {keymatrixdown 8 0x01}
after time 40.9 {keymatrixup 8 0x01}
after time 43 {dump low2; exit}
