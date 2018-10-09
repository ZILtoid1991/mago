module Real.Complex;

/*Complex.h
Real.h*/
/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

//import Common;
import Real.Complex;
import core.stdc.inttypes;

struct Complex10
{
    Real10  RealPart;
    Real10  ImaginaryPart;
    uint16_t      Compare( ref const  Complex10  left, ref const  Complex10  right )
{
    uint16_t     status = 0;

    status = Real10.Compare( left.ImaginaryPart, right.ImaginaryPart );

    if ( Real10.IsEqual( status ) )
    {
        status = Real10.Compare( left.RealPart, right.RealPart );
    }

    return  status;
}

void     Zero()
{
    RealPart.Zero();
    ImaginaryPart.Zero();
}

void     Add( ref const  Complex10  left, ref const  Complex10  right )
{
    RealPart.Add( left.RealPart, right.RealPart );
    ImaginaryPart.Add( left.ImaginaryPart, right.ImaginaryPart );
}

void     Sub( ref const  Complex10  left, ref const  Complex10  right )
{
    RealPart.Sub( left.RealPart, right.RealPart );
    ImaginaryPart.Sub( left.ImaginaryPart, right.ImaginaryPart );
}

void     Mul( ref const  Complex10  left, ref const  Complex10  right )
{
    // p.re = x.re * y.re - x.im * y.im;
    // p.im = x.im * y.re + x.re * y.im;

    Real10   m1;
    Real10   m2;

    m1.Mul( left.RealPart, right.RealPart );
    m2.Mul( left.ImaginaryPart, right.ImaginaryPart );
    RealPart.Sub( m1, m2 );

    m1.Mul( left.ImaginaryPart, right.RealPart );
    m2.Mul( left.RealPart, right.ImaginaryPart );
    ImaginaryPart.Add( m1, m2 );
}

void     Div( ref const  Complex10  left, ref const  Complex10  right )
{
    /*
    Complex q;
    long double r;
    long double den;

    if (fabs(y.re) < fabs(y.im))
    {
        r = y.re / y.im;
        den = y.im + r * y.re;
        q.re = (x.re * r + x.im) / den;
        q.im = (x.im * r - x.re) / den;
    }
    else
    {
        r = y.im / y.re;
        den = y.re + r * y.im;
        q.re = (x.re + r * x.im) / den;
        q.im = (x.im - r * x.re) / den;
    }
    return q;
    */

    // TODO: would it be more readable to use assembly here?
    //       or maybe there should be overloaded operators for Real10?

    Real10       r;
    Real10       den;
    Real10       absRe;
    Real10       absIm;
    uint16_t     status = 0;
    Real10       m;
    Real10       t;

    absRe.Abs( right.RealPart );
    absIm.Abs( right.ImaginaryPart );

    status = Real10.Compare( absRe, absIm );

    if ( Real10.IsLess( status ) )
    {
        r.Div( right.RealPart, right.ImaginaryPart );
        m.Mul( r, right.RealPart );
        den.Add( right.ImaginaryPart, m );
        t.Mul( left.RealPart, r );
        t.Add( t, left.ImaginaryPart );
        RealPart.Div( t, den );
        t.Mul( left.ImaginaryPart, r );
        t.Sub( t, left.RealPart );
        ImaginaryPart.Div( t, den );
    }
    else
    {
        r.Div( right.ImaginaryPart, right.RealPart );
        m.Mul( r, right.ImaginaryPart );
        den.Add( right.RealPart, m );
        t.Mul( r, left.ImaginaryPart );
        t.Add( left.RealPart, t );
        RealPart.Div( t, den );
        t.Mul( r, left.RealPart );
        t.Sub( left.ImaginaryPart, t );
        ImaginaryPart.Div( t, den );
    }
}

void     Rem( ref const  Complex10  left, ref const  Real10  right )
{
    RealPart.Rem( left.RealPart, right );
    ImaginaryPart.Rem( left.ImaginaryPart, right );
}

void     Negate( ref const  Complex10  orig )
{
    RealPart.Negate( orig.RealPart );
    ImaginaryPart.Negate( orig.ImaginaryPart );
}

    
}

