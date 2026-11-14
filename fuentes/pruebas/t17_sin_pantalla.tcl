# t17.tcl sin ventana: SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy openmsx -machine C-BIOS_MSX1 -cart ROM -script t17_sin_pantalla.tcl
set throttle off
set renderer none
set mute on
source [file join [file dirname [info script]] t17.tcl]
