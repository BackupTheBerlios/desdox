
#include "Calender.pike"
#include "Termin.pike"

class User {

  string name;
  Calender calender;

  void create (string name) {

    write ("Der User mit dem Namen "+name +" wird erzeugt.\n" ); 
    this->name = name; 
    this->calender = Calender (name);
  
  }

  string getName () {

    return this->name;

  }

  void setName (string name) {

    this->name = name; 

  }

  void druckeName () {

    write ("Der Name des Objektes ist " + this->name +"\n");

  }

}


void main () {

  User myObject = User ("Markus");
  myObject->druckeName();

  myObject->calender-> druckeCalenderName ();


  myObject->setName("Bernd");
  myObject->druckeName();

  Termin test = Termin ();
}
