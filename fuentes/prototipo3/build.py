# Ensambla el prototipo 3 y genera los parches con las direcciones reales de los símbolos.
import subprocess, os, re, sys
SJ=os.environ.get('SJASMPLUS','sjasmplus')
D=os.path.dirname(os.path.abspath(__file__)); os.chdir(D)
def asm(f):
    r=subprocess.run([SJ,'--nologo','--sym='+f+'.sym',f+'.asm'],capture_output=True,text=True)
    if 'Errors: 0' not in r.stdout+r.stderr: sys.exit(r.stdout+r.stderr)
    return {m.group(1):int(m.group(2),16) for m in re.finditer(r'^(\w+): EQU 0x([0-9A-F]+)',open(f+'.sym').read(),re.M)}
b=asm('blit3')
open('vars.inc','w').write('FORCE EQU %05Xh\nHUDINV EQU %05Xh\n'%(b['force'],b['hudinv']))
# direcciones del volcado que usa ../rom/ccrom.asm
open('../rom/p3sym.inc','w').write('; generado por prototipo3/build.py\n'+''.join('%s equ %05Xh\n'%(n,b[k]) for n,k in
    [('BLITROW','blit_row'),('BLITTAIL','blit_tail'),('HOOK743','hook743'),('HOOKA69','hookA69'),('HUDINV','hudinv'),('GEARINV','gearinv')]))
r=asm('rst10'); g=asm('glyph')
w=lambda n,d: open(n,'wb').write(bytes(d))
lo=lambda a:a&255; hi=lambda a:a>>8
w('jp1033.bin',[0xC3,lo(b['blit']),hi(b['blit'])])
w('h0743.bin',[0xC3,lo(b['hook743']),hi(b['hook743']),0])
w('h0A69.bin',[0xCD,lo(b['hookA69']),hi(b['hookA69'])])
w('h0593.bin',[0xE5,0xC3,lo(b['hookint']),hi(b['hookint']),0,0])
w('h0520.bin',[0xC3,lo(b['hook520']),hi(b['hook520'])])
w('h16EE.bin',[0xCD,lo(b['hookpit']),hi(b['hookpit'])])
w('jpA9F7.bin',[0xC3,lo(g['chr1']),hi(g['chr1'])])
w('jpAA1C.bin',[0xC3,lo(g['chr2']),hi(g['chr2'])])
print('blit3 %04X-%04X force %04X'%(b['blit'],b['blit_end'],b['force']))
