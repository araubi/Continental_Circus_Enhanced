set save_settings_on_exit off
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
set ::ev [open /tmp/claude-0/-home-user/1ef34445-456f-5583-92e7-38641fde800e/scratchpad/fin/tj.txt w]
set ::tag none
set ::joy 0xFF
debug set_bp 0x0561 {} { reg a $::joy }
debug set_bp 0x8CA0 {} { puts $::ev "[format %.2f [machine_info time]] $::tag a=[format %02X [reg a]] v=[expr {[debug read memory 0xB504]+256*[debug read memory 0xB505]}] g=[debug read memory 0xB507]"; flush $::ev }
after time 30 {set ::tag nada}
after time 32 {set ::tag espacio; keymatrixdown 8 1}
after time 34 {keymatrixup 8 1; set ::tag arriba; keymatrixdown 8 0x20}
after time 36 {keymatrixup 8 0x20; set ::tag joy_nada; debug write memory 0xAF3E 1}
after time 38 {set ::tag joy_fuego; set ::joy 0xEF}
after time 40 {set ::tag joy_arriba; set ::joy 0xFE}
after time 42 {set ::tag joy_abajo; set ::joy 0xFD}
after time 42.5 {set ::tag joy_fuego2; set ::joy 0xEF}
after time 46 {set ::tag joy_fuego_abajo; set ::joy 0xED}
after time 48 {close $::ev; exit}
