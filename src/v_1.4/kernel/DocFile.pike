#include <classes.h>
#include <database.h>
#include <macros.h>

//#define DOC_DEBUG

#ifdef DOC_DEBUG 
#define DEBUG_DOC(s) werror(s+"\n")
#else
#define DEBUG_DOC
#endif

static object    steamObject;
static object        oCaller;
static string         buffer; // read (ahead) buffer
static int          position; // read position
static int      doc_position; // position inside document
static mixed           fstat;
static function  contentRead; // read content from this function
static function contentWrite; // write content to this function
static string      sProtocol;

int error = 0;

void 
create(object document, void|string type, void|mapping vars, void|string prot)
{
    steamObject = document;
    oCaller = CALLER;
    buffer = "";
    position = 0;
    doc_position = 0;
    if ( !stringp(type) )
	type = "r";

    if ( search(type, "r") >= 0 && 
	 document->get_object_class() & CLASS_DOCUMENT ) 
    {
	if ( document->get_content_size() > 0 ) {
	    contentRead = document->get_content_callback(vars);
	    fill_buffer(65536);
	}
        fstat = document->stat();
    }
    else if ( search(type, "w") >= 0 ) {
      fstat = 0;
    }
    if ( !stringp(prot) )
      sProtocol = "ftp";
    else
      sProtocol = prot;
}

int is_file() { return 1; }

int write(string data)
{
    if ( !functionp(contentWrite) )
	contentWrite = steamObject->receive_content(0);

    contentWrite(data);
    return strlen(data);
}

void close()
{
    if ( functionp(contentWrite) )
	catch(contentWrite(0));
    contentWrite = 0;
    position = 0;
    contentRead = 0;
    doc_position = 0;
    destruct(this_object());
}

static int fill_buffer(int how_much)
{
    int buf_len = strlen(buffer);
    DEBUG_DOC("reading " + how_much + " bytes into buffer, previously "+
	      buf_len + " bytes.\n");
    while ( buf_len < how_much ) {
	string str = contentRead(doc_position);
	if ( !stringp(str) || strlen(str) == 0 )
	    return strlen(buffer);
	DEBUG_DOC("contentRead function returns " + strlen(str) + " bytes.\n");
	buffer += str;
	buf_len = strlen(buffer);
	doc_position += strlen(str);
    }
    return strlen(buffer);
}

void set_nonblocking() 
{
}

void set_blocking()
{
}

int _sizeof()
{
  // this should never happen: we already got more data
  // from the database than the documents content size ?!!
  if ( steamObject->get_content_size() < doc_position )
    return doc_position; // position inside the document

  return steamObject->get_content_size();
}

string read(void|int len, void|int not_all)
{
    if ( position == _sizeof() ) {
	position++;
	return "";
    }
    else if ( position > _sizeof() ) {
	return 0;
    }

    if ( !intp(len) ) {
	fill_buffer(steamObject->get_content_size());
	return buffer;
    }
    int _read = fill_buffer(len);
    string buf;
    if ( _read < len ) {
	buf = copy_value(buffer);
	buffer = "";
	position += _read;
	return buf;
    }
    buf =  buffer[..len-1];
    position += len;
    buffer = buffer[len..];
    fill_buffer(65536); // read ahead;
    return buf;
}

final mixed `->(string func)
{
    return this_object()[func];
}

Stdio.Stat stat() 
{ 
    mixed res = fstat;
    if ( !arrayp(res) )
      res = steamObject->stat();
    Stdio.Stat st = Stdio.Stat();
    st->atime = res[3];
    st->mtime = res[4];
    st->ctime = res[2];
    st->gid   = res[5];
    st->mode  = res[0];
    st->size  = res[1];
    st->uid   = res[6];
    return st;
}

string describe() 
{ 
    return "DocFile("+
	_FILEPATH->object_to_filename(steamObject) + 
	"," + _sizeof() + " bytes,"+
	", at " + position + ", ahead "+ doc_position + ")";
}
	
	
object get_creator() { return this_user(); }
string get_identifier() { return "Document-File"; }
object get_object_id() { return steamObject->get_object_id(); }
int get_object_class() { return steamObject->get_object_class(); }

object this() 
{ 
  if ( IS_SOCKET(oCaller) )
    return oCaller->get_user_object();
  return oCaller->this(); 
}
string get_client_class() { return sProtocol; } // for compatibility

