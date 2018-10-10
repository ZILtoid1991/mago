module miutils;

public import logger;
public import core.sys.windows.windows;
public import core.stdc.stdlib;
public import core.stdc.string;
public import core.stdc.inttypes;
public import std.utf;
public import std.string;
public import std.format;
public import conv = std.conv;
public import windbg;

public import common.stringutil;

static enum DEBUG_LOCK_WAIT = true;
immutable uint64_t UNSPECIFIED_REQUEST_ID = 0xFFFFFFFFFFFFFFFEUL;


class Mutex {
	HANDLE _mutex;
public:
	this()
	{
		_mutex = CreateMutex(NULL, FALSE, NULL);
	}

	~this()
	{
		CloseHandle(_mutex);
	}

	void Lock()
	{
		WaitForSingleObject(
			_mutex,    // handle to mutex
			INFINITE);  // no time-out interval
	}

	void Unlock()
	{
		ReleaseMutex(_mutex);
	}
}

class TimeCheckedGuardedArea{
	Mutex  mGuard;
//#ifdef DEBUG_LOCK_WAIT
	static if(DEBUG_LOCK_WAIT){
		const char * lockName;
		uint64_t warnTimeout;
		uint64_t startWaitLock;
		uint64_t endWaitLock;
		uint64_t endLock;
	}
//#endif
public:
	this(Mutex guard, const char * name, uint64_t timeout = DEFAULT_GUARD_TIMEOUT){
		//UNREFERENCED_PARAMETER(timeout);
		//UNREFERENCED_PARAMETER(name);
//#ifdef DEBUG_LOCK_WAIT
		this.mGuard = guard;
		this.warnTimeout = timeout;
		static if(DEBUG_LOCK_WAIT){
			startWaitLock = GetCurrentTimeMillis();
			this.lockname = name;
		}
//#endif
		mGuard.Lock();
//#ifdef DEBUG_LOCK_WAIT
		static if(DEBUG_LOCK_WAIT){
			endWaitLock = GetCurrentTimeMillis();
			if (endWaitLock - startWaitLock > warnTimeout)
				CRLog.warn("Lock wait timeout exceeded for guard %s: %llu ms", lockName, endWaitLock - startWaitLock);
		}
//#endif
	}

	~this(){
		mGuard.Unlock();
//#ifdef DEBUG_LOCK_WAIT
		endLock = GetCurrentTimeMillis();
		if (endLock - endWaitLock > warnTimeout)
			CRLog.warn("Lock hold timeout exceeded for guard %s: %llu ms", lockName, endLock - endWaitLock);
//#endif
	}

private:
	TimeCheckedGuardedArea assign (ref TimeCheckedGuardedArea other) {
		//UNREFERENCED_PARAMETER(other);
		return this;
	}
}

class Buffer(T){
	private:
	T * _buf;
	int _size;
	int _len;
public:
	this(){

	}
	~this() {
		clear();
	}
	@nogc @property int length() const { return _len; }
	@nogc @property int size() const { return _size; }
	void reset() {
		_len = 0;
		if (_buf)
			_buf[_len] = 0;
	}
	void clear() {
		_len = 0;
		_size = 0;
		if (_buf) {
			free(_buf);
			_buf = null;
		}
	}
	T* ptr() { return _buf; }
	@nogc @property void reserve(int sz) {
		// ensure there is sz free items in buffer
		int newSize = _len + sz + 1;
		if (newSize > _size) {
			if (newSize < 64) {
				newSize = 64;
			} else {
				if (newSize < _size * 2)
					newSize = _size * 2;
			}
			_buf = cast(T*)realloc(_buf, newSize * T.sizeof);
			for (int i = _size; i < newSize; i++)
				_buf[i] = 0; // fill with zeroes
			_size = newSize;
		}
	}
	/// if length is greater than requested, remove extra items from end of buffer
	void truncate(int newLength) {
		if (newLength >= 0 && _len > newLength) {
			_len = newLength;
			if (_buf)
				_buf[_len] = 0;
		}
	}
	void append(T item) {
		reserve(1);
		_buf[_len++] = item;
		_buf[_len] = 0; // trailing zero, just in case
	}
	Buffer(T) opOpAssign(S)(T item){
		static if(S == "+="){
			append(item);
			return this;
		}else static assert(false, "Operator " ~ S ~ " not supported!");
	}
	/*Buffer(T)& operator += (T item) {
		append(item);
		return *this;
	}*/
	Buffer(T) opOpAssign(S)(const ref Buffer(T) items){
		static if(S == "+="){
			append(items.c_str(), items.length());
			return this;
		}else static assert(false, "Operator " ~ S ~ " not supported!");
	}
	/*Buffer(T)& operator += (const Buffer & items) {
		append(items.c_str(), items.length());
		return *this;
	}*/
	/// append z-string
	Buffer(T) opOpAssign(S)(const T* items){
		static if(S == "+="){
			append(items);
			return this;
		}else static assert(false, "Operator " ~ S ~ " not supported!");
	}
	/*Buffer(T)& operator += (const T* items) {
		append(items);
		return *this;
	}*/
	/// append several items
	void append(const T* items, size_t count) {
		if (count <= 0 || !items)
			return;
		reserve(count);
		for (unsigned i = 0; i < count; i++) {
			_buf[_len + i] = items[i];
		}
		_len += count;
		_buf[_len] = 0; // trailing zero, just in case
	}
	void append(const T* s) {
		/*int len = 0;
		for (; s[len]; len++)
			;*/
		append(s, 0);
	}
	/// replace item
	void replace(T replaceWhat, T replaceWith) {
		for (int i = 0; i < _len; i++)
			if (_buf[i] == replaceWhat)
				_buf[i] = replaceWith;
	}
	void assign(const T * s, size_t count) {
		reset();
		append(s, count);
	}
	void assign(const T * s) {
		reset();
		append(s);
	}
	/// return item by index, or 0 if index out of bounds
	T opIndex(int index) { return (index >= 0 && index < _len) ? _buf[index] : 0; }
	const T * c_str() const {
		return _buf;
	}
	bool empty() const { return _length == 0; }
	bool isNull() const { return !_buf; }
	/// returns last item
	T last() const { return (_len > 0) ? _buf[_len - 1] : 0; }
	/// return true if last item equals to specified one
	bool endsWith(T item) const {
		return (last() == item);
	}
	void trimEol() {
		while (last() == '\n' || last() == '\r')
			truncate(_len - 1);
	}
	void appendIfLastItemNotEqual(T itemToAppend, T lastItemNotEqual) {
		if (last() != lastItemNotEqual)
			append(itemToAppend);
	}
	void appendIfLastItemNotEqual(const T * zitemsToAppend, T lastItemNotEqual) {
		if (last() != lastItemNotEqual)
			append(zitemsToAppend);
	}
}
/+/**
 * Creates a D string from a C/C++ null terminated string.
 */
wstring fromWStringz(wchar* ptr){
	wstring output;
	while(*ptr){
		output ~= *ptr;
		ptr++;
	}
	return output;
}

wchar* toWStringz(wstring str){
	wchar* output = cast(wchar*)malloc((str.length + 1)* wchar.length);
	for(int i ; i < str.length ; i++){
		output[i] = str[i];
	}
	output[str.length] = '\x00';
	return output;
}+/

class StringBuffer : Buffer!(char){
	this(){
		super();
	}
	~this(){
		clear;
	}
	StringBuffer assign(const string s) { 
		assign(toStringz(s), s.length()); 
		return this; 
	}
	/*StringBuffer operator += (char ch) { 
		append(ch); 
		return this; 
	}*/
	string str() { 
		return ptr[0 .. length]; 
	}
	wstring wstr() { 
		return toUTF16(str()); 
	}
}

class WstringBuffer : Buffer!(wchar) {
	this(){
		super();
	}
	~this(){
		clear;
	}
	WstringBuffer pad(wchar_t ch, int len){
		while (length() < len)
			append(ch);
		return *this;
	}
	WstringBuffer assign (const wstring s) { 
		assign(s.ptr, s.length); 
		return *this; 
	}
	WstringBuffer opOpAssign(S)(const wstring s) { 
		static if(S == "+="){
			append(s.c_str(), s.length()); 
			return *this; 
		}
	}
	/*WstringBuffer operator += (wchar_t ch) { 
		append(ch); 
		return *this; 
	}*/
	WstringBuffer appendUtf8(const char * s){
		while (s && s[0]) {
		append(s[0]);
		s++;
		}
		return this;
	}
	string str() { 
		return toUtf8(wstr()); 
	}
	wstring wstr() { 
		return c_str()[0 .. length()]; 
	}
	// appends double quoted string, e.g. "Some message.\n"
	WstringBuffer appendStringLiteral(wstring s){
		append('\"');
		for (size_t i = 0; i < s.length(); i++) {
			wchar_t ch = s[i];
			switch (ch) {
			case '\\':
				append("\\\\"w);
				break;
			case '\"':
				append("\\\""w);
				break;
			case '\n':
				append("\\n"w);
				break;
			case '\t':
				append("\\t"w);
				break;
			case '\r':
				append("\\r"w);
				break;
			case '\0':
				append("\\0"w);
				break;
			default:
				append(ch);
				break;
			}
		}
		append('\"');
		return *this;
	}
	// appends number
	WstringBuffer appendUlongLiteral(uint64_t n){
		//wchar buf[32];
		//wsprintf(buf, L"%I64d", n);
		wstring buf = format("%I64d"w, n);
		foreach(c ; buf)
			append(c);
		return *this;
	}
	// appends number if non zero
	WstringBuffer appendUlongIfNonEmpty(uint64_t n) { 
		if (n != UNSPECIFIED_REQUEST_ID) appendUlongLiteral(n); 
		return this; 
	}
	WstringBuffer appendUlongParam(const wchar_t * paramName, uint64_t value, wchar_t appendCommaIfNotThisChar = '{') {
		if (last() != appendCommaIfNotThisChar)
			append(',');
		append(paramName);
		append('=');
		appendUlongLiteral(value);
		return this;
	}
	WstringBuffer appendUlongParamAsString(const wchar_t * paramName, uint64_t value, wchar_t appendCommaIfNotThisChar = '{') {
		if (last() != appendCommaIfNotThisChar)
			append(',');
		append(paramName);
		append('=');
		appendStringLiteral(to_wstring(value));
		return this;
	}
	WstringBuffer appendStringParam(const wchar_t * paramName, wstring value, wchar_t appendCommaIfNotThisChar = '{') {
		if (last() != appendCommaIfNotThisChar)
			append(',');
		append(paramName);
		append('=');
		appendStringLiteral(value);
		return *this;
	}
	WstringBuffer appendStringParamIfNonEmpty(const wchar_t * paramName, wstring value, wchar_t appendCommaIfNotThisChar = '{') {
		if (!value.empty())
			appendStringParam(paramName, value, appendCommaIfNotThisChar);
		return *this;
	}
	/// append command line parameter, quote if if needed
	WstringBuffer appendCommandLineParameter(wstring s){
		if (s.empty())
		return *this;
		if (last() != 0 && last() != ' ')
			append(" "w);
		bool needQuotes = false;
		for (unsigned i = 0; i < s.length(); i++)
			if (s[i] == ' ')
				needQuotes = true;
		if (needQuotes)
			append("\""w);
		for (unsigned i = 0; i < s.length(); i++) {
			wchar_t ch = s[i];
			if (ch == '\"')
				append("\""w);
			else if (ch == '\n')
				append("\\n"w);
			else
				append(ch);
		}
		if (needQuotes)
			append("\""w);
		return *this;
	}
}

bool isValidIdentChar(wchar_t ch) {
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch == '_') || (ch == '-');
}

wstring processQuotedChars(wstring s) {
	WstringBuffer buf;
	for (unsigned i = 0; i < s.length(); i++) {
		wchar_t ch = s[i];
		wchar_t nextch = i + 1 < s.length() ? s[i + 1] : 0;
		if (ch == '\\' && nextch == '\\') {
			buf.append('\\');
			i++;
		}
		else if (ch == '\\' && nextch == 't') {
			buf.append('\\');
			i++;
		}
		else {
			buf.append(ch);
		}
	}
	return buf.wstr();
}

// various parsing utility functions

/// trying to parse beginning of string as unsigned long; if found sequence of digits, trims beginning digits from s, puts parsed number into n, and returns true.
bool parseUlong(ref wstring s, ref ulong value){
	if (s.empty())
		return false;
	ulong n;
	size_t i;
	for (; i < s.length() && s[i] >= '0' && s[i] <= '9'; i++)
		n = n * 10 + cast(uint)(s[i] - '0');
	if (i == 0)
		return false;
	value = n;
	s = s.substr(i, s.length() - i);
	return true;
}
/// parse whole string as ulong, return false if failed
bool toUlong(wstring s, ref ulong value){
	if (!parseUlong(s, value))
		return false;
	return s.empty();
}
/// convert number to string
wstring toWstring(ulong n){
	WstringBuffer buf;
	buf.appendUlongLiteral(n);
	return buf.wstr();
}
/// parse beginning of string as identifier, allowed chars: a..z, A..Z, _, - (if successful, removes ident from s and puts it to value, and returns true)
bool parseIdentifier(ref wstring s, ref wstring value){
	if (s.empty())
		return false;
	size_t i;
	bool foundLetters;
	for (; i < s.length() && isValidIdentChar(s[i]); i++) {
		if (s[i] != '-' && s[i] != '_')
			foundLetters = true;
	}
	if (!i || !foundLetters)
		return false;
	value = s.substr(0, i);
	s = s.substr(i, s.length() - i);
	return true;
}
/// trim spaces and tabs from beginning of string
void skipWhiteSpace(ref wstring s){
	size_t i;
	for (; i < s.length() && (s[i] == ' ' || s[i] == '\t'); i++) {
	}
	if (i > 0) {
		if (i < s.length())
			s = s.substr(i, s.length() - i);
		else
			s = 0;
	}
}
/// split space separated parameters (properly handling spaces inside "double quotes")
void splitSpaceSeparatedParams(wstring s, ref wstring[] items){
	size_t start;
	size_t i;
	bool insideStringLiteral;
	for (; i < s.length(); i++) {
		wchar ch = s[i];
		wchar nextch = i + 1 < s.length() ? s[i + 1] : 0;
		if ((ch == ' ' || ch == '\t') && !insideStringLiteral) {
			if (i > start)
				items.push_back(processQuotedChars(s.substr(start, i - start)));
			start = i + 1;
		}
		else if (ch == '\"') {
			insideStringLiteral = !insideStringLiteral;
		}
		else if (insideStringLiteral && ch == '\\' && nextch == '\"') {
			i++;
		}
		else if (ch == '\\' && nextch == '\\') {
			// convert double backslashes to single backslashes (CDT support)
			i++;
		}
	}
	if (i > start)
		items.push_back(processQuotedChars(s.substr(start, i - start)));
}
/// returns true if string is like -v -pvalue
bool isShortParamName(ref wstring s){
	return s.length() > 1 && s[0] == '-' && s[1] != '-' && isValidIdentChar(s[1]);
}
/// returns true if string is like --param --param=value
bool isLongParamName(ref wstring s){
	return s.length() > 2 && s[0] == '-' && s[1] == '-' && s[2] != '-' && isValidIdentChar(s[2]);
}
/// returns true if string is like -v -pvalue --param --param=value
bool isParamName(ref wstring s){
	return isShortParamName(s) || isLongParamName(s);
}
/// split line into two parts (before,after) by specified character, returns true if character is found, otherwise s will be placed into before
bool splitByChar(ref wstring s, wchar_t ch, ref wstring before, ref wstring after){
	for (size_t i = 0; i < s.length; i++) {
		if (s[i] == ch) {
			if (i > 0)
				before = s[0 .. i];
			else
				before.length = 0;
			if (i + 1 < s.length)
				after = s[i + 1 .. s.length() - i - 1];//???
			else
				after.length = 0;
			return true;
		}
	}
	before = s;
	after.length = 0;
	return false;
}
/// split line into two parts (before,after) by specified character (search from end of string), returns true if character is found, otherwise s will be placed into before
bool splitByCharRev(ref wstring s, wchar_t ch, ref wstring before, ref wstring after){
	for (int i = cast(int)s.length - 1; i >= 0; i--) {
		if (s[i] == ch) {
			if (i > 0)
				before = s[0 .. i];
			else
				before.length = 0;
			if (i + 1 < cast(int)s.length)
				after = s[i + 1 .. s.length - i - 1];
			else
				after.length = 0;
			return true;
		}
	}
	before = s;
	after.length = 0;
	return false;
}

bool endsWith(ref const wstring value, ref const wstring ending){
	if (ending.length > value.length) 
		return false;
	return equal(ending.rbegin(), ending.rend(), value.rbegin());
}

class RefCountedBase {
private:
	int refCount;
public:
	this() {

	}
	~this() {

	}
	void AddRef() {
		refCount++;
	}
	void Release() {
		if (--refCount <= 0)
			this.destroy();
	}
};

static const wchar*[] sourceFileExtensions = [
	".d"w,
	".di"w,
	".h"w,
	".c"w,
	".cpp"w,
	".hpp"w,
	NULL
];

/// returns true if s is most likely file name
bool looksLikeFileName(wstring s) {
	for (unsigned i = 0; sourceFileExtensions[i]; i++)
		if (endsWith(s, wstring(sourceFileExtensions[i])))
			return true;
	for (unsigned i = 0; i < s.length(); i++) {
		if (s[i] == '/' || s[i] == '\\')
			return true;
	}
	return false;
}


//struct IDebugPendingBreakpoint2;
class BreakpointInfo : RefCountedBase {
private:
	IDebugPendingBreakpoint2* _pendingBreakpoint;
	IDebugBoundBreakpoint2* _boundBreakpoint;
public:
	uint64_t id;
	uint64_t requestId;
	wstring insertCommandText;
	wstring address;
	wstring functionName;
	wstring fileName;
	wstring labelName;
	wstring moduleName;
	wstring originalLocation;
	int line;
	int boundLine;
	int times;
	bool enabled;
	bool pending;
	bool temporary;
	bool bound;
	bool error;
	wstring errorMessage;
	this(){

	}
	~this(){
		/*if (_pendingBreakpoint)
			_pendingBreakpoint.destroy;
		if (_boundBreakpoint)
			_boundBreakpoint.destroy;*/
	}

	ulong assignId(){
		id = nextBreakpointId++;
		return id;
	}

	BreakpointInfo assign (const BreakpointInfo v){
		id = v.id;
		requestId = v.requestId;
		address = (v.address);
		functionName = (v.functionName);
		fileName = (v.fileName);
		labelName = (v.labelName);
		line = v.line;
		enabled = v.enabled;
		pending = v.pending;
		temporary = v.temporary;
		return this;
	}
	bool fromCommand(MICommand cmd){
		insertCommandText = cmd.tail; // commandText;
		// try named params
		for (size_t i = 0; i < cmd.namedParams.size(); i++) {
			wstring name = cmd.namedParams[i].first;
			wstring value = cmd.namedParams[i].second;
			if (name == "--source"w)
				fileName = value;
			else if (name == "--function"w)
				functionName = value;
			else if (name == "--label"w)
				labelName = value;
			else if (name == "--line"w) {
				uint64_t n = 0;
				if (parseUlong(value, n) && value.empty())
					line = cast(int)n;
			} else if (name == "-t"w) // temporary
				temporary = true;
			else if (name == "-f"w)
				pending = true; // create pending if location is not found
			else if (name == "-d"w)
				enabled = false; // create disabled
		}
		// try unnamed params
		for (size_t i = 0; i < cmd.unnamedValues.size(); i++) {
			wstring value = cmd.unnamedValues[i];
			uint64_t n = 0;
			wstring tmp = value;
			if (parseUlong(tmp, n) && tmp.empty()) {
				// it was just a line number
				line = cast(int)n;
			}
			else {
				wstring part1, part2;
				if (splitByCharRev(value, ':', part1, part2)) {
					// there was : char
					tmp = part2;
					if (parseUlong(tmp, n) && tmp.empty()) {
						// there was a number after :
						// filename:line
						fileName = part1;
						line = cast(int)n;
					}
					else {
						// filename:function or filename:label
						if (looksLikeFileName(part1)) {
							fileName = part1;
							functionName = part2;
						}
						else {
							functionName = part1;
							labelName = part2;
						}
					}
				}
				else {
					functionName = value;
				}

			}

		}

		if (!fileName.empty() && line)
			originalLocation = fileName + ":"w + toWstring(line);
		return validateParameters();
	}
	bool validateParameters(){
		if (!fileName.empty() && line) // file:line
			return true;
		// only file:line breakpoint is supported by Mago
		//if (!functionName.empty()) // function or file:function
		//	return true;
		return false;
	}
	/// debug dump
	wstring dumpParams(){
		WstringBuffer buf;
		buf.append("BreakpointInfo {"w);
		buf.appendStringParamIfNonEmpty("fileName"w, fileName);
		buf.appendStringParamIfNonEmpty("functionName"w, functionName);
		buf.appendStringParamIfNonEmpty("labelName"w, labelName);
		buf.appendStringParamIfNonEmpty("address"w, address);
		if (line)
			buf.appendUlongParam("line"w, line);
		buf.append("}"w);
		return buf.wstr();
	}
	/// print mi2 breakpoint info
	void printBreakpointInfo(WstringBuffer buf){
		buf.append("{"w);
		buf.appendUlongParamAsString("number"w, id);
		buf.appendStringParam("type"w, "breakpoint"w);
		buf.appendStringParam("disp"w, temporary ? "del"w : "keep"w);
		buf.appendStringParam("enabled"w, enabled ? "y"w : "n"w);
		buf.appendStringParamIfNonEmpty("addr"w, (pending && address.empty()) ? "<PENDING>"w : address);
		buf.appendStringParamIfNonEmpty("func"w, functionName);
		buf.appendStringParamIfNonEmpty("file"w, getBaseName(fileName));
		buf.appendStringParamIfNonEmpty("fullname"w, fileName);
		if (boundLine || line)
			buf.appendUlongParamAsString("line"w, boundLine ? boundLine : line);
		if (pending)
			buf.appendStringParam("pending"w, insertCommandText);
		buf.append(",thread-groups=[\"i1\"]"w);
		//if (times)
			buf.appendUlongParamAsString("times"w, times);
		buf.appendStringParamIfNonEmpty("original-location"w, originalLocation);
		//buf.appendStringParam(L"thread-groups", std::wstring(L"breakpoint"));
		buf.append("}"w);
	}
	/// request binding, return true if request is sent ok
	bool bind(){

	}

	void setPending(IDebugPendingBreakpoint2 pPendingBp){
		_pendingBreakpoint = pPendingBp;
	}
	void setBound(IDebugBoundBreakpoint2 pBoundBp){
		_boundBreakpoint = pBoundBp;
		pending = false;
		bound = true;
	}
	void setBindError(){
		error = true;
	}
	@property IDebugPendingBreakpoint2 getPendingBreakpoint() { 
		return _pendingBreakpoint; 
	}
	@property IDebugBoundBreakpoint2 getBoundBreakpoint() { 
		return _boundBreakpoint; 
	}

}
class BreakpointInfoList{
	BreakpointInfo[] list;
	this() {

	}
	~this() {

	}
	BreakpointInfoRef findById(uint64_t id){
		for (size_t i = 0; i < list.length; i++)
			if (list[i].id == id)
				return at(i);
		return BreakpointInfoRef();
	}
	BreakpointInfoRef findByPendingBreakpoint(IDebugPendingBreakpoint2 * bp){
		for (size_t i = 0; i < size(); i++)
			if (list[i].getPendingBreakpoint() == bp)
				return at(i);
		return BreakpointInfoRef();
	}
	BreakpointInfoRef findByBoundBreakpoint(IDebugBoundBreakpoint2 * bp){
		for (size_t i = 0; i < size(); i++)
			if (list[i].getBoundBreakpoint() == bp)
				return at(i);
		return BreakpointInfoRef();
	}
	bool addItem(BreakpointInfo bp) { 
		push_back(bp); 
		return true;  
	}
	bool removeItem(BreakpointInfo bp){
		for (size_t i = 0; i < size(); i++)
			if (at(i).Get() == bp.Get()) {
				BreakpointInfoRef found = at(i);
				erase(begin() + i);
				return true;
			}
		return false;
	}
}

static uint64_t nextBreakpointId = 1;

bool fileExists(wstring fname){
	HANDLE h = CreateFileW(fname.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (h == INVALID_HANDLE_VALUE)
		return false;
	CloseHandle(h);
	return true;
}
wstring unquoteString(wstring s){
	if (s.empty())
		return s;
	if (s[0] == '\"') {
		if (s.length() > 1 && s[s.length() - 1] == '\"')
			return s.substr(1, s.length() - 2);
		return s.substr(1, s.length() - 1);
	}
	return s;
}
wstring quoteString(wstring s){
	if (s.empty())
		return "\"\""w;
	WstringBuffer buf;
	buf.appendStringLiteral(s);
	return buf.wstr();
}
wstring fixPathDelimiters(wstring s){
	WstringBuffer buf;
	for (unsigned i = 0; i < s.length(); i++) {
		wchar_t ch = s[i];
		if (ch == '/')
			ch = '\\';
		buf.append(ch);
	}
	return buf.wstr();
}
wstring relativeToAbsolutePath(wstring s){
	WstringBuffer buf;
	if (isAbsolutePath(s)) {
		buf += s;
	} else {
		buf = getCurrentDirectory();
		if (buf.last() != '\\')
			buf += '\\';
		buf += s;
	}
	buf.replace('/', '\\');
	return buf.wstr();
}
bool isAbsolutePath(wstring s){
	if (s.empty())
		return false;
	if (s[0] && s[1] == ':' && s[2] == '\\')
		return true;
	if (s[0] == '\\' && s[1] == '\\')
		return true;
	if (s[0] == '\\' || s[0] == '/')
		return true;
	return false;
}
wstring getCurrentDirectory(){
	wchar_t buf[4096];
	GetCurrentDirectoryW(4095, buf);
	return buf[0..$];
}
/// get base name for file name, e.g. for "/dir/subdir/file.ext" return "file.ext"
wstring getBaseName(wstring fname){
	if (fname.empty())
		return fname;
	int i = (cast(int)fname.length()) - 1;
	for (; i >= 0; i--) {
		if (fname[i] == '/' || fname[i] == '\\')
			return fname.substr(i + 1, fname.length() - i - 1);
	}
	return fname;
}
/// get directory name for file, e.g. for "/dir/subdir/file.ext" return "/dir/subdir"
wstring getDirName(wstring fname){
	if (fname.empty())
		return fname;
	int i = (cast(int)fname.length()) - 1;
	for (; i >= 0; i--) {
		if (fname[i] == '/' || fname[i] == '\\')
			return i > 0 ? fname.substr(0, i) : "";
	}
	return fname;
}

void testEngine();


enum LocalVariableKind {
	VAR_KIND_UNKNOWN, // unknown type
	VAR_KIND_THIS, // this pointer
	VAR_KIND_ARG, // function argument
	VAR_KIND_LOCAL, // stack variable
}
/**
 * ORIGINAL COMMENT
 * helper function converts BSTR string to std::wstring and frees original string
 * END OF ORIGINAL COMMENT
 */
wstring fromBSTR(BSTR bstr){
	if (!bstr)
		return wstring;
	wstring res = bstr;
	SysFreeString(bstr);
	bstr = null;
	return res;
}

class LocalVariableInfo : RefCountedBase {
private:
public:
	LocalVariableKind varKind;
	wstring varFullName;
	wstring varName;
	wstring varType;
	wstring varValue;
	bool expandable;
	bool readonly;
	void dumpMiVariable(WstringBuffer buf, bool includeTypes, bool includeValues, bool fullSyntax){
		if (!includeTypes && !includeValues && !fullSyntax) {
			//if (buf.last() != '[')
			buf.appendStringLiteral(varName);
		}
		else {
			buf.append("{"w);
			buf.appendStringParam("name"w, varName);
			if (includeTypes)
				buf.appendStringParam("type"w, varType);
			if (includeValues)
				buf.appendStringParam("value"w, varValue);
			buf.append("}"w);
		}
	}
	this(){
		varKind = LocalVariableKind.VAR_KIND_UNKNOWN;
	}
	~this() {

	}
}

alias LocalVariableList = LocalVariableInfo[];

struct StackFrameInfo {
	DWORD threadId;
	int frameIndex;
	wstring address;
	wstring moduleName;
	wstring functionName;
	wstring sourceFileName;
	wstring sourceBaseName;
	int sourceLine;
	int sourceColumn;
	LocalVariableList args;
	
	void dumpMIFrame(WstringBuffer buf, bool showLevel = false){
		buf.append('{');
		if (showLevel) {
			buf.appendUlongParamAsString("level"w, frameIndex);
		}
		buf.appendStringParamIfNonEmpty("addr"w, address, '{');
		if (!functionName.empty()) {
			buf.appendStringParamIfNonEmpty("func"w, functionName, '{');
			buf.append(",args=[]"w); //{name="a",value="5"}
			//buf.appendStringParamIfNonEmpty("args", wstring("[]"w), '{'); // TODO
		}
		buf.appendStringParamIfNonEmpty("file"w, sourceBaseName, '{');
		buf.appendStringParamIfNonEmpty("fullname"w, sourceFileName, '{');
		if (sourceLine != 0)
			buf.appendUlongParamAsString("line"w, sourceLine, '{');
		buf.appendStringParamIfNonEmpty("from"w, moduleName, '{');
		buf.append('}');
	}
}

alias StackFrameInfoVector = StackFrameInfo[];

class VariableObject : RefCountedBase {
private:
public:
	wstring name;
	wstring frame;
	wstring expr;
	wstring type;
	wstring value;
	bool inScope;
	this(){
		inScope = true;
	}
	~this() {

	}
	void dumpVariableInfo(WstringBuffer buf, bool forUpdate){
		buf.appendStringParam("name"w, name);
		buf.appendStringParam("type"w, type);
		buf.appendStringParam("value"w, value);
		buf.appendStringParam("numchild"w, "0"w);
		if (forUpdate) {
			buf.appendStringParam("in_scope"w, inScope ? "true"w : "false"w);
			buf.appendStringParam("type_changed", "false"w);
		}
	}
}

class VariableObjectList{
	private VariableObject[] list;
	this(){

	}
	~this(){

	}
	VariableObjectRef find(wstring frameAddress, wstring expr, int * pvarIndex = null){
		for (uint i = 0; i < size(); i++) {
			if (at(i).frame == frameAddress && at(i).expr == expr) {
				if (pvarIndex)
					*pvarIndex = cast(int)i;
				return at(i);
			}
		}
		if (pvarIndex)
			*pvarIndex = -1;
		return VariableObjectRef();
	}
	VariableObjectRef find(wstring name, int* pvarIndex = null){
		for (uint i = 0; i < size(); i++) {
			if (at(i).name == name) {
				if (pvarIndex)
					*pvarIndex = cast(int)i;
				return at(i);
			}
		}
		if (pvarIndex)
			*pvarIndex = -1;
		return VariableObjectRef();
	}
}
/**
 * Creates a D string from a C/C++ null terminated string.
 */
wstring fromWStringz(wchar* ptr)
{
    wstring output;
    while (*ptr)
    {
        output ~= *ptr;
        ptr++;
    }
    return output;
}
immutable(wchar)* toWStringz(const wchar[] str) @trusted pure nothrow
{
    out (result)
    {
        import core.stdc.string : strlen, memcmp;

        if (result)
        {
            auto slen = s.length;
            while (slen > 0 && s[slen - 1] == 0)
                --slen;
            assert(strlen(result) == slen);
            assert(result[0 .. slen] == s[0 .. slen]);
        }
    }
    do
    {
        import std.exception : assumeUnique;

        /+ Unfortunately, this isn't reliable.
     We could make this work if string literals are put
     in read-only memory and we test if s[] is pointing into
     that.
     /* Peek past end of s[], if it's 0, no conversion necessary.
     * Note that the compiler will put a 0 past the end of static
     * strings, and the storage allocator will put a 0 past the end
     * of newly allocated char[]'s.
     */
     char* p = &s[0] + s.length;
     if (*p == 0)
     return s;
     +/

        // Need to make a copy
        auto copy = new char[s.length + 1];
        copy[0 .. s.length] = s[];
        copy[s.length] = 0;

        return  & assumeUnique(copy)[0];
    }
}


/++ Ditto +/
immutable(wchar)* toStringz(return scope wstring s) @trusted pure nothrow
{
    if (s.empty) return "".ptr;
    /* Peek past end of s[], if it's 0, no conversion necessary.
     * Note that the compiler will put a 0 past the end of static
     * strings, and the storage allocator will put a 0 past the end
     * of newly allocated char[]'s.
     */
    immutable p = s.ptr + s.length;
    // Is p dereferenceable? A simple test: if the p points to an
    // address multiple of 4, then conservatively assume the pointer
    // might be pointing to a new block of memory, which might be
    // unreadable. Otherwise, it's definitely pointing to valid
    // memory.
    if ((cast(size_t) p & 3) && *p == 0)
        return &s[0];
    return toStringz(cast(const char[]) s);
}