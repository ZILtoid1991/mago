module EED.NamedChars;

import EED.Common;

struct  NamedChar
{
    const(wchar_t)*  Name;
    dchar_t          Code;
    this(const(wchar_t)* name, dchar_t code){
        this.Name = name;
        this.Code = code;
    }
}


static immutable NamedChar[]  gChars = 
[
    // Name Value Symbol
    NamedChar( "quot"w, 0x22 ),    // 
    NamedChar( "amp"w, 0x26 ),    // &
    NamedChar( "lt"w, 0x3C ),    // <
    NamedChar( "gt"w, 0x3E ),    // >
    NamedChar( "OElig"w, 0x152 ),    // Œ
    NamedChar( "oelig"w, 0x153 ),    // œ
    NamedChar( "Scaron"w, 0x160 ),    // Š
    NamedChar( "scaron"w, 0x161 ),    // š
    NamedChar( "Yuml"w, 0x178 ),    // Ÿ
    NamedChar( "circ"w, 0x2C6 ),    // ˆ
    NamedChar( "tilde"w, 0x2DC ),    // ˜
    NamedChar( "ensp"w, 0x2002 ),    //  
    NamedChar( "emsp"w, 0x2003 ),    //  
    NamedChar( "thinsp"w, 0x2009 ),    //  
    NamedChar( "zwnj"w, 0x200C ),    // ‌
    NamedChar( "zwj"w, 0x200D ),    // ‍
    NamedChar( "lrm"w, 0x200E ),    // ‎
    NamedChar( "rlm"w, 0x200F ),    // ‏
    NamedChar( "ndash"w, 0x2013 ),    // –
    NamedChar( "mdash"w, 0x2014 ),    // —
    NamedChar( "lsquo"w, 0x2018 ),    // ‘
    NamedChar( "rsquo"w, 0x2019 ),    // ’
    NamedChar( "sbquo"w, 0x201A ),    // ‚
    NamedChar( "ldquo"w, 0x201C ),    // “
    NamedChar( "rdquo"w, 0x201D ),    // ”
    NamedChar( "bdquo"w, 0x201E ),    // „
    NamedChar( "dagger"w, 0x2020 ),    // †
    NamedChar( "Dagger"w, 0x2021 ),    // ‡
    NamedChar( "permil"w, 0x2030 ),    // ‰
    NamedChar( "lsaquo"w, 0x2039 ),    // ‹
    NamedChar( "rsaquo"w, 0x203A ),    // ›
    NamedChar( "euro"w, 0x20AC ),    // €
// Latin-1 (ISO-8859-1) Entities
    NamedChar( "nbsp"w, 0xA0 ),    // 
    NamedChar( "iexcl"w, 0xA1 ),    // ¡
    NamedChar( "cent"w, 0xA2 ),    // ¢
    NamedChar( "pound"w, 0xA3 ),    // £
    NamedChar( "curren"w, 0xA4 ),    // ¤
    NamedChar( "yen"w, 0xA5 ),    // ¥
    NamedChar( "brvbar"w, 0xA6 ),    // ¦
    NamedChar( "sect"w, 0xA7 ),    // §
    NamedChar( "uml"w, 0xA8 ),    // ¨
    NamedChar( "copy"w, 0xA9 ),    // ©
    NamedChar( "ordf"w, 0xAA ),    // ª
    NamedChar( "laquo"w, 0xAB ),    // «
    NamedChar( "not"w, 0xAC ),    // ¬
    NamedChar( "shy"w, 0xAD ),    // ­
    NamedChar( "reg"w, 0xAE ),    // ®
    NamedChar( "macr"w, 0xAF ),    // ¯
    NamedChar( "deg"w, 0xB0 ),    // °
    NamedChar( "plusmn"w, 0xB1 ),    // ±
    NamedChar( "sup2"w, 0xB2 ),    // ²
    NamedChar( "sup3"w, 0xB3 ),    // ³
    NamedChar( "acute"w, 0xB4 ),    // ´
    NamedChar( "micro"w, 0xB5 ),    // µ
    NamedChar( "para"w, 0xB6 ),    // ¶
    NamedChar( "middot"w, 0xB7 ),    // ·
    NamedChar( "cedil"w, 0xB8 ),    // ¸
    NamedChar( "sup1"w, 0xB9 ),    // ¹
    NamedChar( "ordm"w, 0xBA ),    // º
    NamedChar( "raquo"w, 0xBB ),    // »
    NamedChar( "frac14"w, 0xBC ),    // ¼
    NamedChar( "frac12"w, 0xBD ),    // ½
    NamedChar( "frac34"w, 0xBE ),    // ¾
    NamedChar( "iquest"w, 0xBF ),    // ¿
    NamedChar( "Agrave"w, 0xC0 ),    // À
    NamedChar( "Aacute"w, 0xC1 ),    // Á
    NamedChar( "Acirc"w, 0xC2 ),    // Â
    NamedChar( "Atilde"w, 0xC3 ),    // Ã
    NamedChar( "Auml"w, 0xC4 ),    // Ä
    NamedChar( "Aring"w, 0xC5 ),    // Å
    NamedChar( "AElig"w, 0xC6 ),    // Æ
    NamedChar( "Ccedil"w, 0xC7 ),    // Ç
    NamedChar( "Egrave"w, 0xC8 ),    // È
    NamedChar( "Eacute"w, 0xC9 ),    // É
    NamedChar( "Ecirc"w, 0xCA ),    // Ê
    NamedChar( "Euml"w, 0xCB ),    // Ë
    NamedChar( "Igrave"w, 0xCC ),    // Ì
    NamedChar( "Iacute"w, 0xCD ),    // Í
    NamedChar( "Icirc"w, 0xCE ),    // Î
    NamedChar( "Iuml"w, 0xCF ),    // Ï
    NamedChar( "ETH"w, 0xD0 ),    // Ð
    NamedChar( "Ntilde"w, 0xD1 ),    // Ñ
    NamedChar( "Ograve"w, 0xD2 ),    // Ò
    NamedChar( "Oacute"w, 0xD3 ),    // Ó
    NamedChar( "Ocirc"w, 0xD4 ),    // Ô
    NamedChar( "Otilde"w, 0xD5 ),    // Õ
    NamedChar( "Ouml"w, 0xD6 ),    // Ö
    NamedChar( "times"w, 0xD7 ),    // ×
    NamedChar( "Oslash"w, 0xD8 ),    // Ø
    NamedChar( "Ugrave"w, 0xD9 ),    // Ù
    NamedChar( "Uacute"w, 0xDA ),    // Ú
    NamedChar( "Ucirc"w, 0xDB ),    // Û
    NamedChar( "Uuml"w, 0xDC ),    // Ü
    NamedChar( "Yacute"w, 0xDD ),    // Ý
    NamedChar( "THORN"w, 0xDE ),    // Þ
    NamedChar( "szlig"w, 0xDF ),    // ß
    NamedChar( "agrave"w, 0xE0 ),    // à
    NamedChar( "aacute"w, 0xE1 ),    // á
    NamedChar( "acirc"w, 0xE2 ),    // â
    NamedChar( "atilde"w, 0xE3 ),    // ã
    NamedChar( "auml"w, 0xE4 ),    // ä
    NamedChar( "aring"w, 0xE5 ),    // å
    NamedChar( "aelig"w, 0xE6 ),    // æ
    NamedChar( "ccedil"w, 0xE7 ),    // ç
    NamedChar( "egrave"w, 0xE8 ),    // è
    NamedChar( "eacute"w, 0xE9 ),    // é
    NamedChar( "ecirc"w, 0xEA ),    // ê
    NamedChar( "euml"w, 0xEB ),    // ë
    NamedChar( "igrave"w, 0xEC ),    // ì
    NamedChar( "iacute"w, 0xED ),    // í
    NamedChar( "icirc"w, 0xEE ),    // î
    NamedChar( "iuml"w, 0xEF ),    // ï
    NamedChar( "eth"w, 0xF0 ),    // ð
    NamedChar( "ntilde"w, 0xF1 ),    // ñ
    NamedChar( "ograve"w, 0xF2 ),    // ò
    NamedChar( "oacute"w, 0xF3 ),    // ó
    NamedChar( "ocirc"w, 0xF4 ),    // ô
    NamedChar( "otilde"w, 0xF5 ),    // õ
    NamedChar( "ouml"w, 0xF6 ),    // ö
    NamedChar( "divide"w, 0xF7 ),    // ÷
    NamedChar( "oslash"w, 0xF8 ),    // ø
    NamedChar( "ugrave"w, 0xF9 ),    // ù
    NamedChar( "uacute"w, 0xFA ),    // ú
    NamedChar( "ucirc"w, 0xFB ),    // û
    NamedChar( "uuml"w, 0xFC ),    // ü
    NamedChar( "yacute"w, 0xFD ),    // ý
    NamedChar( "thorn"w, 0xFE ),    // þ
    NamedChar( "yuml"w, 0xFF ),    // ÿ
// Symbols and Greek letter entities
    NamedChar( "fnof"w, 0x192 ),    // ƒ
    NamedChar( "Alpha"w, 0x391 ),    // Α
    NamedChar( "Beta"w, 0x392 ),    // Β
    NamedChar( "Gamma"w, 0x393 ),    // Γ
    NamedChar( "Delta"w, 0x394 ),    // Δ
    NamedChar( "Epsilon"w, 0x395 ),    // Ε
    NamedChar( "Zeta"w, 0x396 ),    // Ζ
    NamedChar( "Eta"w, 0x397 ),    // Η
    NamedChar( "Theta"w, 0x398 ),    // Θ
    NamedChar( "Iota"w, 0x399 ),    // Ι
    NamedChar( "Kappa"w, 0x39A ),    // Κ
    NamedChar( "Lambda"w, 0x39B ),    // Λ
    NamedChar( "Mu"w, 0x39C ),    // Μ
    NamedChar( "Nu"w, 0x39D ),    // Ν
    NamedChar( "Xi"w, 0x39E ),    // Ξ
    NamedChar( "Omicron"w, 0x39F ),    // Ο
    NamedChar( "Pi"w, 0x3A0 ),    // Π
    NamedChar( "Rho"w, 0x3A1 ),    // Ρ
    NamedChar( "Sigma"w, 0x3A3 ),    // Σ
    NamedChar( "Tau"w, 0x3A4 ),    // Τ
    NamedChar( "Upsilon"w, 0x3A5 ),    // Υ
    NamedChar( "Phi"w, 0x3A6 ),    // Φ
    NamedChar( "Chi"w, 0x3A7 ),    // Χ
    NamedChar( "Psi"w, 0x3A8 ),    // Ψ
    NamedChar( "Omega"w, 0x3A9 ),    // Ω
    NamedChar( "alpha"w, 0x3B1 ),    // α
    NamedChar( "beta"w, 0x3B2 ),    // β
    NamedChar( "gamma"w, 0x3B3 ),    // γ
    NamedChar( "delta"w, 0x3B4 ),    // δ
    NamedChar( "epsilon"w, 0x3B5 ),    // ε
    NamedChar( "zeta"w, 0x3B6 ),    // ζ
    NamedChar( "eta"w, 0x3B7 ),    // η
    NamedChar( "theta"w, 0x3B8 ),    // θ
    NamedChar( "iota"w, 0x3B9 ),    // ι
    NamedChar( "kappa"w, 0x3BA ),    // κ
    NamedChar( "lambda"w, 0x3BB ),    // λ
    NamedChar( "mu"w, 0x3BC ),    // μ
    NamedChar( "nu"w, 0x3BD ),    // ν
    NamedChar( "xi"w, 0x3BE ),    // ξ
    NamedChar( "omicron"w, 0x3BF ),    // ο
    NamedChar( "pi"w, 0x3C0 ),    // π
    NamedChar( "rho"w, 0x3C1 ),    // ρ
    NamedChar( "sigmaf"w, 0x3C2 ),    // ς
    NamedChar( "sigma"w, 0x3C3 ),    // σ
    NamedChar( "tau"w, 0x3C4 ),    // τ
    NamedChar( "upsilon"w, 0x3C5 ),    // υ
    NamedChar( "phi"w, 0x3C6 ),    // φ
    NamedChar( "chi"w, 0x3C7 ),    // χ
    NamedChar( "psi"w, 0x3C8 ),    // ψ
    NamedChar( "omega"w, 0x3C9 ),    // ω
    NamedChar( "thetasym"w, 0x3D1 ),    // ϑ
    NamedChar( "upsih"w, 0x3D2 ),    // ϒ
    NamedChar( "piv"w, 0x3D6 ),    // ϖ
    NamedChar( "bull"w, 0x2022 ),    // •
    NamedChar( "hellip"w, 0x2026 ),    // …
    NamedChar( "prime"w, 0x2032 ),    // ′
    NamedChar( "Prime"w, 0x2033 ),    // ″
    NamedChar( "oline"w, 0x203E ),    // ‾
    NamedChar( "frasl"w, 0x2044 ),    // ⁄
    NamedChar( "weierp"w, 0x2118 ),    // ℘
    NamedChar( "image"w, 0x2111 ),    // ℑ
    NamedChar( "real"w, 0x211C ),    // ℜ
    NamedChar( "trade"w, 0x2122 ),    // ™
    NamedChar( "alefsym"w, 0x2135 ),    // ℵ
    NamedChar( "larr"w, 0x2190 ),    // ←
    NamedChar( "uarr"w, 0x2191 ),    // ↑
    NamedChar( "rarr"w, 0x2192 ),    // →
    NamedChar( "darr"w, 0x2193 ),    // ↓
    NamedChar( "harr"w, 0x2194 ),    // ↔
    NamedChar( "crarr"w, 0x21B5 ),    // ↵
    NamedChar( "lArr"w, 0x21D0 ),    // ⇐
    NamedChar( "uArr"w, 0x21D1 ),    // ⇑
    NamedChar( "rArr"w, 0x21D2 ),    // ⇒
    NamedChar( "dArr"w, 0x21D3 ),    // ⇓
    NamedChar( "hArr"w, 0x21D4 ),    // ⇔
    NamedChar( "forall"w, 0x2200 ),    // ∀
    NamedChar( "part"w, 0x2202 ),    // ∂
    NamedChar( "exist"w, 0x2203 ),    // ∃
    NamedChar( "empty"w, 0x2205 ),    // ∅
    NamedChar( "nabla"w, 0x2207 ),    // ∇
    NamedChar( "isin"w, 0x2208 ),    // ∈
    NamedChar( "notin"w, 0x2209 ),    // ∉
    NamedChar( "ni"w, 0x220B ),    // ∋
    NamedChar( "prod"w, 0x220F ),    // ∏
    NamedChar( "sum"w, 0x2211 ),    // ∑
    NamedChar( "minus"w, 0x2212 ),    // −
    NamedChar( "lowast"w, 0x2217 ),    // ∗
    NamedChar( "radic"w, 0x221A ),    // √
    NamedChar( "prop"w, 0x221D ),    // ∝
    NamedChar( "infin"w, 0x221E ),    // ∞
    NamedChar( "ang"w, 0x2220 ),    // ∠
    NamedChar( "and"w, 0x2227 ),    // ∧
    NamedChar( "or"w, 0x2228 ),    // ∨
    NamedChar( "cap"w, 0x2229 ),    // ∩
    NamedChar( "cup"w, 0x222A ),    // ∪
    NamedChar( "int"w, 0x222B ),    // ∫
    NamedChar( "there4"w, 0x2234 ),    // ∴
    NamedChar( "sim"w, 0x223C ),    // ∼
    NamedChar( "cong"w, 0x2245 ),    // ≅
    NamedChar( "asymp"w, 0x2248 ),    // ≈
    NamedChar( "ne"w, 0x2260 ),    // ≠
    NamedChar( "equiv"w, 0x2261 ),    // ≡
    NamedChar( "le"w, 0x2264 ),    // ≤
    NamedChar( "ge"w, 0x2265 ),    // ≥
    NamedChar( "sub"w, 0x2282 ),    // ⊂
    NamedChar( "sup"w, 0x2283 ),    // ⊃
    NamedChar( "nsub"w, 0x2284 ),    // ⊄
    NamedChar( "sube"w, 0x2286 ),    // ⊆
    NamedChar( "supe"w, 0x2287 ),    // ⊇
    NamedChar( "oplus"w, 0x2295 ),    // ⊕
    NamedChar( "otimes"w, 0x2297 ),    // ⊗
    NamedChar( "perp"w, 0x22A5 ),    // ⊥
    NamedChar( "sdot"w, 0x22C5 ),    // ⋅
    NamedChar( "lceil"w, 0x2308 ),    // ⌈
    NamedChar( "rceil"w, 0x2309 ),    // ⌉
    NamedChar( "lfloor"w, 0x230A ),    // ⌊
    NamedChar( "rfloor"w, 0x230B ),    // ⌋
    NamedChar( "lang"w, 0x2329 ),    // 〈
    NamedChar( "rang"w, 0x232A ),    // 〉
    NamedChar( "loz"w, 0x25CA ),    // ◊
    NamedChar( "spades"w, 0x2660 ),    // ♠
    NamedChar( "clubs"w, 0x2663 ),    // ♣
    NamedChar( "hearts"w, 0x2665 ),    // ♥
    NamedChar( "diams"w, 0x2666 ),    // ♦
];


dchar_t  MapNamedCharacter( const(wchar_t) * name )
{
    return  MapNamedCharacter( name, wcslen( name ) );
}

dchar_t MapNamedCharacter(wstring name){
	for ( int  i = 0; i < gChars.length; i++ )
    {
        if ( gChars[i].Name == name )
        {
            return  gChars[i].Code;
        }
    }

    return  0;
}

dchar_t  MapNamedCharacter( const(wchar_t) * name, size_t  len )
{
    for ( int  i = 0; i < gChars.length; i++ )
    {
        if ( wcsncmp( gChars[i].Name, name, len ) == 0 )
        {
            // they're the same up to our passed in length, 
            // now see if the name ends there or is longer
            if ( gChars[i].Name[len] == '\0' )
                return  gChars[i].Code;
        }
    }

    return  0;
}
