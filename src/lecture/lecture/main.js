function open_chat(id,room,port) {
window.open("/scripts/jicra.pike?channel="+room,"create","scrollbars=yes,width=780,height=600");
}
function order_inventory(id) {
	window.open("/scripts/browser.pike?id="+id+"&_action=show_inventory_order","user","scrollbars=yes,width=480,height=520");
}

function order_inventory_slides(id) {
window.location.href="/scripts/browser.pike?id="+id+"&_action=order_inventory_slides";
}


function open_transfer(id) {
window.open("/gui/upload.html?environment="+id,"create","scrollbars=yes,width=450,height=330");
}

function open_create(id) {
window.open("/documents/create.xml?mode=Container&object="+id,"create","scrollbars=yes,width=720,height=420");
}

function open_upload(id) {
window.open("/documents/create.xml?mode=Document&object="+id,"create","scrollbars=yes,width=720,height=420");
}

function open_search() {
window.open("/documents/search.html","search","scrollbars=yes,width=800,height=600");
}

function open_access(id) {
window.open("/scripts/navigate.pike?object="+id+"&type=access&mode=simple","access","scrollbars=yes,width=680,height=560");
}

function open_attributes(id) {
window.open("/scripts/navigate.pike?object="+id+"&type=attributes","access","scrollbars=yes,width=680,height=560");
}

function open_userdetails(id) {
window.open("/scripts/navigate.pike?object="+id+"&type=details","user","scrollbars=yes,width=480,height=520");
}

function open_userdetailsreply(id) {
window.open("/scripts/navigate.pike?object="+id+"&type=details&mode=sendmail","user","scrollbars=yes,width=480,height=520");
}

function open_ftp(url) {
window.open("ftp://"+url,"steamftp","scrollbars=yes,status=yes,statusbar=yes,menubar=yes,resizable=yes,width=680,height=560");
}

function open_export(id) {
window.open("/scripts/navigate.pike?object="+id+"&style=/stylesheets/export.xsl","user","scrollbars=yes,width=480,height=520");
}

function set_searchfield(form) {
	if(form.keywords.value == "Enter keywords") form.keywords.value = '';
    form.action = "/scripts/browser.pike";
    form._action.value = "search";
}

function check_searchfield(form) {
    if(form.keywords.value == "" || form.keywords.value == "Enter keywords") {
	   alert("Please enter a keyword!");
	   return false;
	} else {
	    form.action = "/scripts/browser.pike";
	    form._action.value = "search";
        form.submit();
    }   
}

function checkall_objects(form) {
    for(var i=0; i<form.length; i++)
	if(form.elements[i].name == "objsel") form.elements[i].checked = true;
}

function uncheckall_objects(form) {
    for(var i=0; i<form.length; i++)
	    if(form.elements[i].name == "objsel") form.elements[i].checked = false;
}

function checkall_gateobjects(form) {
    for(var i=0; i<form.length; i++)
	if(form.elements[i].name == "gateobjsel") form.elements[i].checked = true;
}

function uncheckall_gateobjects(form) {
    for(var i=0; i<form.length; i++)
	    if(form.elements[i].name == "gateobjsel") form.elements[i].checked = false;
}

function check_add(form) {
    var check = false;
    
    for(var i=0; i<form.length; i++)
	    if(form.elements[i].name == "objsel" && form.elements[i].checked == true) check = true;

    if(check) {
        form.action = "/scripts/browser.pike";
        form._action.value = "select";
        form.submit();
    } else return false;
}

function search_again(form)
{
	form._action.value = "search";
	form.submit();
}



function check_objsel_for_selection(no_checkedobjsel) {
	if(no_checkedobjsel == "0") {
		alert("You have to check an Object for this function!");
		return false;
	} else if(no_checkedobjsel == "1") {
		return true;
		} else {
			alert("Just check >one< Object for this function!");
			return false;
		}
}

function commit_action(form) {
    var cselect = form.user_action.selectedIndex;
	var no_checkedobjsel = 0;
	var objid = form.id.value;
	var checked_objid = "-1";
	var check = false;
	
    for(var i=0; i<form.length; i++) {
		if(form.elements[i].name == "objsel" && form.elements[i].checked == true) {
			no_checkedobjsel++;
			checked_objid = form.elements[i].value;
		}
	}
	
	switch(form.user_action.options[cselect].value) {
		case "---":
			return false;
			break;
		case "select_objects":
			return checkall_objects(form);
			break;
		case "unselect_objects":
			return uncheckall_objects(form);
			break;
		case "get_objects":
			check = true;
			break;
		case "copy_objects":
			check = true;
			break;
		case "link_objects":
			check = true;
			break;
		case "delete_objects":
			check = true;
			break;
		case "show_annotations":
			check = check_objsel_for_selection(no_checkedobjsel);
			if(check) document.location.href = "/scripts/navigate.pike?object=" + checked_objid + "&amp;type=annotations";
			check = false;
			break;
		case "show_access":
			check = check_objsel_for_selection(no_checkedobjsel);
			if(check) open_access("" + checked_objid + "");
			check = false;
			break;
		case "show_attributes":
			check = check_objsel_for_selection(no_checkedobjsel);
			if(check) open_attributes("" + checked_objid + "");
			check = false;
			break;
		default:
			return false;
			break;
	}

    if(form.user_action.options[cselect].value == "show_handout")
        form.action = "/scripts/handout.pike";
    	else form.action = "/scripts/browser.pike";
    form._action.value = form.user_action.options[cselect].value;
    if(no_checkedobjsel > 0 && (check)) form.submit();
}

function commit_gateaction(form) {
    var cselect = form.user_gateaction.selectedIndex;
	var no_checkedobjsel = 0;
	var objid = form.id.value;
	var checked_objid = "-1";
	var check = false;

    for(var i=0; i<form.length; i++) {
		if(form.elements[i].name == "gateobjsel" && form.elements[i].checked == true) {
			no_checkedobjsel++;
			checked_objid = form.elements[i].value;
		}
	}
	
	switch(form.user_gateaction.options[cselect].value) {
		case "---":
			return false;
			break;
		case "select_objects":
			return checkall_gateobjects(form);
			break;
		case "unselect_objects":
			return uncheckall_gateobjects(form);
			break;
		case "get_objects":
			check = true;
			break;
		case "copy_objects":
			check = true;
			break;
		case "link_objects":
			check = true;
			break;
		case "delete_objects":
			check = true;
			break;
		default:
			return false;
			break;
	}
	
      if ( form.user_gateaction.options[cselect].value == "show_handout" )
        form.action = "/scripts/handout.pike";
    else
        form.action = "/scripts/browser.pike";
    form._action.value = form.user_gateaction.options[cselect].value;
    if(no_checkedobjsel > 0 && (check)) form.submit();
}


function check_searchrooms(form) {
	var no_checkedobjsel = 0;
	
    for(var i=0; i<form.length; i++) {
		if(form.elements[i].name == "objsel" && form.elements[i].checked == true) {
			no_checkedobjsel++;
		}
	}
	
    if(no_checkedobjsel == 1) form.submit();
		else {
			alert("Please select the destination room for exit");
			return false;
		}
}


function clipboard_action(form, act) {
    var question = "Do you really want to  " + act + "  the selected object?"
    but = confirm(question);
    
    if(but == true) {
        form.action = "/scripts/browser.pike";
	    form._action.value = act;
        form.submit();
    }
}

function do_user_action(form, act) {
	form.action = "/scripts/browser.pike";
	form._action.value = act;
	form.submit();
}

function clipboard_show(form) {
   	form.action = "/scripts/browser.pike";
	form.popup_id.value = 0;
    form._action.value = "show";
	form.submit();
}

function clipboard_leave(form) {
	form.action = "/scripts/browser.pike";
	form.popup_id.value = 0;
	form._action.value = "select";
	form.submit();
}

function escapeurl(escurl) {
    window.location.href = escape(escurl);
}


function encodeurl(url) {
    document.href.location = escape(url);
}

function decodeurl() {
    tmp = document.URL.split("?object=");
    return tmp[1];
}

function open_group(id) {
   opener.location = "/scripts/navigate.pike?object="+id;
}

function open_groups() {
   opener.location = "/scripts/groups.pike";
}

function grp_add_users(form) {
	form.action = "/scripts/browser.pike";
	form._action.value = "grp_add";
	form.submit();
}

function grp_remove_users(form) {
	form.action = "/scripts/browser.pike";
	form._action.value = "grp_remove";
	form.submit();
}

function grp_check_invite(form) {
    if(form.keywords.value == "") {
	   alert("Please enter a User name!");
	   return false;
	} else return true;
}

function send_message(form) {
	form.action = "/scripts/browser.pike";
	form._action.value = "send_message";
	form.submit();
}

function drop_objects(form) {
	form.action = "/scripts/browser.pike";
	form._action.value = "drop_objects";
	form.submit();
}

function get_date(t) {
    if ( t == 0 )
        return "never";
    Zeit = new Date();
    Zeit.setTime(t*1000);
    var datum = Zeit.toGMTString();
    return datum;
}

function check_invite(form) {
    var check = false;
    
    for(var i=0; i<form.length; i++)
	if(form.elements[i].name == "objsel" && form.elements[i].checked == true) check = true;

    if(check) return true;
        else {
			alert("Please select one or more users for your invitation!");
			return false;
		}
}


function show_error(msg) {
    alert(msg);
}


function check_tutorialupload(form) {
	var check_ok = true;
	var alerttext = "Bitte die folgenden Felder ausfüllen:\n\n";
	var tabidx = eval(form.tutorials_selecttutor.options.selectedIndex);
	
	if (form.URL.value == "") { 
        alerttext = alerttext + "Dokument-Datei\n";
        check_ok = false;
    }	
	
	if(form.tutorials_selecttutor.options[tabidx].value == -1) { 
        alerttext = alerttext + "Übungsgruppenleiter\n";
        check_ok = false;
    }
	
	if (form.tutorial_mno2.value == "" || form.tutorial_mno3.value == "") { 
        alerttext = alerttext + "2. und 3. Matrikelnummer\n";
        check_ok = false;
    }
	
	if(!check_ok) {
        alert(alerttext);
        return false;
    } else form.submit();
}


function tutorials_set_rate(id) {
	var form = document.browser;
	
	form.action = "/scripts/lecture.pike";
	form._action.value = "rate";
	form.object.value = id;
	form.submit();
}


function finish_tutorial(id) {
	var form = document.browser;
	var finishcheck = confirm("Soll die Bewertung wirklich abgeschlossen werden?");
	
	if(finishcheck) {
		form.action = "/scripts/lecture.pike";
		form._action.value = "finish";
		form.object.value = id;
		form.submit();
	} else return false;
}
