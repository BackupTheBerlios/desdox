function check_register(form) {
    var i = 0;
    var test = true;
    var alerttext = "Bitte die folgenden Felder ausfuellen:\r\r";    

    if(form.nickname.value == "") {
	alerttext = alerttext + "Nick\r";
	test = false;
    }
    if (form.nickname.value.length < 4 && form.nickname.value != "") {
	alerttext = alerttext + "Die minimale Laenge des Nick ist 4\r";
	test = false;
    }

    if(form.email.value == "") {
	alerttext = alerttext + "E-mail\r";
	test = false;
    }
    
    if(form.pw.value == "") {
		alerttext = alerttext + "Password\r";
		test = false;
    }
    if(form.pw.value.length < 6 && form.pw.value != "") {
	alerttext = alerttext + "Die Laenge des Passwortes muss mindestens 6 Zeichen sein\r";
	test = false;
    } 
    if ( form.mnr.value.length != 7 ) {
	alerttext = "Die Matrikelnummer muss genau aus 7 Nummern bestehen !";
	test = false;
    }	
    else {
	for ( i = 0; i < 7; i++ ) 
            if ( form.mnr.value.charAt(i) < '0' || form.mnr.value.charAt(i) > '9' ) {
		alerttext = "Die Matrikelnummer darf nur aus Nummern bestehen !";
	        test = false;
	    }
    }
    if ( form.studiengang.value == "" ) {
	alerttext = alerrtext + "Studiengang\r";
	test = false;
    }
	
	
    if (!test) alert(alerttext);

    return test;
}



