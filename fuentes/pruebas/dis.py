"""Desensambla rangos de la imagen de RAM de una ROM: python3 dis.py ROM 9571-9710 [más rangos]"""
import sys
import os
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','herramientas','desensamblado'))
from z80dis import Dis
rom=open(sys.argv[1],'rb').read(); ram=rom[0x2000:0x12000]
d=Dis(ram,0)
for rng in sys.argv[2:]:
    a,b=[int(x,16) for x in rng.split('-')]
    pc=a
    while pc<b:
        r=d.dec(pc)
        print('%04X  %-12s %s'%(pc, ram[pc:pc+r[1]].hex(), r[0]))
        pc+=r[1]
    print()
