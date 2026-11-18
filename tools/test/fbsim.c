/* Màn hình e-ink giả cho việc thử: 2 lớp "fb" (bộ nhớ, thứ đã vẽ) và "screen" (thứ người dùng thấy).
   Đóng vai fbink và eips (theo tên gọi). Thư mục trạng thái: $FBSIM_DIR. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgen.h>
#define S 768
static int W=758,H=1024; static unsigned char *fb,*sc; static char dir[512];
static void loadf(const char*n,unsigned char*b){char p[600];snprintf(p,600,"%s/%s",dir,n);FILE*f=fopen(p,"rb");if(f){size_t r=fread(b,1,S*H,f);(void)r;fclose(f);}else memset(b,255,S*H);}
static void savef(const char*n,unsigned char*b){char p[600];snprintf(p,600,"%s/%s",dir,n);FILE*f=fopen(p,"wb");if(f){fwrite(b,1,S*H,f);fclose(f);}}
static void logl(const char*s){char p[600];snprintf(p,600,"%s/log",dir);FILE*f=fopen(p,"a");if(f){fputs(s,f);fputc('\n',f);fclose(f);}}
static int col(const char*n){if(!strcmp(n,"BLACK"))return 0;if(!strcmp(n,"WHITE"))return 255;if(!strncmp(n,"GRAY",4)){char c=n[4];int v=(c>='0'&&c<='9')?c-'0':(c-'A'+10);return v*17;}return 0;}
static int kv(const char*s,const char*k,int def){char key[32];snprintf(key,32,"%s=",k);const char*p=s;while((p=strstr(p,key))){if(p==s||p[-1]==','){return atoi(p+strlen(key));}p++;}return def;}
static void clip(int*x,int*y,int*w,int*h){if(*x<0){*w+=*x;*x=0;}if(*y<0){*h+=*y;*y=0;}if(*x+*w>W)*w=W-*x;if(*y+*h>H)*h=H-*y;if(*w<0)*w=0;if(*h<0)*h=0;}
static void fill(int x,int y,int w,int h,int c){clip(&x,&y,&w,&h);for(int j=y;j<y+h;j++)memset(fb+j*S+x,c,w);}
static void refresh(int x,int y,int w,int h,int fl){clip(&x,&y,&w,&h);for(int j=y;j<y+h;j++)memcpy(sc+j*S+x,fb+j*S+x,w);char l[200];snprintf(l,200,"S %d %d %d %d %d",y,x,w,h,fl);logl(l);}
static unsigned hashs(const char*s){unsigned h=5381;while(*s)h=h*33+(unsigned char)*s++;return h;}
int main(int argc,char**argv){
  const char*d=getenv("FBSIM_DIR");snprintf(dir,512,"%s",d?d:"/tmp");
  if(getenv("FBSIM_W"))W=atoi(getenv("FBSIM_W"));if(getenv("FBSIM_H"))H=atoi(getenv("FBSIM_H"));
  fb=malloc(S*2048);sc=malloc(S*2048);loadf("fb",fb);loadf("screen",sc);
  char*me=basename(argv[0]);
  if(!strcmp(me,"eips")){
    const char*file=0;int x=0,y=0,cl=0;
    for(int i=1;i<argc;i++){if(!strcmp(argv[i],"-g")&&i+1<argc)file=argv[++i];else if(!strcmp(argv[i],"-x")&&i+1<argc)x=atoi(argv[++i]);else if(!strcmp(argv[i],"-y")&&i+1<argc)y=atoi(argv[++i]);else if(!strcmp(argv[i],"-c"))cl=1;}
    if(cl){memset(fb,255,S*H);memset(sc,255,S*H);}
    if(file){FILE*f=fopen(file,"rb");unsigned char hd[24];int w=100,h=100;if(f){if(fread(hd,1,24,f)==24){w=(hd[16]<<24)|(hd[17]<<16)|(hd[18]<<8)|hd[19];h=(hd[20]<<24)|(hd[21]<<16)|(hd[22]<<8)|hd[23];}fclose(f);}else return 1;
      unsigned hs=hashs(file);int w0=w,h0=h;clip(&x,&y,&w,&h);(void)w0;(void)h0;
      /* có tệp điểm ảnh thật (<ảnh>.raw: "W H\n" + byte xám) thì dùng; không thì tô hoa văn theo tên tệp */
      char rp[800];snprintf(rp,800,"%s.raw",file);FILE*rf=fopen(rp,"rb");unsigned char*px=0;int pw=0,ph=0;
      if(rf){if(fscanf(rf,"%d %d",&pw,&ph)==2){fgetc(rf);px=malloc((size_t)pw*ph);if(fread(px,1,(size_t)pw*ph,rf)!=(size_t)pw*ph){free(px);px=0;}}fclose(rf);}
      int ox=x,oy=y;(void)ox;(void)oy;
      for(int j=y;j<y+h;j++)for(int i=x;i<x+w;i++){int sx=i-x,sy=j-y;fb[j*S+i]=(px&&sx<pw&&sy<ph)?px[sy*pw+sx]:((unsigned char)(((hs>>3)+i*3+j*5)&0xff)|1);}
      refresh(x,y,w,h,0);char l[700];snprintf(l,700,"EIPS %s %d %d",file,x,y);logl(l);}
    savef("fb",fb);savef("screen",sc);return 0;}
  int nb=0,bgless=0,flash=0,clear=0,center=0,info=0,dok=0,dos=0;const char*fg="BLACK",*bg="WHITE",*tspec=0,*kreg=0,*sreg=0,*str=0;
  for(int i=1;i<argc;i++){char*a=argv[i];
    if(!strcmp(a,"-q")||!strcmp(a,"-H")||!strcmp(a,"-h")||!strcmp(a,"-M"))continue;
    if(!strcmp(a,"-b"))nb=1;else if(!strcmp(a,"-O"))bgless=1;else if(!strcmp(a,"-f"))flash=1;else if(!strcmp(a,"-c"))clear=1;else if(!strcmp(a,"-m"))center=1;else if(!strcmp(a,"-e"))info=1;
    else if(!strcmp(a,"-C")&&i+1<argc)fg=argv[++i];else if(!strcmp(a,"-B")&&i+1<argc)bg=argv[++i];else if(!strcmp(a,"-W")&&i+1<argc)i++;
    else if(!strcmp(a,"-t")&&i+1<argc)tspec=argv[++i];
    else if(!strcmp(a,"-k")){dok=1;if(i+1<argc&&!strncmp(argv[i+1],"top=",4))kreg=argv[++i];}
    else if(!strcmp(a,"-s")){dos=1;if(i+1<argc&&!strncmp(argv[i+1],"top=",4))sreg=argv[++i];}
    else if(a[0]!='-'||strlen(a)>2)str=a;}
  if(info){printf("viewWidth=%d;viewHeight=%d;currentRota=0;\n",W,H);return 0;}
  if(getenv("FBSIM_TRACE")){char l[1200];int o=0;for(int i=1;i<argc&&o<1100;i++)o+=snprintf(l+o,1200-o,"%s ",argv[i]);char p2[600];snprintf(p2,600,"%s/trace",dir);FILE*f=fopen(p2,"a");if(f){fputs(l,f);fputc('\n',f);fclose(f);}}
  int rx=0,ry=0,rw=W,rh=H,did=0;
  if(clear){fill(0,0,W,H,col(bg));did=1;}
  if(dok){if(kreg){ry=kv(kreg,"top",0);rx=kv(kreg,"left",0);rw=kv(kreg,"width",W);rh=kv(kreg,"height",H);}fill(rx,ry,rw,rh,col(bg));did=1;}
  if(tspec&&str&&*str){int px=kv(tspec,"px",20),top=kv(tspec,"top",0),left=kv(tspec,"left",0),right=kv(tspec,"right",0),bottom=kv(tspec,"bottom",0);
    int n=0;for(const char*p=str;*p;p++)if((*p&0xC0)!=0x80)n++;
    int symf=(strstr(tspec,"symbols")||strstr(tspec,"chess.ttf"))?1:0;   /* phông ký hiệu: mực là hình vuông ~0,64 x 0,64 px, bắt đầu ~0,18 px dưới đỉnh */
    int w=symf?n*px*66/100:n*px*42/100;if(w>W-left-right)w=W-left-right;int h=px*12/10;if(h>H-top-bottom)h=H-top-bottom;
    if(center){left=W/8;top=H/2-px;w=W*3/4;h=px*3;}
    int x=left,y=top;clip(&x,&y,&w,&h);unsigned hs=hashs(str);int f=col(fg);
    if(!bgless)fill(x,y,w,h,col(bg));
    /* mực chỉ nằm trong thân chữ như phông thật: chữ số/chữ hoa từ ~0,24em đến ~0,97em dưới đỉnh dòng;
       chữ thường có thể xuống tới ~1,2em (đuôi g, y) và lên ~0,18em (dấu tiếng Việt) */
    int caps=1;for(const unsigned char*q=(const unsigned char*)str;*q;q++){if(*q>=0x80||(*q>='a'&&*q<='z')){caps=0;break;}}
    int i0=y+(caps?px*19/100:px*10/100), i1=y+(caps?px*81/100:px*100/100); if(symf){i0=y+px*17/100;i1=y+px*82/100;} if(center){i0=y;i1=y+h;} if(i1>y+h)i1=y+h; if(i0<y)i0=y;
    for(int j=i0;j<i1;j++)for(int i=x;i<x+w;i++)if(((i*7+j*13+hs)%5)==0)fb[j*S+i]=f;
    if(!kreg&&!clear){rx=x;ry=y;rw=w;rh=h;}did=1;}
  if(dos){if(sreg){ry=kv(sreg,"top",0);rx=kv(sreg,"left",0);rw=kv(sreg,"width",W);rh=kv(sreg,"height",H);}else{rx=0;ry=0;rw=W;rh=H;}refresh(rx,ry,rw,rh,flash);}
  else if(did&&!nb){if(clear){rx=0;ry=0;rw=W;rh=H;}refresh(rx,ry,rw,rh,flash);}
  savef("fb",fb);savef("screen",sc);return 0;}
