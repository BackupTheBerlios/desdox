inherit Slotter.Inserts.VerticalMenu;

string sBaseDir = ".";
string sProto = "";

void create(string|void basedir, string|void proto)
{
    if (basedir)
        sBaseDir = basedir;

    if (proto)
        sProto = proto;
    
    set_active_icons(sProto+
                     combine_path(basedir,"./unimenu/UniActiveL.gif"), 20 ,
                     sProto+
                     combine_path(basedir,"./unimenu/UniActiveM.gif"), 35,
                     sProto+
                     combine_path(basedir,"./unimenu/UniActiveR.gif"),20);
    set_inactive_icons(sProto+
                       combine_path(basedir,"./unimenu/UniInActiveL.gif"), 20,
                       sProto+
                       combine_path(basedir,"./unimenu/UniInActiveM.gif"), 35,
                       sProto+
                       combine_path(basedir,"./unimenu/UniInActiveR.gif"),20);
    set_active_style("class=\"UniActiv\"");
    set_inactive_style("class=\"UniInActiv\"");
}


array generate()
{
    object session = Session.get_user_session();
    string var = get_variable();
    string val = session->get_global(var);
    set_state(val);
    return ::generate();
}

                  
array(string) need_style_sheets() {
    return ({ sProto + combine_path(sBaseDir,"./unimenu/menu.css") });
}

