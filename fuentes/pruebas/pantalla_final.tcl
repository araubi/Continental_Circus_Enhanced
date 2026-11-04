set save_settings_on_exit off
after time 10 { reg a 8; reg hl 0; reg pc 0xFB03 }
after time 13 { screenshot -raw /tmp/claude-0/-home-user/1ef34445-456f-5583-92e7-38641fde800e/scratchpad/fin/emu_final.png }
after time 13.5 { keymatrixdown 8 1 }
after time 14 { keymatrixup 8 1 }
after time 16 { screenshot -raw /tmp/claude-0/-home-user/1ef34445-456f-5583-92e7-38641fde800e/scratchpad/fin/emu_after.png; exit }
