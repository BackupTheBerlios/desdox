inherit Slotter.Insert;
mapping(string:Slotter.Slot) alternatives= ([]);
string|function mControl;

void create(string|function sC)
{
    mControl = sC;
}

Slotter.Slot get_slot_to_state(string state)
{
    Slotter.Slot slot = Slotter.Slot();
    alternatives[state]= slot;
    werror(sprintf("getting slot (%O) to state \"%s\"\n", slot, state));
    return slot;
}

array list_alternatives() {
    array alt = ({});
    foreach (indices(alternatives), string alternative)
    {
        alt += ({ "<dl><dt>"+alternative+"</td><dd>" , alternative, "</dd></dl>" });
    }
    return alt;
}
        
array preview() {
    return ({ "Alternator"+
              "["+(stringp(mControl) ? mControl :
                        function_name(mControl)+"()")+"]" })+
        ({ "<ul>" }) + list_alternatives() + ({ "</ul>" });
}

array generate() {

    string val;
    if (stringp(mControl))
    {        
        object session = Session.get_user_session();
        val = session->get_global(mControl);
    }
    else
    {
        val = mControl();
    }
    
    return ({ alternatives[val]? alternatives[val]:
              (alternatives["@default"] ? alternatives["@default"] :
              "Variable ["+(stringp(mControl) ? mControl
                            : function_name(mControl))+
               "] state ["+val+"] not handled and no @default given") });
}
