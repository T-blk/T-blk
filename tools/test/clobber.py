# Tìm lỗi "trùng tên biến": shell không có biến cục bộ, nên hàm A đặt biến V, gọi hàm B (B hoặc hàm B gọi tiếp cũng ghi V),
# rồi A đọc lại V -> sai. In ra các chỗ nghi ngờ trong những hàm được chỉ định.
import re, sys, glob
files=['dash.sh']+sorted(glob.glob('lib/*.sh'))
src={f:re.sub(r'(^|[ \t;])#[^\n]*', r'\1', open(f).read()) for f in files}
FN={}   # tên -> (file, thân)
for f,s in src.items():
    for m in re.finditer(r'^([a-zA-Z_][a-zA-Z_0-9]*)\(\) *\{', s, re.M):
        i=m.end(); le=s.find('\n',i)
        if s[i:le].rstrip().endswith('}'): body=s[i:le]
        else:
            k=s.find('\n}',i); body=s[i:k if k>0 else len(s)]
        FN[m.group(1)]=(f,body)
SKIP={'if','of','bs','skip','seek','count','conv','top','left','width','height','px','right','bottom','regular','steps','direction','size'}
def assigns(body):
    out=[]
    for m in re.finditer(r'(?<![A-Za-z0-9_${"\'=/.,:-])([A-Za-z_][A-Za-z0-9_]*)=', body):
        if m.group(1) not in SKIP: out.append((m.start(),m.group(1)))
    for m in re.finditer(r'\bfor ([A-Za-z_][A-Za-z0-9_]*) in', body): out.append((m.start(),m.group(1)))
    for m in re.finditer(r'\bread -r ((?:[A-Za-z_][A-Za-z0-9_]* ?)+)', body):
        for v in m.group(1).split(): out.append((m.start(),v))
    return out
def calls(body):
    out=[]
    for m in re.finditer(r'(?<![A-Za-z0-9_$.=/-])([A-Za-z_][A-Za-z0-9_]*)(?=[ ;\n)]|$)', body):
        if m.group(1) in FN:
            # phải ở vị trí lệnh: đầu dòng / sau ; && || { ( | do then else $(
            pre=body[:m.start()].rstrip(' ')
            if pre=='' or pre[-1] in ';&|{()\n' or pre.endswith(('do','then','else','$(','!')): out.append((m.start(),m.group(1)))
    return out
OWN={n:set(v for _,v in assigns(b)) for n,(f,b) in FN.items()}
CALL={n:set(c for _,c in calls(b)) for n,(f,b) in FN.items()}
CLOB={n:set(OWN[n]) for n in FN}
ch=True
while ch:
    ch=False
    for n in FN:
        for c in CALL[n]:
            if c!=n and not CLOB[c]<=CLOB[n]: CLOB[n]|=CLOB[c]; ch=True
targets=sys.argv[1:]
rep=[]
for n in targets:
    if n not in FN: print('?? không thấy hàm',n); continue
    f,body=FN[n]; A=assigns(body); C=calls(body)
    for v in sorted(set(x for _,x in A)):
        apos=[p for p,x in A if x==v]
        reads=[m.start() for m in re.finditer(r'(?<![A-Za-z0-9_])\$?\{?'+re.escape(v)+r'(?![A-Za-z0-9_=])', body) ]
        reads=[p for p in reads if not any(abs(p-a)<=1 for a in apos)]
        for rp in reads:
            last=max([a for a in apos if a<rp], default=None)
            if last is None: continue
            bad=[c for p,c in C if last<p<rp and v in CLOB[c] and c!=n]
            if bad:
                ln=body.count('\n',0,rp); line=body.split('\n')[ln].strip()[:110]
                rep.append((f,n,v,sorted(set(bad))[:4],line))
seen=set()
for f,n,v,bad,line in rep:
    key=(n,v)
    if key in seen: continue
    seen.add(key); print(f"{f}: {n}(): biến {v} có thể bị ghi đè bởi {', '.join(bad)}\n      … {line}")
print(f"\n{len(seen)} chỗ nghi ngờ trong {len(targets)} hàm")
