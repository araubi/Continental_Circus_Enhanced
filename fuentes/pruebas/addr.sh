# uso: . addr.sh  -> exporta las direcciones del volcado (cambian con cada edición de blit3.asm)
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sym(){ grep -E "^$1: EQU" $R/prototipo3/blit3.sym | head -1 | sed 's/.*0x0000/0x/'; }
export TAIL=$(sym blit_tail) N1=$(sym n1) N12=$(sym n12) SKIP=$(sym pitvram) V_FORCE=$(sym force) V_PITNOW=$(sym pitnow)
