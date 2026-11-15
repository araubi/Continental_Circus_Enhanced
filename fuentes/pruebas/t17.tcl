set save_settings_on_exit off
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 30 {keymatrixdown 8 0x20}
set ::c 0
# 0x16AC = BLITTAIL (fin del volcado; ver fuentes/rom/p3sym.inc). En la v1.0 era 0x166D.
after time 40 { debug set_bp 0x16AC {[expr {[reg a]==160}]} {incr ::c} }
after time 60 { puts stderr "imagenes en 20 s: $::c"; exit }
