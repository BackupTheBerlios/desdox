inherit Slotter.Insert;

mapping(string:string) mHiddenVars = ([]);
function fFormCB;
private Slotter.Slot inner;

void set_form_callback(function f)
{
    fFormCB =f;
}

void set_hidden(string name, string value)
{
    mHiddenVars [name]=value;
}

Slotter.Slot get_inner()
{
    if (!objectp(inner))
        inner=Slotter.Slot();
    return inner;
}

array generate() {

    object oSession = Session.get_user_session();
    object oComposer = oSession->get_composer();
    
    string out = "<form action=\""+
        oComposer->callName()+"\" method=\"post\">\n";
    
    foreach(indices(mHiddenVars), string name)
        out += "  <input type=\"hidden\" name=\""+name+"\" value=\""+
            mHiddenVars[name]+"\"/>\n";
    
    out += "  <input type=\"hidden\" name=\"x\" value=\""+
        oSession->get_callback_name(fFormCB)+"\"/>\n";
    out += "  <input type=\"hidden\" name=\"sid\" value=\""+
        oSession->get_SID()+"\"/>\n";
    
    return ({ out, inner, "\n</form>\n"});
}

array preview() {
    return ({ "basic form:<br/>", inner });
}
