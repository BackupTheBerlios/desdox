inherit Slotter.Inserts.Dispatcher;

string al, ab, ar;
int alw, ah, arw;
string astyle;
string il, ib, ir;
int ilw, ih, irw;
string istyle;

string start, end;
string sWidth, sAlign;

string sGlobalVar;

void set_start_end_icons(string s, string e)
{
    start =s;
    end = e;
}

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

    void create(string state) {
        desc = state;
    }

    array preview() {
        return ({ desc });
    }

    array generate() {
        object session = Session.get_user_session();
        
        if (get_state() == desc)
            return
                ({ "     <td align=\"right\" height=\""+ah+"\""+
                   "width=\""+alw+"\" background=\""+al+"\"/>"+
                   "<td background=\""+ab+"\" align=\"center\">\n"+
                   "        <a "+(astyle?astyle:"")+
                   " href=\""+session->callSession()+
                   "&amp;"+sGlobalVar+"="+desc+"\">"+
                   desc+"</a>\n    </td>\n"+
                   "     <td align=\"left\" height=\""+ah+"\""+
                   "width=\""+arw+"\" background=\""+ar+"\"/>\n" });
        else return
            ({ "    <td align=\"right\" height=\""+ih+"\""+
               "width=\""+ilw+"\" background=\""+il+"\"/>"+
               "<td background=\""+ib+"\" align=\"center\">\n"+
               "       <a "+(istyle?istyle:"")+
               " href=\""+session->callSession()+
               "&amp;"+sGlobalVar+"="+desc+"\">"+
               desc+"</a>\n     </td>\n"+
               "     <td align=\"left\" height=\""+ih+"\""+
               "width=\""+irw+"\" background=\""+ir+"\"/>\n"});
    }
}


class CellSlot{
    inherit Slotter.Slot;

    string state;
    void create(string _state) {
        state = _state;
    }

    Slotter.Insert get_insert() {
        return CellRenderer(state);
    }
}

        
int add_state(string s)
{
    ::add_state(s, CellSlot(s));
}

array generate()
{
    array(Slotter.Slot) slots = ::generate();
    array out = ({"  <table cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n"});

    out += ({ "  <tr><!--MenuRow-->\n" });

    if (start) out += ({ "    <td><img src=\""+start+"\"/></td>\n" });
    foreach(slots, Slotter.Slot slot)
    {
        out += ({ slot }) ;
    }
    if (end) out += ({ "     <td><img src=\""+end+"\"/></td>\n" });
    
    out += ({"  </tr><!--MenuRow-->\n"});
    out += ({"  </table>\n"});
    return out;
}

array preview()
{
    array(Slotter.Slot) slots = ::preview();
    array out = ({ "<table cellpadding=\"0\" cellspacing=\"0\" border=\"1\" >\n",
                   "<tr>HorizontalSimpleMenu<br/>" });

    foreach(slots, Slotter.Slot slot)
    {
        out += ({ slot , "<br/>"});
    }
    out += ({"</tr></table>\n"});
    return out;
}


object get_cell() {
    return CellRenderer("test");
}

void set_width(string width) {
    sWidth = width;
}

void set_align(string align) {
    sAlign = align;
}
