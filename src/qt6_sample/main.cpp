 #include <QApplication>
 #include <QPushButton>

 int main(int argc, char *argv[])
 {
     const QApplication app(argc, argv);

     QPushButton hello("Hello world!");

     hello.show();
     return app.exec();
 }