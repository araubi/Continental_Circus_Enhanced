import re,sys,ast
K=int(sys.argv[1]); x=open('cc.xml').read()
t0,vdp,regs,iff=ast.literal_eval(open('st%d.txt'%K).read())
F=3436363200
ev=x[x.index('<events>'):]
L=[]
for m in re.finditer(r'type="KeyMatrixState">\s*<StateChange>\s*<time>\s*<time>(\d+)</time>\s*</time>\s*</StateChange>\s*<row>(\d+)</row>\s*<press>(\d+)</press>\s*<release>(\d+)</release>',ev):
    t,r,p,rl=map(int,m.groups())
    if t>=t0: L.append(((t-t0)/F,r,p,rl))
D='/tmp/claude-0/-home-user/1ef34445-456f-5583-92e7-38641fde800e/scratchpad/omr'
o=['set save_settings_on_exit off','set ::D %s'%D,'proc rest {} {',
 '  set f [open $::D/ram%d.bin r]; fconfigure $f -translation binary; set d [read $f]; close $f'%K,
 '  debug write_block "Main RAM" 0 $d',
 '  set f [open $::D/vram%d.bin r]; fconfigure $f -translation binary; set d [read $f]; close $f'%K,
 '  debug write_block VRAM 0 $d']
for i,v in enumerate(vdp): o.append('  debug write "VDP regs" %d %d'%(i,v))
o.append('  debug write ioports 0xA8 0xFF')
for k,v in regs.items(): o.append('  reg %s %s'%(k,v))
o.append('  reg iff %d'%(1 if iff=='true' else 0))
for t,r,p,rl in L:
    if p: o.append('  after time %.6f {keymatrixdown %d %d}'%(t,r,p))
    if rl: o.append('  after time %.6f {keymatrixup %d %d}'%(t,r,rl))
o.append('  set ::T0 [machine_info time]')
o.append('}')
open('rest%d.tcl'%K,'w').write('\n'.join(o)+'\n')
print(len(L),'eventos; primero',L[:2])
