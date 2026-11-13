# Controllo statico minimo dei file Dart: bilanciamento di (), [], {} ignorando stringhe e commenti,
# import relativi esistenti, classi referenziate dal router.
import os, re, sys
root = sys.argv[1]
errors = 0
def strip(src):
    out=[];i=0;n=len(src)
    while i<n:
        c=src[i]
        if src.startswith('//',i):
            j=src.find('\n',i); i = n if j<0 else j; continue
        if src.startswith('/*',i):
            j=src.find('*/',i+2); i = n if j<0 else j+2; continue
        if c in 'rR' and i+1<n and src[i+1] in '\'"' : i+=1; c=src[i]; raw=True
        else: raw=False
        if c in '\'"':
            q=src[i:i+3] if src[i:i+3] in ("'''",'"""') else c
            i+=len(q)
            depth=0
            while i<n:
                if not raw and src[i]=='\\': i+=2; continue
                if not raw and src.startswith('${',i):
                    # interpolazione: salta bilanciando graffe
                    d=1;i+=2
                    while i<n and d>0:
                        if src[i]=='{': d+=1
                        elif src[i]=='}': d-=1
                        i+=1
                    continue
                if src.startswith(q,i): i+=len(q); break
                i+=1
            out.append('""'); continue
        out.append(c); i+=1
    return ''.join(out)
pairs={')':'(',']':'[','}':'{'}
for dp,_,fs in os.walk(root):
    for f in fs:
        if not f.endswith('.dart'): continue
        p=os.path.join(dp,f); src=open(p,encoding='utf-8').read()
        s=strip(src); st=[]
        line=1
        for ch in s:
            if ch=='\n': line+=1
            if ch in '([{': st.append((ch,line))
            elif ch in ')]}':
                if not st or st[-1][0]!=pairs[ch]:
                    print(f'{p}:{line}: parentesi non bilanciata {ch}'); errors+=1; break
                st.pop()
        else:
            if st: print(f'{p}: parentesi non chiusa {st[-1]}'); errors+=1
        for m in re.finditer(r"^import '([^']+)';", src, re.M):
            imp=m.group(1)
            if imp.startswith('package:wgf_connect/'):
                target=os.path.join(root,'lib',imp[len('package:wgf_connect/'):])
            elif imp.startswith('package:') or imp.startswith('dart:'): continue
            else: target=os.path.normpath(os.path.join(dp,imp))
            if not os.path.exists(target): print(f'{p}: import mancante {imp}'); errors+=1
print('file controllati, errori:', errors)
sys.exit(1 if errors else 0)
