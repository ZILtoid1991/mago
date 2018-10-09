module EED.PropTables;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import EED.Common;
import EED.Properties;

struct PropPair
{
    const wchar_t* Name;
    StdProperty Property;
    this(const wchar_t* name, StdProperty property)
    {
        this.Name = name;
        this.Property = property;
    }
}

//------------------------------------------------------------------------

PropPair[] mBaseProps = [PropPair("sizeof"w, new PropertySize()),];

PropPair[] mIntProps = [
    PropPair("max"w, new PropertyIntegralMax()), PropPair("min"w, new PropertyIntegralMin()),
];

PropPair[] mFloatProps = [
    PropPair("max"w, new PropertyFloatMax()), PropPair("min_normal"w,
        new PropertyFloatMin()), PropPair("infinity"w, new PropertyFloatInfinity()), PropPair("nan"w,
        new PropertyFloatNan()), PropPair("dig"w, new PropertyFloatDigits()), PropPair("epsilon"w,
        new PropertyFloatEpsilon()), PropPair("mant_dig"w, new PropertyFloatMantissaDigits()), PropPair("max_10_exp"w,
        new PropertyFloatMax10Exp()), PropPair("max_exp"w, new PropertyFloatMaxExp()), PropPair("min_10_exp"w,
        new PropertyFloatMin10Exp()), PropPair("min_exp"w, new PropertyFloatMinExp()), PropPair("re"w,
        new PropertyFloatReal()), PropPair("im"w, new PropertyFloatImaginary()),
];

PropPair[] mDArrayProps = [
    PropPair("length"w, new PropertyDArrayLength()), PropPair("ptr"w, new PropertyDArrayPtr()),
];

PropPair[] mSArrayProps = [
    PropPair("length"w, new PropertySArrayLength()), PropPair("ptr"w, new PropertySArrayPtr()),
];

PropPair[] mDelegateProps = [
    PropPair("ptr"w, new PropertyDelegatePtr()), PropPair("funcptr"w,
        new PropertyDelegateFuncPtr()),
];

PropPair[] mFieldProps = [PropPair("offsetof"w, new PropertyFieldOffset()),];

struct PropPairPair {
    PropPair* Pair; 
    size_t Len;
    this(PropPair pair, size_t len){
        this.Pair = pair;
        this.Len = len;
    }
}


PropPairPair[] mAllPropPairs = [
    PropPairPair(mBaseProps, mBaseProps.length), PropPairPair(mIntProps,
        mIntProps.length), PropPairPair(mFloatProps, mFloatProps.length), PropPairPair(mDArrayProps,
        mDArrayProps.length), PropPairPair(mSArrayProps, mSArrayProps.length), PropPairPair(mDelegateProps,
        mDelegateProps.length), PropPairPair(mFieldProps, mFieldProps.length),
]; //------------------------------------------------------------------------

HRESULT InitPropTables()
{
    return S_OK;}

    void FreePropTables()
    {
        for (size_t i = 0; i < _countof(mAllPropPairs); i++)
        {
            for (size_t j = 0; j < mAllPropPairs[i].Len; j++)
            {
                mAllPropPairs[i].Pair[j].Property.destroy;}
            }
        }

        StdProperty FindPropertyInArray(const wchar_t* name, PropPair* array, size_t len)
        {
            for (size_t i = 0; i < len; i++)
            {
                if (wcscmp(name, array[i].Name) == 0)
                    return array[i].Property;}
                return null;}

                StdProperty FindBaseProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mBaseProps, _countof(mBaseProps));
                }

                StdProperty FindIntProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mIntProps, _countof(mIntProps));
                }

                StdProperty FindFloatProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mFloatProps, _countof(mFloatProps));
                }

                StdProperty FindDArrayProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mDArrayProps, _countof(mDArrayProps));
                }

                StdProperty FindSArrayProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mSArrayProps, _countof(mSArrayProps));
                }

                StdProperty FindDelegateProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mDelegateProps, _countof(mDelegateProps));
                }

                StdProperty FindFieldProperty(const wchar_t* name)
                {
                    return FindPropertyInArray(name, mFieldProps, _countof(mFieldProps));
                }
