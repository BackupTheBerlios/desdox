inherit Slotter.Inserts.HorizontalSimpleMenu;

string sBaseDir = ".";
string sProto = "";

void create(string|void basedir, string|void proto) {
    if (basedir)
        sBaseDir = basedir;

    if (proto)
        sProto = proto;
    
    set_active_icons(sProto + combine_path(basedir,"./unimenu/ReiterMBaL.gif"), 12 ,
                     sProto + combine_path(basedir,"./unimenu/ReiterMBaBg.gif"), 22,
                     sProto + combine_path(basedir,"./unimenu/ReiterMBaR.gif"),9);
    set_inactive_icons(sProto + combine_path(basedir,"./unimenu/ReiterMBiL.gif"), 12,
                       sProto + combine_path(basedir,"./unimenu/ReiterMBiBg.gif"), 22,
                       sProto + combine_path(basedir,"./unimenu/ReiterMBiR.gif"),10);

    set_start_end_icons(0,
                        sProto + combine_path(basedir, "./unimenu/ReiterMBEnd.gif"));
    set_active_style("class=\"TabActiv\"");
    set_inactive_style("class=\"TabInActiv\"");
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
