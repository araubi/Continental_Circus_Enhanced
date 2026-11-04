set save_settings_on_exit off
set ::D /tmp/claude-0/-home-user/1ef34445-456f-5583-92e7-38641fde800e/scratchpad/cc/rom
after time 6 {keymatrixdown 7 0x80}
after time 6.2 {keymatrixup 7 0x80}
after time 7.2 {keymatrixdown 7 0x80}
after time 7.4 {keymatrixup 7 0x80}
after time 12 {keymatrixdown 8 0x01}
after time 12.3 {keymatrixup 8 0x01}
after time 30 {keymatrixdown 8 0x20}
set ::ev [open $::D/ev26.txt w]
debug set_bp 0x8D3B {} { puts $::ev "[format %.2f [machine_info time]] v [expr {[reg hl]}] fr [debug read memory 0xB501] p [format %x [expr {[debug read memory 0x2142]+256*[debug read memory [expr {0x2142+1}]]}]]"; flush $::ev }
after time 40 {record start -audioonly $::D/brake26.wav}
after time 44 {keymatrixup 8 0x20; keymatrixdown 8 0x40}
after time 48 {keymatrixup 8 0x40; keymatrixdown 8 0x20}
after time 54 {keymatrixup 8 0x20; keymatrixdown 8 0x40}
after time 56 {keymatrixup 8 0x40}
after time 60 {record stop; close $::ev; exit}
