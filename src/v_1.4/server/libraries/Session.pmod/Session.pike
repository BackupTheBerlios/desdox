/**
 * sTeam Session support
 *
 */
mapping(Slotter.Insert:mixed) Storage = ([]);
mapping(string:mixed)         Global= ([]);
private int                   iSID;
object composer;
mapping(Slotter.Insert:string) mInsert2IDs = ([]);
mapping(string:Slotter.Insert) mIDs2Insert= ([]);

private mapping(function:array) mCallbacks = ([]);

void create(int sid)
{
    iSID = sid;
}

int get_SID() { return iSID; }

void set_local(Slotter.Insert namespace, string name, mixed value)
{
    mapping InsertLocal = Storage[namespace];

    if (!mappingp(InsertLocal))
        InsertLocal = ([]);

    InsertLocal[name]=value;
    Storage[namespace] = InsertLocal;
}

mixed get_local(Slotter.Insert namespace, string name)
{
    mapping InsertLocal = Storage[namespace];

    if (!mappingp(InsertLocal))
        return 0;

    return InsertLocal[name];
}

/**
 * set and thus declare a globa variable to exist in this session
 * @param name  - global name of the variable
 * @param value - the value to store
 * @author Ludger Merkens
 */
void set_global(string name, mixed value)
{
    Global[name]=value;
}

/**
 * define a global variable by setting it to 0 in case there was
 * no index with this name yet, this never changes a value
 * @param string name - name of the global variable to set.
 * @author Ludger Merkens
 */

void define_global(string name)
{
    if (zero_type(Global[name]))
        Global[name]=0;
}

mixed get_global(string name)
{
    return Global[name];
}

mixed get_global_vars()
{
    return copy_value(Global);
}

/**
 * read a vars mapping as passed to instances of "Script.pike" and filter
 * all variables known in this session and store them accordingly.
 *
 * @param mapping vars - the variables mapping as passed to a webscript
 * @returns nothing
 *
 * @author Ludger Merkens
 */ 
void store_global_params(mapping vars)
{
    foreach(indices(Global), string sVarIndex)
    {
        if (!zero_type(vars[sVarIndex]))
            Global[sVarIndex] = vars[sVarIndex];
    }
}

void set_composer(object oComposer)
{
    composer = oComposer;
}

object get_composer()
{
    return composer;
}

string callSession()
{
    return composer->callName()+(composer->get_environment() ? "?" : "&")+
        "sid="+(string)iSID;
}

/**
 * calculate a sessionwide unique insert-id, the according insert can
 * be retrieved later by get_insert_by_id()
 */
string get_id_to_insert(Slotter.Insert insert)
{
    string res = mInsert2IDs[insert];
    if (stringp(res))
        return res;
    else
    {
        werror(sprintf("mIDs2Insert: %O\n", mInsert2IDs));
        res = (string) sizeof(indices(mIDs2Insert))+1;
        mInsert2IDs[insert] = res;
        mIDs2Insert[res]=insert;
        return res;
    }
}

Slotter.Insert get_insert_by_id(string sInsertID)
{
    return mIDs2Insert[sInsertID];
}


/**
 * generate a name to a given function, that will allow to
 * call it via a post in a html form.
 *
 * @param function callback
 */
string get_callback_name(function callback)
{
    if (!functionp(callback))
        return "no-function";
    
    return get_id_to_insert(function_object(callback))+
        "@"+function_name(callback);
}

/**
 * define which parameters a function takes to be executed
 *
 * @param function f  -  the callback function to call
 * @param array(string) args - the array describing the args
 */
void define_callback(function f, void|array(string) args)
{
    mCallbacks[ f ]  =  args;
}


array get_callback_details(function callback)
{
    return mCallbacks[callback];
}


/**
 * call a local function in one of the inserts. the callbackname consists
 * of the get_path_slot_name() of the Slot the insert is currently in
 * appended with "@" and the local name of the callback in the insert
 * @param string - callbackname : the callbackname as passed to the
 *                                x variable (eXecute)
 * @param mixed  - webvars      : all parameters as passed to
 *                                /classes/Scripts.execute()
 * @see Slotter.Insert.call_back_name()
 * @returns the result of the callback
 *
 * @author Ludger Merkens
 */
mixed call_slot_callback(string callbackname, mixed webvars)
{
    string sSlot;
    string sCB;
    array aCBdata;

    function f;
    array(string) args;

    werror("call_slot_callback\n");
    if (sscanf(callbackname, "%s@%s", sSlot, sCB)!=2)
        throw(({"Illegal Callbackname", backtrace()}));

    //    werror(sprintf("known slots are %O\n",allSlots));
    Slotter.Insert oCBHandler = get_insert_by_id(sSlot);

    function callback = oCBHandler[sCB];
    
    werror(sprintf("insert found is %O\n", oCBHandler));
    aCBdata = mCallbacks[callback];

    werror(sprintf("callback_details are %O\n", aCBdata));
    if (!arrayp(aCBdata))
        throw(({sprintf("Failed to find callbackdata for %s", callbackname),
                backtrace()}));

    args = aCBdata;

    array values = allocate(sizeof(args));
    for (int i=0;i<sizeof(args);i++)
    {
        if (args[i][0]=='@')
        {
            mapping res = webvars -
                filter(indices(webvars),
                       lambda(string p) {
                           if (p[..strlen(args[i])-2] !=
                               args[i][1..]) return p;
                       });
            values[i]= ({ args[i][1..], res });
        }
        else
            values[i]=webvars[args[i]];
    }
    werror(sprintf("Call SlotCallback %O with %O\n", callback, values));
    return callback(@values);

}

