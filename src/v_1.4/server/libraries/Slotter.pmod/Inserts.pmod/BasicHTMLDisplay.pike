inherit Slotter.Insert;
string filename;

void create(string fname)
{
    filename = fname;
}

array preview()
{
    return ({filename});
}

array generate()
{
    Stdio.File f = Stdio.File(filename, "r");
    return ({f->read()});
}
