
AttachScript("ObjectModule.bsl", "Module");
Module = New Module;
Execute("Module." + CommandLineArguments[0] + "()");