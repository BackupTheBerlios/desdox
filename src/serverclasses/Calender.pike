
class Calender {

  string calenderName;
  array (Termin) TerminListe;


  /*
    Der Konstruktor der Klasse Calender. Nimmt einen String entgegen und
    weist ihn der Klassenvariable calenderName zu.  
  */
  void create (string name) {
    
    write ("Der Kalender fuer "+name +" wird erzeugt.\n" );
    this->calenderName = name + "`s Calender"+"\n";

  }


  /*
    Druckt den Namen des Kalenders aus.
  */
  void druckeCalenderName () {

    write (this->calenderName);

  }


  /*
    Setzt den Namen des Kalenders
  */
  void setCalenderName (string newCalenderName) {

    this->CalenderName = newCalenderName;

  }

  /*
    Liefert den Namen des Kalenders als string
  */
  string getCalenderName () {

    return this->calenderName+"\n";

  }


  /*
    Muss noch implementiert werden
  */
  void  addDate () {

  }

  /*
    Muss noch implementiert werden
  */
  void  deleteDate () {

  }
  /*
    Liefert alle Termine des Users zurück, oder gibt diese aus.
    Was auch immer.
  */
  void  getDates () {

  }
}
