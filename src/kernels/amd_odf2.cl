#define GGI (get_global_id(0))
#define GLI (get_local_id(0))

#define SET_AB(ai1,ai2,ii1,ii2) { \
    elem=ii1>>2; \
    tmp1=(ii1&3)<<3; \
    ai1[elem] = ai1[elem]|(ai2<<(tmp1)); \
    ai1[elem+1] = (tmp1==0) ? 0 : ai2>>(32-tmp1);\
    }


__kernel void __attribute__((reqd_work_group_size(64, 1, 1))) 
strmodify( __global uint *dst,  __global uint *inp, __global uint *size, __global uint *sizein, uint16 str, uint16 salt)
{
__local uint inpc[64][14];
uint SIZE;
uint elem,tmp1;

inpc[GLI][0] = inp[GGI*(8)+0];
inpc[GLI][1] = inp[GGI*(8)+1];
inpc[GLI][2] = inp[GGI*(8)+2];
inpc[GLI][3] = inp[GGI*(8)+3];
inpc[GLI][4] = inp[GGI*(8)+4];
inpc[GLI][5] = inp[GGI*(8)+5];
inpc[GLI][6] = inp[GGI*(8)+6];
inpc[GLI][7] = inp[GGI*(8)+7];

SIZE=sizein[GGI];
size[GGI] = (SIZE+str.sF);

SET_AB(inpc[GLI],str.s0,SIZE,0);
SET_AB(inpc[GLI],str.s1,SIZE+4,0);
SET_AB(inpc[GLI],str.s2,SIZE+8,0);
SET_AB(inpc[GLI],str.s3,SIZE+12,0);

SET_AB(inpc[GLI],0x80,(SIZE+str.sF),0);

dst[GGI*8+0] = inpc[GLI][0];
dst[GGI*8+1] = inpc[GLI][1];
dst[GGI*8+2] = inpc[GLI][2];
dst[GGI*8+3] = inpc[GLI][3];
dst[GGI*8+4] = inpc[GLI][4];
dst[GGI*8+5] = inpc[GLI][5];
dst[GGI*8+6] = inpc[GLI][6];
dst[GGI*8+7] = inpc[GLI][7];
}

#ifndef OLD_ATI
#define F_00_19(bb,cc,dd) (bitselect((dd),(cc),(bb)))
#define F_20_39(bb,cc,dd)  ((bb) ^ (cc) ^ (dd))  
#define F_40_59(bb,cc,dd) (bitselect((cc), (bb), ((dd)^(cc))))
#define F_60_79(bb,cc,dd)  F_20_39((bb),(cc),(dd)) 
#else
#define F_00_19(bb,cc,dd)  ((((cc) ^ (dd)) & (bb)) ^ (dd))
#define F_20_39(bb,cc,dd)  ((cc) ^ (bb) ^ (dd))  
#define F_40_59(bb,cc,dd)  (((bb) & (cc)) | (((bb)|(cc)) & (dd)))  
#define F_60_79(bb,cc,dd)  F_20_39(bb,cc,dd) 
#endif

#define Endian_Reverse32(aa) { l=(aa);tmp1=rotate(l,Sl);tmp2=rotate(l,Sr); (aa)=bitselect(tmp2,tmp1,m); }
#define ROTATE1(aa, bb, cc, dd, ee, x) (ee) = (ee) + rotate((aa),S2) + F_00_19((bb),(cc),(dd)) + (x); (ee) = (ee) + K; (bb) = rotate((bb),S3) 
#define ROTATE1_NULL(aa, bb, cc, dd, ee)  (ee) = (ee) + rotate((aa),S2) + F_00_19((bb),(cc),(dd)) + K; (bb) = rotate((bb),S3)
#define ROTATE2_F(aa, bb, cc, dd, ee, x) (ee) = (ee) + rotate((aa),S2) + F_20_39((bb),(cc),(dd)) + (x) + K; (bb) = rotate((bb),S3) 
#define ROTATE3_F(aa, bb, cc, dd, ee, x) (ee) = (ee) + rotate((aa),S2) + F_40_59((bb),(cc),(dd)) + (x) + K; (bb) = rotate((bb),S3)
#define ROTATE4_F(aa, bb, cc, dd, ee, x) (ee) = (ee) + rotate((aa),S2) + F_60_79((bb),(cc),(dd)) + (x) + K; (bb) = rotate((bb),S3)

#define GLI get_local_id(0)


#define S11 3U
#define S12 7U
#define S13 11U
#define S14 19U
#define S21 3U
#define S22 5U
#define S23 9U
#define S24 13U
#define S31 3U
#define S32 9U
#define S33 11U
#define S34 15U

#define Ca 0x67452301  
#define Cb 0xefcdab89  
#define Cc 0x98badcfe  
#define Cd 0x10325476  

#define S1 1U
#define S2 5U
#define S3 30U
#define Sl 8U
#define Sr 24U
#define m 0x00FF00FFU
#define m2 0xFF00FF00U

#define SH0 0x6A09E667U
#define SH1 0xBB67AE85U
#define SH2 0x3C6EF372U
#define SH3 0xA54FF53AU
#define SH4 0x510E527FU
#define SH5 0x9B05688CU
#define SH6 0x1F83D9ABU
#define SH7 0x5BE0CD19U

#define  SHR(x,n) ((x) >> n)
#define ROTR(x,n) (rotate(x,(32-n)))

#define SS0(x) (ROTR(x, 7U) ^  SHR(x, 3U)^ ROTR(x,18U) )
#define SS1(x) (ROTR(x,17U) ^  SHR(x,10U)^ ROTR(x,19U) )
#define SS2(x) (ROTR(x, 2U) ^ ROTR(x,22U)^ ROTR(x,13U) )
#define SS3(x) (ROTR(x, 6U) ^ ROTR(x,25U)^ ROTR(x,11U) )

#define F1(x,y,z) (bitselect(z,y,x))
#define F0(x,y,z) (bitselect(y, x,(z^y)))

#define P(a,b,c,d,e,f,g,h,x,K) {tmp1 =  F1(e,f,g) +  SS3(e) + h + K +x;tmp2 = F0(a,b,c) + SS2(a);d += tmp1; h = tmp1 + tmp2;}
#define P0(a,b,c,d,e,f,g,h,K) {tmp1 = SS3(e) + F1(e,f,g) + h + K;tmp2 = SS2(a) + F0(a,b,c);d += tmp1; h = tmp1 + tmp2;}




#ifndef GCN
__kernel 
__attribute__((reqd_work_group_size(64, 1, 1)))
void prepare( __global uint *dst,  __global uint *input, __global uint *size,  __global uint *found_ind, __global uint *found, uint16 salt,uint16 str)
{
uint2 SIZE,sz;  
uint ib,ic,id;  
uint2 a,b,c,d,e,f,g,h, tmp1, tmp2,l; 
uint2 w0, w1, w2, w3, w4, w5, w6, w7,w8,w9,w10,w11,w12,w13,w14,w16;
uint yl,yr,zl,zr,wl,wr;
uint2 K;
uint2 K0 = (uint2)0x5A827999;
uint2 K1 = (uint2)0x6ED9EBA1;
uint2 K2 = (uint2)0x8F1BBCDC;
uint2 K3 = (uint2)0xCA62C1D6;
uint2 H0 = (uint2)0x67452301;
uint2 H1 = (uint2)0xEFCDAB89;
uint2 H2 = (uint2)0x98BADCFE;
uint2 H3 = (uint2)0x10325476;
uint2 H4 = (uint2)0xC3D2E1F0;
uint2 A,B,C,D,E,F,G,H;
uint2 IPA,IPB,IPC,IPD,IPE;
uint2 OPA,OPB,OPC,OPD,OPE;
uint2 TA,TB,TC,TD,TE;
uint2 TTA,TTB,TTC,TTD,TTE,TTF,TTTA,TTTB,TTTC,TTTD,TTTE;
TTA=TTB=TTC=TTD=TTE=(uint2)0;


a.s0=input[get_global_id(0)*2*8];
b.s0=input[get_global_id(0)*2*8+1];
c.s0=input[get_global_id(0)*2*8+2];
d.s0=input[get_global_id(0)*2*8+3];
e.s0=input[get_global_id(0)*2*8+4];
f.s0=input[get_global_id(0)*2*8+5];
g.s0=input[get_global_id(0)*2*8+6];
h.s0=input[get_global_id(0)*2*8+7];

a.s1=input[get_global_id(0)*2*8+8];
b.s1=input[get_global_id(0)*2*8+9];
c.s1=input[get_global_id(0)*2*8+10];
d.s1=input[get_global_id(0)*2*8+11];
e.s1=input[get_global_id(0)*2*8+12];
f.s1=input[get_global_id(0)*2*8+13];
g.s1=input[get_global_id(0)*2*8+14];
h.s1=input[get_global_id(0)*2*8+15];

sz.s0=size[get_global_id(0)*2]<<3;
sz.s1=size[get_global_id(0)*2+1]<<3;

// Calculate sha1(ipad^key)
w0=a;
w1=b;
w2=c;
w3=d;
w4=e;
w5=f;
w6=g;
w7=h;

w8=w9=w10=w11=w12=w13=w14=0;
SIZE=sz;

A=SH0;
B=SH1;
C=SH2;
D=SH3;
E=SH4;
F=SH5;
G=SH6;
H=SH7;

Endian_Reverse32(w0);
P(A, B, C, D, E, F, G, H, w0, 0x428A2F98);
Endian_Reverse32(w1);
P(H, A, B, C, D, E, F, G, w1, 0x71374491);
Endian_Reverse32(w2);
P(G, H, A, B, C, D, E, F, w2, 0xB5C0FBCF);
Endian_Reverse32(w3);
P(F, G, H, A, B, C, D, E, w3, 0xE9B5DBA5);
Endian_Reverse32(w4);
P(E, F, G, H, A, B, C, D, w4, 0x3956C25B);
Endian_Reverse32(w5);
P(D, E, F, G, H, A, B, C, w5, 0x59F111F1);
Endian_Reverse32(w6);
P(C, D, E, F, G, H, A, B, w6, 0x923F82A4);
Endian_Reverse32(w7);
P(B, C, D, E, F, G, H, A, w7, 0xAB1C5ED5);
P0(A, B, C, D, E, F, G, H, 0xD807AA98);
P0(H, A, B, C, D, E, F, G, 0x12835B01);
P0(G, H, A, B, C, D, E, F, 0x243185BE);
P0(F, G, H, A, B, C, D, E, 0x550C7DC3);
P0(E, F, G, H, A, B, C, D, 0x72BE5D74);
P0(D, E, F, G, H, A, B, C, 0x80DEB1FE);
P0(C, D, E, F, G, H, A, B, 0x9BDC06A7);
P(B, C, D, E, F, G, H, A, SIZE, 0xC19BF174);
w16=SS0(w1)+w0; P(A, B, C, D, E, F, G, H, w16, 0xE49B69C1);
w0=SS1(SIZE)+SS0(w2)+w1; P(H, A, B, C, D, E, F, G, w0,  0xEFBE4786);
w1=SS1(w16)+SS0(w3)+w2;  P(G, H, A, B, C, D, E, F, w1, 0x0FC19DC6);
w2=SS1(w0)+SS0(w4)+w3; P(F, G, H, A, B, C, D, E, w2, 0x240CA1CC);
w3=SS1(w1)+w13+SS0(w5)+w4; P(E, F, G, H, A, B, C, D, w3, 0x2DE92C6F);
w4=SS1(w2)+w14+SS0(w6)+w5; P(D, E, F, G, H, A, B, C, w4, 0x4A7484AA);
w5=SS1(w3)+SIZE+SS0(w7)+w6; P(C, D, E, F, G, H, A, B, w5, 0x5CB0A9DC);
w6=SS1(w4)+w16+SS0(w8)+w7; P(B, C, D, E, F, G, H, A, w6, 0x76F988DA);
w7=SS1(w5)+w0+SS0(w9)+w8; P(A, B, C, D, E, F, G, H, w7, 0x983E5152);
w8=SS1(w6)+w1+SS0(w10)+w9; P(H, A, B, C, D, E, F, G, w8, 0xA831C66D);
w9=SS1(w7)+w2+SS0(w11)+w10; P(G, H, A, B, C, D, E, F, w9, 0xB00327C8);
w10=SS1(w8)+w3+SS0(w12)+w11; P(F, G, H, A, B, C, D, E, w10, 0xBF597FC7);
w11=SS1(w9)+w4+SS0(w13)+w12; P(E, F, G, H, A, B, C, D, w11, 0xC6E00BF3);
w12=SS1(w10)+w5+SS0(w14)+w13; P(D, E, F, G, H, A, B, C, w12, 0xD5A79147);
w13=SS1(w11)+w6+SS0(SIZE)+w14; P(C, D, E, F, G, H, A, B, w13, 0x06CA6351);
w14=SS1(w12)+w7+SS0(w16)+SIZE; P(B, C, D, E, F, G, H, A, w14, 0x14292967);
SIZE=SS1(w13)+w8+SS0(w0)+w16; P(A, B, C, D, E, F, G, H, SIZE, 0x27B70A85);
w16=SS1(w14)+w9+SS0(w1)+w0; P(H, A, B, C, D, E, F, G, w16, 0x2E1B2138);
w0=SS1(SIZE)+w10+SS0(w2)+w1; P(G, H, A, B, C, D, E, F, w0, 0x4D2C6DFC);
w1=SS1(w16)+w11+SS0(w3)+w2; P(F, G, H, A, B, C, D, E, w1, 0x53380D13);
w2=SS1(w0)+w12+SS0(w4)+w3; P(E, F, G, H, A, B, C, D, w2, 0x650A7354);
w3=SS1(w1)+w13+SS0(w5)+w4; P(D, E, F, G, H, A, B, C, w3, 0x766A0ABB);
w4=SS1(w2)+w14+SS0(w6)+w5; P(C, D, E, F, G, H, A, B, w4, 0x81C2C92E);
w5=SS1(w3)+SIZE+SS0(w7)+w6; P(B, C, D, E, F, G, H, A, w5, 0x92722C85);
w6=SS1(w4)+w16+SS0(w8)+w7; P(A, B, C, D, E, F, G, H, w6, 0xA2BFE8A1);
w7=SS1(w5)+w0+SS0(w9)+w8; P(H, A, B, C, D, E, F, G, w7, 0xA81A664B);
w8=SS1(w6)+w1+SS0(w10)+w9; P(G, H, A, B, C, D, E, F, w8, 0xC24B8B70);
w9=SS1(w7)+w2+SS0(w11)+w10; P(F, G, H, A, B, C, D, E, w9, 0xC76C51A3);
w10=SS1(w8)+w3+SS0(w12)+w11; P(E, F, G, H, A, B, C, D, w10, 0xD192E819);
w11=SS1(w9)+w4+SS0(w13)+w12; P(D, E, F, G, H, A, B, C, w11, 0xD6990624);
w12=SS1(w10)+w5+SS0(w14)+w13; P(C, D, E, F, G, H, A, B, w12, 0xF40E3585);
w13=SS1(w11)+w6+SS0(SIZE)+w14; P(B, C, D, E, F, G, H, A, w13, 0x106AA070);
w14=SS1(w12)+w7+SS0(w16)+SIZE; P(A, B, C, D, E, F, G, H, w14, 0x19A4C116);
SIZE=SS1(w13)+w8+SS0(w0)+w16; P(H, A, B, C, D, E, F, G, SIZE, 0x1E376C08);
w16=SS1(w14)+w9+SS0(w1)+w0; P(G, H, A, B, C, D, E, F, w16, 0x2748774C);
w0=SS1(SIZE)+w10+SS0(w2)+w1; P(F, G, H, A, B, C, D, E, w0, 0x34B0BCB5);
w1=SS1(w16)+w11+SS0(w3)+w2; P(E, F, G, H, A, B, C, D, w1, 0x391C0CB3);
w2=SS1(w0)+w12+SS0(w4)+w3; P(D, E, F, G, H, A, B, C, w2, 0x4ED8AA4A);
w3=SS1(w1)+w13+SS0(w5)+w4; P(C, D, E, F, G, H, A, B, w3, 0x5B9CCA4F);
w4=SS1(w2)+w14+SS0(w6)+w5; P(B, C, D, E, F, G, H, A, w4, 0x682E6FF3);
w5=SS1(w3)+SIZE+SS0(w7)+w6; P(A, B, C, D, E, F, G, H, w5, 0x748F82EE);
w6=SS1(w4)+w16+SS0(w8)+w7; P(H, A, B, C, D, E, F, G, w6, 0x78A5636F);
w7=SS1(w5)+w0+SS0(w9)+w8; P(G, H, A, B, C, D, E, F, w7, 0x84C87814);
w8=SS1(w6)+w1+SS0(w10)+w9; P(F, G, H, A, B, C, D, E, w8, 0x8CC70208);
w9=SS1(w7)+w2+SS0(w11)+w10; P(E, F, G, H, A, B, C, D, w9, 0x90BEFFFA);
w10=SS1(w8)+w3+SS0(w12)+w11; P(D, E, F, G, H, A, B, C, w10, 0xA4506CEB);
w11=SS1(w9)+w4+SS0(w13)+w12; P(C, D, E, F, G, H, A, B, w11, 0xBEF9A3F7);
w12=SS1(w10)+w5+SS0(w14)+w13; P(B, C, D, E, F, G, H, A, w12, 0xC67178F2);

a=A+SH0;b=B+SH1;c=C+SH2;d=D+SH3;e=E+SH4;f=F+SH5;g=G+SH6;h=H+SH7;

// Calculate sha1(ipad^key)
w0=a^(uint2)0x36363636;
w1=b^(uint2)0x36363636;
w2=c^(uint2)0x36363636;
w3=d^(uint2)0x36363636;
w4=e^(uint2)0x36363636;
w5=f^(uint2)0x36363636;
w6=g^(uint2)0x36363636;
w7=h^(uint2)0x36363636;

w8=w9=w10=w11=w12=w13=w14=SIZE=(uint2)0x36363636;

A=H0;
B=H1;
C=H2;
D=H3;
E=H4;

K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);

IPA=A+H0;IPB=B+H1;IPC=C+H2;IPD=D+H3;IPE=E+H4;



// Calculate sha1(opad^key)
w0=a^(uint2)0x5c5c5c5c;
w1=b^(uint2)0x5c5c5c5c;
w2=c^(uint2)0x5c5c5c5c;
w3=d^(uint2)0x5c5c5c5c;
w4=e^(uint2)0x5c5c5c5c;
w5=f^(uint2)0x5c5c5c5c;
w6=g^(uint2)0x5c5c5c5c;
w7=h^(uint2)0x5c5c5c5c;

w8=w9=w10=w11=w12=w13=w14=SIZE=(uint2)0x5c5c5c5c;
A=H0;
B=H1;
C=H2;
D=H3;
E=H4;
K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);

OPA=A+H0;OPB=B+H1;OPC=C+H2;OPD=D+H3;OPE=E+H4;




// calculate hash sum 1
A=IPA;
B=IPB;
C=IPC;
D=IPD;
E=IPE;

w0=(uint2)salt.s0;
w1=(uint2)salt.s1;
w2=(uint2)salt.s2;
w3=(uint2)salt.s3;
w4=(uint2)salt.s4;
w5=0x80000000;
SIZE=(uint2)salt.sF;
w6=w7=w8=w9=w10=w11=w12=w13=w14=(uint2)0;


K = K0;
Endian_Reverse32(w0);  
ROTATE1(A, B, C, D, E, w0);
Endian_Reverse32(w1);  
ROTATE1(E, A, B, C, D, w1);
Endian_Reverse32(w2);  
ROTATE1(D, E, A, B, C, w2);
Endian_Reverse32(w3);  
ROTATE1(C, D, E, A, B, w3);
Endian_Reverse32(w4);  
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);
A=A+IPA;B=B+IPB;C=C+IPC;D=D+IPD;E=E+IPE;





// calculate hash sum 2

w0=A;
w1=B;
w2=C;
w3=D;
w4=E;
w5=(uint2)0x80000000;
A=OPA;
B=OPB;
C=OPC;
D=OPD;
E=OPE;
SIZE=(uint2)((64+20)<<3);
w6=w7=w8=w9=w10=w11=w12=w13=w14=(uint2)0;


K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);
A=A+OPA;B=B+OPB;C=C+OPC;D=D+OPD;E=E+OPE;
TTA=A;TTB=B;TTC=C;TTD=D;TTE=E;


dst[get_global_id(0)*40+0]=IPA.s0;
dst[get_global_id(0)*40+1]=IPB.s0;
dst[get_global_id(0)*40+2]=IPC.s0;
dst[get_global_id(0)*40+3]=IPD.s0;
dst[get_global_id(0)*40+4]=IPE.s0;
dst[get_global_id(0)*40+5]=OPA.s0;
dst[get_global_id(0)*40+6]=OPB.s0;
dst[get_global_id(0)*40+7]=OPC.s0;
dst[get_global_id(0)*40+8]=OPD.s0;
dst[get_global_id(0)*40+9]=OPE.s0;
dst[get_global_id(0)*40+10]=TTA.s0;
dst[get_global_id(0)*40+11]=TTB.s0;
dst[get_global_id(0)*40+12]=TTC.s0;
dst[get_global_id(0)*40+13]=TTD.s0;
dst[get_global_id(0)*40+14]=TTE.s0;
dst[get_global_id(0)*40+15]=TTA.s0;
dst[get_global_id(0)*40+16]=TTB.s0;
dst[get_global_id(0)*40+17]=TTC.s0;
dst[get_global_id(0)*40+18]=TTD.s0;
dst[get_global_id(0)*40+19]=TTE.s0;
dst[get_global_id(0)*40+20]=IPA.s1;
dst[get_global_id(0)*40+21]=IPB.s1;
dst[get_global_id(0)*40+22]=IPC.s1;
dst[get_global_id(0)*40+23]=IPD.s1;
dst[get_global_id(0)*40+24]=IPE.s1;
dst[get_global_id(0)*40+25]=OPA.s1;
dst[get_global_id(0)*40+26]=OPB.s1;
dst[get_global_id(0)*40+27]=OPC.s1;
dst[get_global_id(0)*40+28]=OPD.s1;
dst[get_global_id(0)*40+29]=OPE.s1;
dst[get_global_id(0)*40+30]=TTA.s1;
dst[get_global_id(0)*40+31]=TTB.s1;
dst[get_global_id(0)*40+32]=TTC.s1;
dst[get_global_id(0)*40+33]=TTD.s1;
dst[get_global_id(0)*40+34]=TTE.s1;
dst[get_global_id(0)*40+35]=TTA.s1;
dst[get_global_id(0)*40+36]=TTB.s1;
dst[get_global_id(0)*40+37]=TTC.s1;
dst[get_global_id(0)*40+38]=TTD.s1;
dst[get_global_id(0)*40+39]=TTE.s1;

}


__kernel 
__attribute__((reqd_work_group_size(64, 1, 1)))
void block( __global uint *dst,  __global uint *input, __global uint *size,  __global uint *found_ind, __global uint *found, uint16 salt,uint16 str)
{
uint2 SIZE;  
uint ib,ic,id;  
uint2 a,b,c,d,e,f,g,h, tmp1, tmp2,l; 
uint2 w0, w1, w2, w3, w4, w5, w6, w7,w8,w9,w10,w11,w12,w13,w14,w16;
uint yl,yr,zl,zr,wl,wr;
uint2 K;
uint2 K0 = (uint2)0x5A827999;
uint2 K1 = (uint2)0x6ED9EBA1;
uint2 K2 = (uint2)0x8F1BBCDC;
uint2 K3 = (uint2)0xCA62C1D6;
uint2 H0 = (uint2)0x67452301;
uint2 H1 = (uint2)0xEFCDAB89;
uint2 H2 = (uint2)0x98BADCFE;
uint2 H3 = (uint2)0x10325476;
uint2 H4 = (uint2)0xC3D2E1F0;
uint2 A,B,C,D,E;
uint2 IPA,IPB,IPC,IPD,IPE;
uint2 OPA,OPB,OPC,OPD,OPE;
uint2 TA,TB,TC,TD,TE;
uint2 TTA,TTB,TTC,TTD,TTE,TTF,TTTA,TTTB,TTTC,TTTD,TTTE;


IPA.s0=input[get_global_id(0)*40+0];
IPB.s0=input[get_global_id(0)*40+1];
IPC.s0=input[get_global_id(0)*40+2];
IPD.s0=input[get_global_id(0)*40+3];
IPE.s0=input[get_global_id(0)*40+4];
OPA.s0=input[get_global_id(0)*40+5];
OPB.s0=input[get_global_id(0)*40+6];
OPC.s0=input[get_global_id(0)*40+7];
OPD.s0=input[get_global_id(0)*40+8];
OPE.s0=input[get_global_id(0)*40+9];
A.s0=input[get_global_id(0)*40+10];
B.s0=input[get_global_id(0)*40+11];
C.s0=input[get_global_id(0)*40+12];
D.s0=input[get_global_id(0)*40+13];
E.s0=input[get_global_id(0)*40+14];
TTA.s0=input[get_global_id(0)*40+15];
TTB.s0=input[get_global_id(0)*40+16];
TTC.s0=input[get_global_id(0)*40+17];
TTD.s0=input[get_global_id(0)*40+18];
TTE.s0=input[get_global_id(0)*40+19];
IPA.s1=input[get_global_id(0)*40+20];
IPB.s1=input[get_global_id(0)*40+21];
IPC.s1=input[get_global_id(0)*40+22];
IPD.s1=input[get_global_id(0)*40+23];
IPE.s1=input[get_global_id(0)*40+24];
OPA.s1=input[get_global_id(0)*40+25];
OPB.s1=input[get_global_id(0)*40+26];
OPC.s1=input[get_global_id(0)*40+27];
OPD.s1=input[get_global_id(0)*40+28];
OPE.s1=input[get_global_id(0)*40+29];
A.s1=input[get_global_id(0)*40+30];
B.s1=input[get_global_id(0)*40+31];
C.s1=input[get_global_id(0)*40+32];
D.s1=input[get_global_id(0)*40+33];
E.s1=input[get_global_id(0)*40+34];
TTA.s1=input[get_global_id(0)*40+35];
TTB.s1=input[get_global_id(0)*40+36];
TTC.s1=input[get_global_id(0)*40+37];
TTD.s1=input[get_global_id(0)*40+38];
TTE.s1=input[get_global_id(0)*40+39];


// We now have the first HMAC. Iterate to find the rest
for (ic=salt.sA;ic<salt.sB;ic++)
{
// calculate hash sum 1
w0=A;
w1=B;
w2=C;
w3=D;
w4=E;
w5=(uint2)0x80000000;
SIZE=(uint2)(64+20)<<3;
A=IPA;
B=IPB;
C=IPC;
D=IPD;
E=IPE;

w6=w7=w8=w9=w10=w11=w12=w13=w14=(uint2)0;


K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1_NULL(A, B, C, D, E);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);
A=A+IPA;B=B+IPB;C=C+IPC;D=D+IPD;E=E+IPE;

// calculate hash sum 2
w0=A;
w1=B;
w2=C;
w3=D;
w4=E;
w5=(uint2)0x80000000;
A=OPA;
B=OPB;
C=OPC;
D=OPD;
E=OPE;

SIZE=(uint2)(64+20)<<3;
w6=w7=w8=w9=w10=w11=w12=w13=w14=w16=(uint2)0;


K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1_NULL(A, B, C, D, E);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);

A=A+OPA;B=B+OPB;C=C+OPC;D=D+OPD;E=E+OPE;
TTA^=A;TTB^=B;TTC^=C;TTD^=D;TTE^=E;
}

dst[get_global_id(0)*80+10]=A.s0;
dst[get_global_id(0)*80+11]=B.s0;
dst[get_global_id(0)*80+12]=C.s0;
dst[get_global_id(0)*80+13]=D.s0;
dst[get_global_id(0)*80+14]=E.s0;
dst[get_global_id(0)*80+15]=TTA.s0;
dst[get_global_id(0)*80+16]=TTB.s0;
dst[get_global_id(0)*80+17]=TTC.s0;
dst[get_global_id(0)*80+18]=TTD.s0;
dst[get_global_id(0)*80+19]=TTE.s0;
dst[get_global_id(0)*80+30]=A.s1;
dst[get_global_id(0)*80+31]=B.s1;
dst[get_global_id(0)*80+32]=C.s1;
dst[get_global_id(0)*80+33]=D.s1;
dst[get_global_id(0)*80+34]=E.s1;
dst[get_global_id(0)*80+35]=TTA.s1;
dst[get_global_id(0)*80+36]=TTB.s1;
dst[get_global_id(0)*80+37]=TTC.s1;
dst[get_global_id(0)*80+38]=TTD.s1;
dst[get_global_id(0)*80+39]=TTE.s1;
}



__kernel 
__attribute__((reqd_work_group_size(64, 1, 1)))
void final( __global uint *dst,  __global uint *input, __global uint *size,  __global uint *found_ind, __global uint *found, uint16 salt,uint16 str)
{
uint2 TTA,TTB,TTC,TTD,TTE,TA,l,tmp1,tmp2;

TTA.s0=input[get_global_id(0)*40+15];
TTB.s0=input[get_global_id(0)*40+16];
TTC.s0=input[get_global_id(0)*40+17];
TTD.s0=input[get_global_id(0)*40+18];
TTE.s0=input[get_global_id(0)*40+19];
TTA.s1=input[get_global_id(0)*40+35];
TTB.s1=input[get_global_id(0)*40+36];
TTC.s1=input[get_global_id(0)*40+37];
TTD.s1=input[get_global_id(0)*40+38];
TTE.s1=input[get_global_id(0)*40+39];


Endian_Reverse32(TTA);
Endian_Reverse32(TTB);
Endian_Reverse32(TTC);
Endian_Reverse32(TTD);
Endian_Reverse32(TTE);



if (salt.sE==0)
{
dst[(get_global_id(0)*16)] = (uint)(TTA.s0);
dst[(get_global_id(0)*16)+1] = (uint)(TTB.s0);
dst[(get_global_id(0)*16)+2] = (uint)(TTC.s0);
dst[(get_global_id(0)*16)+3] = (uint)(TTD.s0);
dst[(get_global_id(0)*16)+4] = (uint)(TTE.s0);
dst[(get_global_id(0)*16)+8] = (uint)(TTA.s1);
dst[(get_global_id(0)*16)+9] = (uint)(TTB.s1);
dst[(get_global_id(0)*16)+10] = (uint)(TTC.s1);
dst[(get_global_id(0)*16)+11] = (uint)(TTD.s1);
dst[(get_global_id(0)*16)+12] = (uint)(TTE.s1);
}
else
{
dst[(get_global_id(0)*16)+5] = (uint)(TTA.s0);
dst[(get_global_id(0)*16)+6] = (uint)(TTB.s0);
dst[(get_global_id(0)*16)+7] = (uint)(TTC.s0);
dst[(get_global_id(0)*16)+13] = (uint)(TTA.s1);
dst[(get_global_id(0)*16)+14] = (uint)(TTB.s1);
dst[(get_global_id(0)*16)+15] = (uint)(TTC.s1);
}

}



#else

__kernel 
__attribute__((reqd_work_group_size(64, 1, 1)))
void prepare( __global uint *dst,  __global uint *input, __global uint *size,  __global uint *found_ind, __global uint *found, uint16 salt,uint16 str)
{
uint SIZE,sz;  
uint ib,ic,id;  
uint a,b,c,d,e,f,g,h, tmp1, tmp2,l; 
uint w0, w1, w2, w3, w4, w5, w6, w7,w8,w9,w10,w11,w12,w13,w14,w16;
uint yl,yr,zl,zr,wl,wr;
uint K;
uint K0 = (uint)0x5A827999;
uint K1 = (uint)0x6ED9EBA1;
uint K2 = (uint)0x8F1BBCDC;
uint K3 = (uint)0xCA62C1D6;
uint H0 = (uint)0x67452301;
uint H1 = (uint)0xEFCDAB89;
uint H2 = (uint)0x98BADCFE;
uint H3 = (uint)0x10325476;
uint H4 = (uint)0xC3D2E1F0;
uint A,B,C,D,E,F,G,H;
uint IPA,IPB,IPC,IPD,IPE;
uint OPA,OPB,OPC,OPD,OPE;
uint TA,TB,TC,TD,TE;
uint TTA,TTB,TTC,TTD,TTE,TTF,TTTA,TTTB,TTTC,TTTD,TTTE;
TTA=TTB=TTC=TTD=TTE=(uint)0;


a=input[get_global_id(0)*8];
b=input[get_global_id(0)*8+1];
c=input[get_global_id(0)*8+2];
d=input[get_global_id(0)*8+3];
e=input[get_global_id(0)*8+4];
f=input[get_global_id(0)*8+5];
g=input[get_global_id(0)*8+6];
h=input[get_global_id(0)*8+7];

sz=size[get_global_id(0)]<<3;

// Calculate sha1(ipad^key)
w0=a;
w1=b;
w2=c;
w3=d;
w4=e;
w5=f;
w6=g;
w7=h;

w8=w9=w10=w11=w12=w13=w14=0;
SIZE=sz;

A=SH0;
B=SH1;
C=SH2;
D=SH3;
E=SH4;
F=SH5;
G=SH6;
H=SH7;

Endian_Reverse32(w0);
P(A, B, C, D, E, F, G, H, w0, 0x428A2F98);
Endian_Reverse32(w1);
P(H, A, B, C, D, E, F, G, w1, 0x71374491);
Endian_Reverse32(w2);
P(G, H, A, B, C, D, E, F, w2, 0xB5C0FBCF);
Endian_Reverse32(w3);
P(F, G, H, A, B, C, D, E, w3, 0xE9B5DBA5);
Endian_Reverse32(w4);
P(E, F, G, H, A, B, C, D, w4, 0x3956C25B);
Endian_Reverse32(w5);
P(D, E, F, G, H, A, B, C, w5, 0x59F111F1);
Endian_Reverse32(w6);
P(C, D, E, F, G, H, A, B, w6, 0x923F82A4);
Endian_Reverse32(w7);
P(B, C, D, E, F, G, H, A, w7, 0xAB1C5ED5);
P0(A, B, C, D, E, F, G, H, 0xD807AA98);
P0(H, A, B, C, D, E, F, G, 0x12835B01);
P0(G, H, A, B, C, D, E, F, 0x243185BE);
P0(F, G, H, A, B, C, D, E, 0x550C7DC3);
P0(E, F, G, H, A, B, C, D, 0x72BE5D74);
P0(D, E, F, G, H, A, B, C, 0x80DEB1FE);
P0(C, D, E, F, G, H, A, B, 0x9BDC06A7);
P(B, C, D, E, F, G, H, A, SIZE, 0xC19BF174);
w16=SS0(w1)+w0; P(A, B, C, D, E, F, G, H, w16, 0xE49B69C1);
w0=SS1(SIZE)+SS0(w2)+w1; P(H, A, B, C, D, E, F, G, w0,  0xEFBE4786);
w1=SS1(w16)+SS0(w3)+w2;  P(G, H, A, B, C, D, E, F, w1, 0x0FC19DC6);
w2=SS1(w0)+SS0(w4)+w3; P(F, G, H, A, B, C, D, E, w2, 0x240CA1CC);
w3=SS1(w1)+w13+SS0(w5)+w4; P(E, F, G, H, A, B, C, D, w3, 0x2DE92C6F);
w4=SS1(w2)+w14+SS0(w6)+w5; P(D, E, F, G, H, A, B, C, w4, 0x4A7484AA);
w5=SS1(w3)+SIZE+SS0(w7)+w6; P(C, D, E, F, G, H, A, B, w5, 0x5CB0A9DC);
w6=SS1(w4)+w16+SS0(w8)+w7; P(B, C, D, E, F, G, H, A, w6, 0x76F988DA);
w7=SS1(w5)+w0+SS0(w9)+w8; P(A, B, C, D, E, F, G, H, w7, 0x983E5152);
w8=SS1(w6)+w1+SS0(w10)+w9; P(H, A, B, C, D, E, F, G, w8, 0xA831C66D);
w9=SS1(w7)+w2+SS0(w11)+w10; P(G, H, A, B, C, D, E, F, w9, 0xB00327C8);
w10=SS1(w8)+w3+SS0(w12)+w11; P(F, G, H, A, B, C, D, E, w10, 0xBF597FC7);
w11=SS1(w9)+w4+SS0(w13)+w12; P(E, F, G, H, A, B, C, D, w11, 0xC6E00BF3);
w12=SS1(w10)+w5+SS0(w14)+w13; P(D, E, F, G, H, A, B, C, w12, 0xD5A79147);
w13=SS1(w11)+w6+SS0(SIZE)+w14; P(C, D, E, F, G, H, A, B, w13, 0x06CA6351);
w14=SS1(w12)+w7+SS0(w16)+SIZE; P(B, C, D, E, F, G, H, A, w14, 0x14292967);
SIZE=SS1(w13)+w8+SS0(w0)+w16; P(A, B, C, D, E, F, G, H, SIZE, 0x27B70A85);
w16=SS1(w14)+w9+SS0(w1)+w0; P(H, A, B, C, D, E, F, G, w16, 0x2E1B2138);
w0=SS1(SIZE)+w10+SS0(w2)+w1; P(G, H, A, B, C, D, E, F, w0, 0x4D2C6DFC);
w1=SS1(w16)+w11+SS0(w3)+w2; P(F, G, H, A, B, C, D, E, w1, 0x53380D13);
w2=SS1(w0)+w12+SS0(w4)+w3; P(E, F, G, H, A, B, C, D, w2, 0x650A7354);
w3=SS1(w1)+w13+SS0(w5)+w4; P(D, E, F, G, H, A, B, C, w3, 0x766A0ABB);
w4=SS1(w2)+w14+SS0(w6)+w5; P(C, D, E, F, G, H, A, B, w4, 0x81C2C92E);
w5=SS1(w3)+SIZE+SS0(w7)+w6; P(B, C, D, E, F, G, H, A, w5, 0x92722C85);
w6=SS1(w4)+w16+SS0(w8)+w7; P(A, B, C, D, E, F, G, H, w6, 0xA2BFE8A1);
w7=SS1(w5)+w0+SS0(w9)+w8; P(H, A, B, C, D, E, F, G, w7, 0xA81A664B);
w8=SS1(w6)+w1+SS0(w10)+w9; P(G, H, A, B, C, D, E, F, w8, 0xC24B8B70);
w9=SS1(w7)+w2+SS0(w11)+w10; P(F, G, H, A, B, C, D, E, w9, 0xC76C51A3);
w10=SS1(w8)+w3+SS0(w12)+w11; P(E, F, G, H, A, B, C, D, w10, 0xD192E819);
w11=SS1(w9)+w4+SS0(w13)+w12; P(D, E, F, G, H, A, B, C, w11, 0xD6990624);
w12=SS1(w10)+w5+SS0(w14)+w13; P(C, D, E, F, G, H, A, B, w12, 0xF40E3585);
w13=SS1(w11)+w6+SS0(SIZE)+w14; P(B, C, D, E, F, G, H, A, w13, 0x106AA070);
w14=SS1(w12)+w7+SS0(w16)+SIZE; P(A, B, C, D, E, F, G, H, w14, 0x19A4C116);
SIZE=SS1(w13)+w8+SS0(w0)+w16; P(H, A, B, C, D, E, F, G, SIZE, 0x1E376C08);
w16=SS1(w14)+w9+SS0(w1)+w0; P(G, H, A, B, C, D, E, F, w16, 0x2748774C);
w0=SS1(SIZE)+w10+SS0(w2)+w1; P(F, G, H, A, B, C, D, E, w0, 0x34B0BCB5);
w1=SS1(w16)+w11+SS0(w3)+w2; P(E, F, G, H, A, B, C, D, w1, 0x391C0CB3);
w2=SS1(w0)+w12+SS0(w4)+w3; P(D, E, F, G, H, A, B, C, w2, 0x4ED8AA4A);
w3=SS1(w1)+w13+SS0(w5)+w4; P(C, D, E, F, G, H, A, B, w3, 0x5B9CCA4F);
w4=SS1(w2)+w14+SS0(w6)+w5; P(B, C, D, E, F, G, H, A, w4, 0x682E6FF3);
w5=SS1(w3)+SIZE+SS0(w7)+w6; P(A, B, C, D, E, F, G, H, w5, 0x748F82EE);
w6=SS1(w4)+w16+SS0(w8)+w7; P(H, A, B, C, D, E, F, G, w6, 0x78A5636F);
w7=SS1(w5)+w0+SS0(w9)+w8; P(G, H, A, B, C, D, E, F, w7, 0x84C87814);
w8=SS1(w6)+w1+SS0(w10)+w9; P(F, G, H, A, B, C, D, E, w8, 0x8CC70208);
w9=SS1(w7)+w2+SS0(w11)+w10; P(E, F, G, H, A, B, C, D, w9, 0x90BEFFFA);
w10=SS1(w8)+w3+SS0(w12)+w11; P(D, E, F, G, H, A, B, C, w10, 0xA4506CEB);
w11=SS1(w9)+w4+SS0(w13)+w12; P(C, D, E, F, G, H, A, B, w11, 0xBEF9A3F7);
w12=SS1(w10)+w5+SS0(w14)+w13; P(B, C, D, E, F, G, H, A, w12, 0xC67178F2);

a=A+SH0;b=B+SH1;c=C+SH2;d=D+SH3;e=E+SH4;f=F+SH5;g=G+SH6;h=H+SH7;



// Calculate sha1(ipad^key)
w0=a^(uint)0x36363636;
w1=b^(uint)0x36363636;
w2=c^(uint)0x36363636;
w3=d^(uint)0x36363636;
w4=e^(uint)0x36363636;
w5=f^(uint)0x36363636;
w6=g^(uint)0x36363636;
w7=h^(uint)0x36363636;

w8=w9=w10=w11=w12=w13=w14=SIZE=(uint)0x36363636;

A=H0;
B=H1;
C=H2;
D=H3;
E=H4;

K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);

IPA=A+H0;IPB=B+H1;IPC=C+H2;IPD=D+H3;IPE=E+H4;



// Calculate sha1(opad^key)
w0=a^(uint)0x5c5c5c5c;
w1=b^(uint)0x5c5c5c5c;
w2=c^(uint)0x5c5c5c5c;
w3=d^(uint)0x5c5c5c5c;
w4=e^(uint)0x5c5c5c5c;
w5=f^(uint)0x5c5c5c5c;
w6=g^(uint)0x5c5c5c5c;
w7=h^(uint)0x5c5c5c5c;

w8=w9=w10=w11=w12=w13=w14=SIZE=(uint)0x5c5c5c5c;
A=H0;
B=H1;
C=H2;
D=H3;
E=H4;
K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);

OPA=A+H0;OPB=B+H1;OPC=C+H2;OPD=D+H3;OPE=E+H4;




// calculate hash sum 1
A=IPA;
B=IPB;
C=IPC;
D=IPD;
E=IPE;

w0=(uint)salt.s0;
w1=(uint)salt.s1;
w2=(uint)salt.s2;
w3=(uint)salt.s3;
w4=(uint)salt.s4;
w5=0x80000000;
SIZE=(uint)salt.sF;
w6=w7=w8=w9=w10=w11=w12=w13=w14=(uint)0;


K = K0;
Endian_Reverse32(w0);  
ROTATE1(A, B, C, D, E, w0);
Endian_Reverse32(w1);  
ROTATE1(E, A, B, C, D, w1);
Endian_Reverse32(w2);  
ROTATE1(D, E, A, B, C, w2);
Endian_Reverse32(w3);  
ROTATE1(C, D, E, A, B, w3);
Endian_Reverse32(w4);  
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);
A=A+IPA;B=B+IPB;C=C+IPC;D=D+IPD;E=E+IPE;





// calculate hash sum 2

w0=A;
w1=B;
w2=C;
w3=D;
w4=E;
w5=(uint)0x80000000;
A=OPA;
B=OPB;
C=OPC;
D=OPD;
E=OPE;
SIZE=(uint)((64+20)<<3);
w6=w7=w8=w9=w10=w11=w12=w13=w14=(uint)0;


K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1(E, A, B, C, D, w6);
ROTATE1(D, E, A, B, C, w7);
ROTATE1(C, D, E, A, B, w8);
ROTATE1(B, C, D, E, A, w9);
ROTATE1(A, B, C, D, E, w10);
ROTATE1(E, A, B, C, D, w11);
ROTATE1(D, E, A, B, C, w12);
ROTATE1(C, D, E, A, B, w13);
ROTATE1(B, C, D, E, A, w14);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);
A=A+OPA;B=B+OPB;C=C+OPC;D=D+OPD;E=E+OPE;
TTA=A;TTB=B;TTC=C;TTD=D;TTE=E;


dst[get_global_id(0)*20+0]=IPA;
dst[get_global_id(0)*20+1]=IPB;
dst[get_global_id(0)*20+2]=IPC;
dst[get_global_id(0)*20+3]=IPD;
dst[get_global_id(0)*20+4]=IPE;
dst[get_global_id(0)*20+5]=OPA;
dst[get_global_id(0)*20+6]=OPB;
dst[get_global_id(0)*20+7]=OPC;
dst[get_global_id(0)*20+8]=OPD;
dst[get_global_id(0)*20+9]=OPE;
dst[get_global_id(0)*20+10]=TTA;
dst[get_global_id(0)*20+11]=TTB;
dst[get_global_id(0)*20+12]=TTC;
dst[get_global_id(0)*20+13]=TTD;
dst[get_global_id(0)*20+14]=TTE;
dst[get_global_id(0)*20+15]=TTA;
dst[get_global_id(0)*20+16]=TTB;
dst[get_global_id(0)*20+17]=TTC;
dst[get_global_id(0)*20+18]=TTD;
dst[get_global_id(0)*20+19]=TTE;

}


__kernel 
__attribute__((reqd_work_group_size(64, 1, 1)))
void block( __global uint *dst,  __global uint *input, __global uint *size,  __global uint *found_ind, __global uint *found, uint16 salt,uint16 str)
{
uint SIZE;  
uint ib,ic,id;  
uint a,b,c,d,e,f,g,h, tmp1, tmp2,l; 
uint w0, w1, w2, w3, w4, w5, w6, w7,w8,w9,w10,w11,w12,w13,w14,w16;
uint yl,yr,zl,zr,wl,wr;
uint K;
uint K0 = (uint)0x5A827999;
uint K1 = (uint)0x6ED9EBA1;
uint K2 = (uint)0x8F1BBCDC;
uint K3 = (uint)0xCA62C1D6;
uint H0 = (uint)0x67452301;
uint H1 = (uint)0xEFCDAB89;
uint H2 = (uint)0x98BADCFE;
uint H3 = (uint)0x10325476;
uint H4 = (uint)0xC3D2E1F0;
uint A,B,C,D,E;
uint IPA,IPB,IPC,IPD,IPE;
uint OPA,OPB,OPC,OPD,OPE;
uint TA,TB,TC,TD,TE;
uint TTA,TTB,TTC,TTD,TTE,TTF,TTTA,TTTB,TTTC,TTTD,TTTE;


IPA=input[get_global_id(0)*20+0];
IPB=input[get_global_id(0)*20+1];
IPC=input[get_global_id(0)*20+2];
IPD=input[get_global_id(0)*20+3];
IPE=input[get_global_id(0)*20+4];
OPA=input[get_global_id(0)*20+5];
OPB=input[get_global_id(0)*20+6];
OPC=input[get_global_id(0)*20+7];
OPD=input[get_global_id(0)*20+8];
OPE=input[get_global_id(0)*20+9];
A=input[get_global_id(0)*20+10];
B=input[get_global_id(0)*20+11];
C=input[get_global_id(0)*20+12];
D=input[get_global_id(0)*20+13];
E=input[get_global_id(0)*20+14];
TTA=input[get_global_id(0)*20+15];
TTB=input[get_global_id(0)*20+16];
TTC=input[get_global_id(0)*20+17];
TTD=input[get_global_id(0)*20+18];
TTE=input[get_global_id(0)*20+19];


// We now have the first HMAC. Iterate to find the rest
for (ic=salt.sA;ic<salt.sB;ic++)
{
// calculate hash sum 1
w0=A;
w1=B;
w2=C;
w3=D;
w4=E;
w5=(uint)0x80000000;
SIZE=(uint)(64+20)<<3;
A=IPA;
B=IPB;
C=IPC;
D=IPD;
E=IPE;

w6=w7=w8=w9=w10=w11=w12=w13=w14=(uint)0;


K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1_NULL(A, B, C, D, E);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);
A=A+IPA;B=B+IPB;C=C+IPC;D=D+IPD;E=E+IPE;

// calculate hash sum 2
w0=A;
w1=B;
w2=C;
w3=D;
w4=E;
w5=(uint)0x80000000;
A=OPA;
B=OPB;
C=OPC;
D=OPD;
E=OPE;

SIZE=(uint)(64+20)<<3;
w6=w7=w8=w9=w10=w11=w12=w13=w14=w16=(uint)0;


K = K0;
ROTATE1(A, B, C, D, E, w0);
ROTATE1(E, A, B, C, D, w1);
ROTATE1(D, E, A, B, C, w2);
ROTATE1(C, D, E, A, B, w3);
ROTATE1(B, C, D, E, A, w4);
ROTATE1(A, B, C, D, E, w5);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1_NULL(A, B, C, D, E);
ROTATE1_NULL(E, A, B, C, D);
ROTATE1_NULL(D, E, A, B, C);
ROTATE1_NULL(C, D, E, A, B);
ROTATE1_NULL(B, C, D, E, A);
ROTATE1(A, B, C, D, E, SIZE);  
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1);ROTATE1(E,A,B,C,D,w16);
w0 = rotate((w14 ^ w9 ^ w3 ^ w1),S1);ROTATE1(D,E,A,B,C,w0); 
w1 = rotate((SIZE ^ w10 ^ w4 ^ w2),S1); ROTATE1(C,D,E,A,B,w1); 
w2 = rotate((w16 ^ w11 ^ w5 ^ w3),S1);  ROTATE1(B,C,D,E,A,w2); 
K = K1;
w3 = rotate((w0 ^ w12 ^ w6 ^ w4),S1); ROTATE2_F(A, B, C, D, E, w3);
w4 = rotate((w1 ^ w13 ^ w7 ^ w5),S1); ROTATE2_F(E, A, B, C, D, w4);
w5 = rotate((w2 ^ w14 ^ w8 ^ w6),S1); ROTATE2_F(D, E, A, B, C, w5);
w6 = rotate((w3 ^ SIZE ^ w9 ^ w7),S1);ROTATE2_F(C, D, E, A, B, w6);
w7 = rotate((w4 ^ w16 ^ w10 ^ w8),S1); ROTATE2_F(B, C, D, E, A, w7);
w8 = rotate((w5 ^ w0 ^ w11 ^ w9),S1); ROTATE2_F(A, B, C, D, E, w8);
w9 = rotate((w6 ^ w1 ^ w12 ^ w10),S1); ROTATE2_F(E, A, B, C, D, w9);
w10 = rotate((w7 ^ w2 ^ w13 ^ w11),S1); ROTATE2_F(D, E, A, B, C, w10); 
w11 = rotate((w8 ^ w3 ^ w14 ^ w12),S1); ROTATE2_F(C, D, E, A, B, w11); 
w12 = rotate((w9 ^ w4 ^ SIZE ^ w13),S1); ROTATE2_F(B, C, D, E, A, w12);
w13 = rotate((w10 ^ w5 ^ w16 ^ w14),S1); ROTATE2_F(A, B, C, D, E, w13);
w14 = rotate((w11 ^ w6 ^ w0 ^ SIZE),S1); ROTATE2_F(E, A, B, C, D, w14);
SIZE = rotate((w12 ^ w7 ^ w1 ^ w16),S1); ROTATE2_F(D, E, A, B, C, SIZE);
w16 = rotate((w13 ^ w8 ^ w2 ^ w0),S1); ROTATE2_F(C, D, E, A, B, w16);  
w0 = rotate(w14 ^ w9 ^ w3 ^ w1,S1); ROTATE2_F(B, C, D, E, A, w0);  
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2,S1); ROTATE2_F(A, B, C, D, E, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE2_F(E, A, B, C, D, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE2_F(D, E, A, B, C, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1);ROTATE2_F(C, D, E, A, B, w4);
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE2_F(B, C, D, E, A, w5);  
K = K2;
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(A, B, C, D, E, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(E, A, B, C, D, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(D, E, A, B, C, w8); 
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE3_F(C, D, E, A, B, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE3_F(B, C, D, E, A, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE3_F(A, B, C, D, E, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE3_F(E, A, B, C, D, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE3_F(D, E, A, B, C, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE3_F(C, D, E, A, B, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE3_F(B, C, D, E, A, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE3_F(A, B, C, D, E, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE3_F(E, A, B, C, D, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE3_F(D, E, A, B, C, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3, S1); ROTATE3_F(C, D, E, A, B, w2);
w3 = rotate(w0 ^ w12 ^ w6 ^ w4, S1); ROTATE3_F(B, C, D, E, A, w3); 
w4 = rotate(w1 ^ w13 ^ w7 ^ w5, S1); ROTATE3_F(A, B, C, D, E, w4); 
w5 = rotate(w2 ^ w14 ^ w8 ^ w6, S1); ROTATE3_F(E, A, B, C, D, w5); 
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7, S1); ROTATE3_F(D, E, A, B, C, w6);
w7 = rotate(w4 ^ w16 ^ w10 ^ w8, S1); ROTATE3_F(C, D, E, A, B, w7);
w8 = rotate(w5 ^ w0 ^ w11 ^ w9, S1); ROTATE3_F(B, C, D, E, A, w8); 
K = K3;
w9 = rotate(w6 ^ w1 ^ w12 ^ w10, S1); ROTATE4_F(A, B, C, D, E, w9);
w10 = rotate(w7 ^ w2 ^ w13 ^ w11, S1); ROTATE4_F(E, A, B, C, D, w10);  
w11 = rotate(w8 ^ w3 ^ w14 ^ w12, S1); ROTATE4_F(D, E, A, B, C, w11);  
w12 = rotate(w9 ^ w4 ^ SIZE ^ w13, S1); ROTATE4_F(C, D, E, A, B, w12); 
w13 = rotate(w10 ^ w5 ^ w16 ^ w14, S1); ROTATE4_F(B, C, D, E, A, w13); 
w14 = rotate(w11 ^ w6 ^ w0 ^ SIZE, S1); ROTATE4_F(A, B, C, D, E, w14); 
SIZE = rotate(w12 ^ w7 ^ w1 ^ w16, S1); ROTATE4_F(E, A, B, C, D, SIZE);
w16 = rotate(w13 ^ w8 ^ w2 ^ w0, S1); ROTATE4_F(D, E, A, B, C, w16);
w0 = rotate(w14 ^ w9 ^ w3 ^ w1, S1); ROTATE4_F(C, D, E, A, B, w0); 
w1 = rotate(SIZE ^ w10 ^ w4 ^ w2, S1); ROTATE4_F(B, C, D, E, A, w1);
w2 = rotate(w16 ^ w11 ^ w5 ^ w3,S1); ROTATE4_F(A, B, C, D, E, w2); 
w3 = rotate(w0 ^ w12 ^ w6 ^ w4,S1); ROTATE4_F(E, A, B, C, D, w3);  
w4 = rotate(w1 ^ w13 ^ w7 ^ w5,S1); ROTATE4_F(D, E, A, B, C, w4);  
w5 = rotate(w2 ^ w14 ^ w8 ^ w6,S1); ROTATE4_F(C, D, E, A, B, w5);  
w6 = rotate(w3 ^ SIZE ^ w9 ^ w7,S1); ROTATE4_F(B, C, D, E, A, w6); 
w7 = rotate(w4 ^ w16 ^ w10 ^ w8,S1); ROTATE4_F(A, B, C, D, E, w7); 
w8 = rotate(w5 ^ w0 ^ w11 ^ w9,S1); ROTATE4_F(E, A, B, C, D, w8);  
w9 = rotate(w6 ^ w1 ^ w12 ^ w10,S1); ROTATE4_F(D, E, A, B, C, w9); 
w10 = rotate(w7 ^ w2 ^ w13 ^ w11,S1); ROTATE4_F(C, D, E, A, B, w10);
w11 = rotate(w8 ^ w3 ^ w14 ^ w12,S1); ROTATE4_F(B, C, D, E, A, w11);

A=A+OPA;B=B+OPB;C=C+OPC;D=D+OPD;E=E+OPE;
TTA^=A;TTB^=B;TTC^=C;TTD^=D;TTE^=E;
}

dst[get_global_id(0)*20+10]=A;
dst[get_global_id(0)*20+11]=B;
dst[get_global_id(0)*20+12]=C;
dst[get_global_id(0)*20+13]=D;
dst[get_global_id(0)*20+14]=E;
dst[get_global_id(0)*20+15]=TTA;
dst[get_global_id(0)*20+16]=TTB;
dst[get_global_id(0)*20+17]=TTC;
dst[get_global_id(0)*20+18]=TTD;
dst[get_global_id(0)*20+19]=TTE;
}



__kernel 
__attribute__((reqd_work_group_size(64, 1, 1)))
void final( __global uint *dst,  __global uint *input, __global uint *size,  __global uint *found_ind, __global uint *found, uint16 salt,uint16 str)
{
uint TTA,TTB,TTC,TTD,TTE,TA,l,tmp1,tmp2;

TTA=input[get_global_id(0)*20+15];
TTB=input[get_global_id(0)*20+16];
TTC=input[get_global_id(0)*20+17];
TTD=input[get_global_id(0)*20+18];
TTE=input[get_global_id(0)*20+19];


Endian_Reverse32(TTA);
Endian_Reverse32(TTB);
Endian_Reverse32(TTC);
Endian_Reverse32(TTD);
Endian_Reverse32(TTE);

if (salt.sE==0)
{
dst[(get_global_id(0)*8)] = (uint)(TTA);
dst[(get_global_id(0)*8)+1] = (uint)(TTB);
dst[(get_global_id(0)*8)+2] = (uint)(TTC);
dst[(get_global_id(0)*8)+3] = (uint)(TTD);
dst[(get_global_id(0)*8)+4] = (uint)(TTE);
}
else
{
dst[(get_global_id(0)*8)+5] = (uint)(TTA);
dst[(get_global_id(0)*8)+6] = (uint)(TTB);
dst[(get_global_id(0)*8)+7] = (uint)(TTC);
}

}

#endif
