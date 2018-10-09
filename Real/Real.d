module Real.Real;

/*Complex.h
Real.h*/
/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
//import Real;
//import gdtoa;
import core.stdc.inttypes;

struct Real10
{
    uint16_t    Words[5];
    /// instead of relying on ecx holding the this pointer
/// use:         mov edx, dword ptr [this]
/// because ecx might have garbage if the method was inlined
void  Zero()
{
    memset( Words, 0,  Words.sizeof );
}
int     GetSign() const
{
    return ((Words[4] & 0x8000) == 0) ? 1 : -1;
}
// condition code bits in status word: (C0, C1, C2, C3) (8, 9, 10, 14)

bool     IsZero() const
{
    const  uint16_t   Mask = 0x4500;
    uint16_t         status = 0;
    const  uint16_t* words = Words;

    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        ftst;
        fnstsw  word  ptr  status;
        ffree  ST(0);
        fincstp;
    }

    return (status & Mask) == 0x4000;
}

bool     IsNan() const
{
    const  uint16_t   Mask = 0x4500;
    uint16_t         status = 0;
    const  uint16_t* words = Words;

    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fxam;
        fnstsw  word  ptr  status;
        ffree  ST(0);
        fincstp;
    }

    return (status & Mask) == 0x0100;
}

/*  FCOM
Condition               C3  C2  C0
ST(0) > SRC             0   0   0
ST(0) < SRC             0   0   1
ST(0) = SRC             1   0   0
Unordered*              1   1   1
*/

// condition code bits in status word: (C0, C1, C2, C3) (8, 9, 10, 14)

uint16_t     Compare( ref const  Real10  left, ref const  Real10  right )
{
    uint16_t         status = 0;

    asm
    {
        mov  eax, right;
        fld  tbyte  ptr [eax];
        mov  eax, left;
        fld  tbyte  ptr [eax];
        fcompp;                  //; compare ST(0) with ST(1) then pop twice
        fnstsw  word  ptr  status;
    }

    return  status;
}

bool          IsLess( uint16_t  status )
{
    const  uint16_t   Mask = 0x4500;
    return (status & Mask) == 0x0100;
}

bool          IsGreater( uint16_t  status )
{
    const  uint16_t   Mask = 0x4500;
    return (status & Mask) == 0x0;
}

bool          IsEqual( uint16_t  status )
{
    const  uint16_t   Mask = 0x4500;
    return (status & Mask) == 0x4000;
}

bool          IsUnordered( uint16_t  status )
{
    const  uint16_t   Mask = 0x4500;
    return (status & Mask) == 0x4500;
}

/*  FXAM
Class                   C3  C2  C0
Unsupported             0   0   0
NaN                     0   0   1
Normal finite number    0   1   0
Infinity                0   1   1
Zero                    1   0   0
Empty                   1   0   1
Denormal number         1   1   0
*/

// condition code bits in status word: (C0, C1, C2, C3) (8, 9, 10, 14)

bool     FitsInDouble() const
{
    const  uint16_t   Mask = 0x4500;
    uint16_t         status1 = 0;
    uint16_t         status2 = 0;
    double           d = 0.0;
    const  uint16_t* words = Words;

    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fxam;
        fnstsw  word  ptr  status1;
        fstp  qword  ptr  d;
        fld  qword  ptr  d;
        fxam;
        fnstsw  word  ptr  status2;
        ffree  ST(0);
        fincstp;
    }

    return (status1 & Mask) == (status2 & Mask);
}

bool     FitsInFloat() const
{
    const  uint16_t   Mask = 0x4500;
    uint16_t         status1 = 0;
    uint16_t         status2 = 0;
    float            f = 0.0;
    const  uint16_t* words = Words;

    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fxam;
        fnstsw  word  ptr  status1;
        fstp  dword  ptr  f;
        fld  dword  ptr  f;
        fxam;
        fnstsw  word  ptr  status2;
        ffree  ST(0);
        fincstp;
    }

    return (status1 & Mask) == (status2 & Mask);
}

double   ToDouble() const
{
    double           d = 0.0;
    const  uint16_t* words = Words;

    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fstp  qword  ptr  d;
    }

    return  d;
}

float    ToFloat() const
{
    float            f = 0.0;
    const  uint16_t* words = Words;

    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fstp  dword  ptr  f;
    }

    return  f;
}

int16_t  ToInt16() const
{
    int16_t          d = 0;
    const  uint16_t* words = Words;
    uint16_t         control = 0;
    const  uint16_t   rcControl = 0x0F7F;

    asm
    {
        fnstcw  word  ptr [control];
        fldcw  word  ptr [rcControl];          //; set rounding to truncate and precision to double-extended

        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fistp  word  ptr  d;        //; or should we use fisttp to truncate instead of rounding?

        fldcw  word  ptr [control];
    }

    return  d;
}

int32_t  ToInt32() const
{
    int32_t          d = 0;
    const  uint16_t* words = Words;
    uint16_t         control = 0;
    const  uint16_t   rcControl = 0x0F7F;

    asm
    {
        fnstcw  word  ptr [control];
        fldcw  word  ptr [rcControl];          //; set rounding to truncate and precision to double-extended

        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fistp  dword  ptr  d;       //; or should we use fisttp to truncate instead of rounding?

        fldcw  word  ptr [control];
    }

    return  d;
}

int64_t  ToInt64() const
{
    int64_t          d = 0;
    const  uint16_t* words = Words;
    uint16_t         control = 0;
    const  uint16_t   rcControl = 0x0F7F;

    asm
    {
        fnstcw  word  ptr [control];
        fldcw  word  ptr [rcControl];          //; set rounding to truncate and precision to double-extended

        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fistp  qword  ptr  d;       //; or should we use fisttp to truncate instead of rounding?

        fldcw  word  ptr [control];
    }

    return  d;
}

uint64_t  ToUInt64() const
{
    uint64_t         d = 0;
    const  uint16_t* words = Words;
    uint16_t         control = 0;
    const  uint16_t   rcControl = 0x0F7F;
    // represents 2^63 = 0x8000000000000000 in float80
    static  uint16_t  unsignedMSB64[5] = [ 0x0000, 0x0000, 0x0000, 0x8000, 0x403e ];

    // ___LDBLULLNG
    asm
    {
        mov  edx, dword  ptr [words];
        fld  tbyte  ptr [edx];
        fld  tbyte  ptr [unsignedMSB64];
        fcomp  st(1);
        fnstsw  ax;
        fnstcw  word  ptr [control];
        fldcw  word  ptr [rcControl];
        sahf;
        jae  NoMore;
        fld  tbyte  ptr [unsignedMSB64];
        fsubp  st(1), st(0);
        fistp  qword  ptr [d];
        add  dword  ptr [d+4], 80000000h;
        jmp  Done;
NoMore:;
        fistp  qword  ptr [d];
Done:;
        fldcw  word  ptr [control];
    }
    return  d;
}

void     FromDouble( double  d )
{
    uint16_t*   words = Words;

    asm
    {
        fld  qword  ptr  d;
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     FromFloat( float  f )
{
    uint16_t*   words = Words;

    asm
    {
        fld  dword  ptr  f;
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     FromInt32( int32_t  i )
{
    uint16_t*   words = Words;

    asm
    {
        fild  dword  ptr  i;
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     FromInt64( int64_t  i )
{
    uint16_t*   words = Words;

    asm
    {
        fild  qword  ptr  i;
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     FromUInt64( uint64_t  i )
{
    uint16_t*       words = Words;
    uint64_t         iNoMSB = i & 0x7fffffffffffffff;
    // represents 2^63 = 0x8000000000000000 in float80
    static  uint16_t  unsignedMSB64[5] = [ 0x0000, 0x0000, 0x0000, 0x8000, 0x403e ];
    uint16_t         control = 0;

    asm
    {
        fnstcw  word  ptr [control];
        or  word  ptr [control], 0300h;    //; set precision to double-extended
        fldcw  word  ptr [control];

        //; load the integer without the most significant bit
        fild  qword  ptr  iNoMSB;
    }

    // was the MSB set? if so, add it as an already converted float80
    if ( i != iNoMSB )
    {
        asm
        {
            fld  tbyte  ptr [unsignedMSB64];
            fadd;
        }
    }

    asm
    {
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     LoadInfinity()
{
    strtopx( "infinity", null, Words );
}

void     LoadNegativeInfinity()
{
    strtopx( "-infinity", null, Words );
}

void     LoadNan()
{
    strtopx( "nan", null, Words );
}

void     LoadEpsilon()
{
    Words[0] = 0x0000;
    Words[1] = 0x0000;
    Words[2] = 0x0000;
    Words[3] = 0x8000;
    Words[4] = 0x3fc0;
}

void     LoadMax()
{
    Words[0] = 0xffff;
    Words[1] = 0xffff;
    Words[2] = 0xffff;
    Words[3] = 0xffff;
    Words[4] = 0x7ffe;
}

void     LoadMinNormal()
{
    Words[0] = 0x0000;
    Words[1] = 0x0000;
    Words[2] = 0x0000;
    Words[3] = 0x8000;
    Words[4] = 0x0001;
}

int      MantissaDigits()
{
    return  64;
}

int      MaxExponentBase10()
{
    return  4932;
}

int      MaxExponentBase2()
{
    return  16384;
}

int      MinExponentBase10()
{
    return -4932;
}

int      MinExponentBase2()
{
    return -16381;
}

void     Add( ref const  Real10  left, ref const  Real10  right )
{
    uint16_t*   words = Words;
    uint16_t     control = 0;

    asm
    {
        // TODO: modify the control word like this for all operations, 
        //      maybe it should be global?
        //      do we need to set it back after the operation?

        fnstcw  word  ptr [control];
        or  word  ptr [control], 0300h;    //; set precision to double-extended
        fldcw  word  ptr [control];

        mov  eax, left;
        fld  tbyte  ptr [eax];
        mov  eax, right;
        fld  tbyte  ptr [eax];
        fadd;                    //; ST(1) := ST(1) + ST(0) then pop
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     Sub( ref const  Real10  left, ref const  Real10  right )
{
    uint16_t*   words = Words;
    uint16_t     control = 0;

    asm
    {
        fnstcw  word  ptr [control];
        or  word  ptr [control], 0300h;    //; set precision to double-extended
        fldcw  word  ptr [control];

        mov  eax, left;
        fld  tbyte  ptr [eax];
        mov  eax, right;
        fld  tbyte  ptr [eax];
        fsub;                    //; ST(1) := ST(1) - ST(0) then pop
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     Mul( ref const  Real10  left, ref const  Real10  right )
{
    uint16_t*   words = Words;
    uint16_t     control = 0;

    asm
    {
        fnstcw  word  ptr [control];
        or  word  ptr [control], 0300h;    //; set precision to double-extended
        fldcw  word  ptr [control];

        mov  eax, left;
        fld  tbyte  ptr [eax];
        mov  eax, right;
        fld  tbyte  ptr [eax];
        fmul;                    //; ST(1) := ST(1) * ST(0) then pop
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     Div( ref const  Real10  left, ref const  Real10  right )
{
    uint16_t*   words = Words;
    uint16_t     control = 0;

    asm
    {
        fnstcw  word  ptr [control];
        or  word  ptr [control], 0300h;    //; set precision to double-extended
        fldcw  word  ptr [control];

        mov  eax, left;
        fld  tbyte  ptr [eax];
        mov  eax, right;
        fld  tbyte  ptr [eax];
        fdiv;                    //; ST(1) := ST(1) / ST(0) then pop
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

void     Rem( ref const  Real10  left, ref const  Real10  right )
{
    uint16_t*   words = Words;
    uint16_t     control = 0;

    asm
    {
        fnstcw  word  ptr [control];
        or  word  ptr [control], 0300h;    //; set precision to double-extended
        fldcw  word  ptr [control];

        mov  eax, right;
        fld  tbyte  ptr [eax];
        mov  eax, left;
        fld  tbyte  ptr [eax];
Retry:;
        fprem;                   //; ST(0) := ST(0) % ST(1)    doesn't pop!
        fnstsw  ax;
        sahf;
        jp  Retry;

        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
        ffree  ST(0);
        fincstp;
    }
}

void     Negate( ref const  Real10  orig )
{
    uint16_t*   words = Words;

    asm
    {
static if(0) {
        fldz
         fld  tbyte  ptr [orig]
        fsub;
}  /* SYNTAX ERROR: (595): expression expected, not else */ else {
        mov  eax, orig
         fld  tbyte  ptr [eax]
        fchs
}
          /* SYNTAX ERROR: (600): expected ; instead of ptr */ 
        
     /* SYNTAX ERROR: unexpected trailing } */ }
 /* SYNTAX ERROR: unexpected trailing } */ }

void     Abs( ref const  Real10  orig )
{
    uint16_t*   words = Words;

    asm
    {
        mov  eax, orig;
        fld  tbyte  ptr [eax];
        fabs;
        mov  edx, dword  ptr [words];
        fstp  tbyte  ptr [edx];
    }
}

errno_t  Parse( const(wchar_t) * str, ref Real10  val )
{
    size_t   len = wcslen( str );
    char *   astr = new  char[ len + 1 ];

    for ( size_t  i = 0; i < len + 1; i++ )
        astr[i] = cast(char) str[i];

    errno_t  err = 0;
    char *   p = null;

    _set_errno( 0 );
    strtopx( astr, &p, val.Words );

    if ( p == astr )
        err = EINVAL;
    else
         _get_errno( &err );

    delete [] astr;

    return  err;
}


void  ToString( wchar_t * str, int  len, int  digits ) const
{
    char     s[Float80DecStrLen+1] = "";
    int      bufLen = (len > _countof( s )) ? _countof( s ) : len;

    // TODO: let the user change digit count
    g_xfmt( s, cast(void *) Words, digits, bufLen );

    for ( char * p = s; *p != '\0'; p++, str++ )
        *str = cast(wchar_t) *p;

    *str = '\0'w;
}

}






/*  FTST
Condition               C3  C2  C0
ST(0) > 0.0             0   0   0
ST(0) < 0.0             0   0   1
ST(0) = 0.0             1   0   0
Unordered*              1   1   1
*/

