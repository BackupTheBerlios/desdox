inherit Slotter.Inserts.Dispatcher;

string al, ab, ar;
int alw, ah, arw;
string astyle;
string il, ib, ir;
int ilw, ih, irw;
string istyle;

string sGlobalVar;

void set_active_icons(string left, int lw,
                 string back, int h,
                 string right, int rw)
{
    al = left; alw=lw;
    ab = back; ah=h;
    ar = right; arw=rw;
}

void set_inactive_icons(string left, int lw,
                   string back, int h,
                   string right, int rw)
{
    il = left; ilw=lw;
    ib = back; ih=h;
    ir = right; irw=rw;
}

void set_active_style(string style)
{
    astyle=style;
}

void set_inactive_style(string style)
{
    istyle=style;
}

void set_variable(string wv)
{
    sGlobalVar =wv;
    Session.get_user_session()->define_global(wv);
}

string get_variable()
{
    return sGlobalVar;
}

int set_state(string|int s)
{
    string value;
    if (!stringp(s))
    {
        if (sizeof(states))
            value = states[0]->name;
    } else
        value = s;
    
    if (::set_state(value))
    {
        Session.get_user_session()->set_global(sGlobalVar, value);
        return 1;
    }
    return 0;
}

class CellRenderer {
    inherit Slotter.Insert;
    string desc;
    
    void create(Slotter.Slot parent, string state) {
        set_slot(parent);
        desc = state;
    }

    array generate() {
        object session = Session.get_user_session();

        if (get_state() == desc)
            return
                ({ "<td align=\"right\" height=\""+ah+"\""+
                   "width=\""+alw+"\" background=\""+al+"\"/>"+
                   "<td background=\""+ab+"\" align=\"center\">"+
                   "<a "+(astyle?astyle:"")+
                   " href=\""+session->callSession()+
                   "&amp;"+sGlobalVar+"="+desc+"\">"+
                   desc+"</a></td>"+
                   "<td align=\"left\" height=\""+ah+"\""+
                   "width=\""+arw+"\" background=\""+ar+"\"/>" });
        else return
            ({ "<td align=\"right\" height=\""+ih+"\""+
               "width=\""+ilw+"\" background=\""+il+"\"/>"+
               "<td background=\""+ib+"\" align=\"center\">"+
               "<a "+(istyle?istyle:"")+
               " href=\""+session->callSession()+
               "&amp;"+sGlobalVar+"="+desc+"\">"+
               desc+"</a></td>"+
               "<td align=\"left\" height=\""+ih+"\""+
               "width=\""+irw+"\" background=\""+ir+"\"/>"});
    }
}


class CellSlot{
    inherit Slotter.Slot;

    string state;
    void create(Slotter.Slot parent, string _state) {
        ::create(parent, "state:"+_state);
        state = _state;
    }

    Slotter.Insert get_insert() {
        return CellRenderer(this_object(), state);
    }
}

        
int add_state(string s)
{
    ::add_state(s, CellSlot(get_slot(), s));
}

array generate()
{
    array(Slotter.Slot) slots = ::generate();
    array out = ({"<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\">"});

    foreach(slots, Slotter.Slot slot)
    {
        out += ({"<tr>"}) + ({ slot }) + ({"</tr>"});
    }

    out += ({"</table>"});
    return out;
}

array preview()
{
    array out = ({"<table>"});
    array(Slotter.Slot) slots =::preview();
    
    foreach(slots, Slotter.Slot slot)
    {
        out += ({"<tr>"}) + ({ slot }) + ({"</tr>"});
    }
    
    return out +({ "</table>" });
}

object get_cell() {
    return CellRenderer(0,"test");
}
