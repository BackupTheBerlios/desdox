inherit Slotter.Insert;
array(Slotter.Slot) table = ({});


Slotter.Slot new_row(string name) {
    Slotter.Slot slot = Slotter.Slot();
    table += ({slot});
    return slot;
}

array preview() {
    return copy_value(table);
}

array generate() {
    return copy_value(table);
}
