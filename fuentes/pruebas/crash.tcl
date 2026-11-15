set throttle off
set renderer none
set mute on
proc dump {n} { set f [open $::env(OUT)/vram_$n.bin wb]; puts -nonewline $f [debug read_block VRAM 0 16384]; close $f }
proc st {} { return "B4DE=[debug read memory 0xB4DE] mandos=[format %02X [debug read memory 0xB50E]] marcha=[debug read memory 0xB507] v=[expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]}] giro=[debug read memory 0xA3CF] B513=[format %02X [debug read memory 0xB513]] humo=[expr {[debug read memory 0xB519]>>7}]" }
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 30 {keymatrixdown 8 0x20}
after time 36 {keymatrixdown 8 0x01}
after time 36.3 {keymatrixup 8 0x01}
set ::log 0; set ::fr 0; set ::t0 0
after time 44 {
  puts stderr "antes: [st]"
  debug write memory 0xB513 $::env(HIT)
  if {$::env(HOLD)} { keymatrixdown 8 0x01 }
  set ::log 1; set ::t0 [machine_info time]
  debug set_bp $::env(TAIL) {[reg a]==160} { if {$::log} { incr ::fr
     if {$::env(VERB) || $::fr < 3} { puts stderr "  $::fr: [st]" }
     if {$::fr > 2 && [debug read memory 0xB50E] == 0x1F && [debug read memory 0xB513] == 0} { puts stderr "mandos de vuelta: imagen $::fr, [format %.1f [expr {[machine_info time]-$::t0}]] s: [st]"; set ::log 0; dump fin
        after time [expr {[machine_info time]+2}] { puts stderr "2 s después: [st]"; exit } } } }
}
after time 50 { if {$::log && $::env(HIT) eq "0x80"} { puts stderr "6 s tras el toque: [st]"; dump toque; exit } }
after time 70 { puts stderr "sin fin: [st]"; exit }
