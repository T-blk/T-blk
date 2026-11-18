import subprocess, sys, random, pychess as pc
import os; A=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','kindle','dashboard','lib','chess.awk'); AWK=sys.argv[1]; games=int(sys.argv[2]); random.seed(int(sys.argv[3])); TL=sys.argv[4] if len(sys.argv)>4 else '1'
def eng(act, save, **kw):
    cmd=[AWK]+sum([['-v',f'{k}={v}'] for k,v in kw.items()],[])+['-v',f'ACT={act}','-v',f'SAVE={save}','-f',A]
    return subprocess.run(cmd,capture_output=True,text=True)
def state(save):
    d={}
    for l in open(save):
        k,_,v=l.rstrip('\n').partition(' ')
        if k!='H': d[k]=v
    return d
bad=0; res={}; total=0
for g in range(games):
    save=f'ref{g}.save'; open(save,'w').close()
    lw,lb=random.choice([(3,2),(2,3),(3,1),(1,2),(3,3),(1,1),(2,2)])
    eng('new',save,NMODE='ai',NLV=lw,NPC='b')
    pos=pc.start(); plies=0; err=''
    while True:
        st=state(save)
        if st['ST']!='play' or plies>=200: break
        turn=st['S'].split()[1]; lv=lw if turn=='w' else lb
        txt=open(save).read().replace(f"\nLV {st['LV']}\n",f"\nLV {lv}\n").replace(f"\nPC {st['PC']}\n",f"\nPC {'b' if turn=='w' else 'w'}\n")
        open(save,'w').write(txt)
        r=eng('ai',save,TLIM=TL)
        if r.stderr.strip(): err='awk báo lỗi: '+r.stderr.strip()[:200]; break
        s2=state(save)['S'].split()
        match=[np for m,np in pc.legal(pos) if ''.join(np[0])==s2[0]]
        if not match: err=f'nước thứ {plies+1} KHÔNG HỢP LỆ: {"".join(pos[0])} -> {s2[0]}'; break
        np=match[0]
        ca=''.join('1' if x in np[2] else '0' for x in 'KQkq')
        if ca!=s2[2]: err=f'nước {plies+1}: quyền nhập thành lệch awk={s2[2]} trọng tài={ca}'; break
        epm=-1 if np[3] is None else 21+(np[3]//8)*10+np[3]%8
        if int(s2[3])!=epm:
            # awk ghi ô "qua đường" sau mọi nước tốt đi 2 ô; trọng tài cũng vậy -> phải khớp
            err=f'nước {plies+1}: ô bắt tốt qua đường lệch awk={s2[3]} trọng tài={epm}'; break
        pos=np; plies+=1
    st=state(save)['ST']; ls=pc.legal(pos)
    exp='play'
    if not ls: exp='mate' if pc.incheck(pos,pos[1]) else 'stale'
    if not err and st in ('mate','stale') and st!=exp: err=f'kết thúc "{st}" nhưng trọng tài nói "{exp}"'
    if not err and st=='play' and exp!='play': err=f'ván phải kết thúc ({exp}) nhưng awk vẫn "play"'
    total+=plies
    if err: bad+=1; print(f'VÁN {g} (mức {lw}-{lb}) LỖI: {err}')
    res[st]=res.get(st,0)+1
print(f'{games} ván, {total} nước, LỖI: {bad}, kết thúc: {res}')
