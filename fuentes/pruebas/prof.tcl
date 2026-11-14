set throttle off
set renderer none
set mute on
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 30 {keymatrixdown 8 0x20}
after time 33 {keymatrixdown 8 0x01}
after time 33.3 {keymatrixup 8 0x01}
# puntos del bucle de carrera (827A) y del fotograma (8919): nombre del tramo que EMPIEZA en cada dirección
set ::pts {
 0x827A "AE33 pausa" 0x828A "8C99 mandos+fisica" 0x828D "9181" 0x8290 "lluvia/82C6" 0x82C6 "8459" 0x82C9 "prep 82C9-8323"
 0x891A "91A0" 0x891D "92E6" 0x8920 "91EA" 0x8923 "9277" 0x8926 "93BD" 0x8929 "9571 carretera" 0x892C "exx" 0x8933 "8AB9"
 0x8936 "A0D2 objetos+rivales" 0x8939 "9D93 coche propio" 0x893C "pre-volcado" 0x8941 "8B3F volcado" 0x8944 "reloj" 0x8951 "8C23"
 0x8954 "9F68?" 0x895B "97D2" 0x895E "tiempo" 0x8998 "AE84 marcador" 0x899B "cola 899B" 0x8326 "8F2B choques" 0x8329 "fin bucle" }
array set ::acc {}; set ::last ""; set ::lt 0; set ::fr 0; set ::on 0
proc pt {name} { set t [machine_info time]; if {$::on && $::last ne ""} { if {![info exists ::acc($::last)]} {set ::acc($::last) 0}; set ::acc($::last) [expr {$::acc($::last)+($t-$::lt)}] }; set ::last $name; set ::lt $t; if {$name eq "AE33 pausa"} { incr ::fr } }
after time 38 { foreach {a n} $::pts { debug set_bp $a {} [list pt $n] }; set ::on 1; set ::fr 0; set ::ta [machine_info time] }
after time 58 { set tot [expr {[machine_info time]-$::ta}]; set n $::fr
  puts stderr "imagenes=$n ciclos/imagen=[format %.0f [expr {$tot*3579545/$n}]]"
  set l {}; foreach k [array names ::acc] { lappend l [list [expr {$::acc($k)*3579545/$n}] $k] }
  foreach e [lsort -real -decreasing -index 0 $l] { puts stderr [format "%8.0f  %5.1f%%  %s" [lindex $e 0] [expr {100.0*[lindex $e 0]*$n/($tot*3579545)}] [lindex $e 1]] }
  exit }
