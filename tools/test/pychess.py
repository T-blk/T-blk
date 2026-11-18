# Bộ luật cờ vua độc lập (bàn 8x8 dạng danh sách) để chấm máy awk. pos = (board[64], turn, castle 'KQkq' subset, ep_sq or None)
def start(): return (list("rnbqkbnrpppppppp"+"."*32+"PPPPPPPPRNBQKBNR"),'w','KQkq',None)
def rc(i): return divmod(i,8)
def on(r,c): return 0<=r<8 and 0<=c<8
def color(p): return None if p=='.' else ('w' if p.isupper() else 'b')
def attacked(b,sq,by):
    r,c=rc(sq)
    for dr,dc in ((-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)):
        if on(r+dr,c+dc) and b[(r+dr)*8+c+dc]==('N' if by=='w' else 'n'): return True
    for dr in (-1,0,1):
        for dc in (-1,0,1):
            if (dr or dc) and on(r+dr,c+dc) and b[(r+dr)*8+c+dc]==('K' if by=='w' else 'k'): return True
    pr = r+1 if by=='w' else r-1
    for dc in (-1,1):
        if on(pr,c+dc) and b[pr*8+c+dc]==('P' if by=='w' else 'p'): return True
    for dr,dc in ((-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)):
        rr,cc=r+dr,c+dc
        while on(rr,cc):
            p=b[rr*8+cc]
            if p!='.':
                if color(p)==by and (p.upper()=='Q' or (p.upper()=='R' and (dr==0 or dc==0)) or (p.upper()=='B' and dr and dc)): return True
                break
            rr+=dr; cc+=dc
    return False
def apply(pos,m):
    b,turn,ca,ep=pos; b=b[:]; f,t,pr=m; p=b[f]; r1,c1=rc(f); r2,c2=rc(t)
    nep=None
    if p.upper()=='P':
        if t==ep: b[r1*8+c2]='.'
        if abs(r2-r1)==2: nep=(r1+r2)//2*8+c1
    b[t]=p; b[f]='.'
    if pr: b[t]=pr if turn=='w' else pr.lower()
    if p.upper()=='K' and abs(c2-c1)==2:
        if c2==6: b[r1*8+5]=b[r1*8+7]; b[r1*8+7]='.'
        else: b[r1*8+3]=b[r1*8+0]; b[r1*8+0]='.'
    for sq,fl in ((60,'KQ'),(63,'K'),(56,'Q'),(4,'kq'),(7,'k'),(0,'q')):
        if f==sq or t==sq:
            for x in fl: ca=ca.replace(x,'')
    return (b,'b' if turn=='w' else 'w',ca,nep)
def pseudo(pos):
    b,turn,ca,ep=pos; out=[]
    for i,p in enumerate(b):
        if color(p)!=turn: continue
        r,c=rc(i); P=p.upper()
        if P=='P':
            d=-1 if turn=='w' else 1; startr=6 if turn=='w' else 1; last=0 if turn=='w' else 7
            def add(t):
                if rc(t)[0]==last: out.extend((i,t,x) for x in 'QRBN')
                else: out.append((i,t,None))
            if on(r+d,c) and b[(r+d)*8+c]=='.':
                add((r+d)*8+c)
                if r==startr and b[(r+2*d)*8+c]=='.': out.append((i,(r+2*d)*8+c,None))
            for dc in (-1,1):
                if on(r+d,c+dc):
                    t=(r+d)*8+c+dc
                    if (b[t]!='.' and color(b[t])!=turn) or t==ep: add(t)
        elif P in 'NK':
            ds=((-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)) if P=='N' else [(a,bb) for a in (-1,0,1) for bb in (-1,0,1) if a or bb]
            for dr,dc in ds:
                if on(r+dr,c+dc) and color(b[(r+dr)*8+c+dc])!=turn: out.append((i,(r+dr)*8+c+dc,None))
            if P=='K':
                opp='b' if turn=='w' else 'w'; row=7 if turn=='w' else 0
                if i==row*8+4 and not attacked(b,i,opp):
                    if ('K' if turn=='w' else 'k') in ca and b[row*8+5]=='.' and b[row*8+6]=='.' and b[row*8+7]==('R' if turn=='w' else 'r') and not attacked(b,row*8+5,opp) and not attacked(b,row*8+6,opp): out.append((i,row*8+6,None))
                    if ('Q' if turn=='w' else 'q') in ca and b[row*8+3]=='.' and b[row*8+2]=='.' and b[row*8+1]=='.' and b[row*8]==('R' if turn=='w' else 'r') and not attacked(b,row*8+3,opp) and not attacked(b,row*8+2,opp): out.append((i,row*8+2,None))
        else:
            ds=[]
            if P in 'RQ': ds+=[(-1,0),(1,0),(0,-1),(0,1)]
            if P in 'BQ': ds+=[(-1,-1),(-1,1),(1,-1),(1,1)]
            for dr,dc in ds:
                rr,cc=r+dr,c+dc
                while on(rr,cc):
                    q=b[rr*8+cc]
                    if q=='.': out.append((i,rr*8+cc,None))
                    else:
                        if color(q)!=turn: out.append((i,rr*8+cc,None))
                        break
                    rr+=dr; cc+=dc
    return out
def incheck(pos,side):
    b=pos[0]; k=b.index('K' if side=='w' else 'k'); return attacked(b,k,'b' if side=='w' else 'w')
def legal(pos):
    res=[]
    for m in pseudo(pos):
        np=apply(pos,m)
        if not incheck(np,pos[1]): res.append((m,np))
    return res
def perft(pos,d):
    if d==0: return 1
    ls=legal(pos)
    if d==1: return len(ls)
    return sum(perft(np,d-1) for _,np in ls)
def from_fen(fen):
    f=fen.split(); b=[]
    for ch in f[0].replace('/',''):
        b.extend('.'*int(ch) if ch.isdigit() else ch)
    ep=None if f[3]=='-' else (8-int(f[3][1]))*8+ord(f[3][0])-97
    return (b,f[1],''.join(x for x in 'KQkq' if x in f[2]),ep)
if __name__=='__main__':
    print('khai cuộc d3',perft(start(),3),'(8902)')
    print('Kiwipete d3',perft(from_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"),3),'(97862)')
    print('vị trí 3 d4',perft(from_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -"),4),'(43238)')
    print('vị trí 4 d3',perft(from_fen("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -"),3),'(9467)')
    print('vị trí 5 d3',perft(from_fen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -"),3),'(62379)')
