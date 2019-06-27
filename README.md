# tirex

Регулярные выражения для платформы 1С:Предприятие 8 и интерпретатора OneScript

Пример использования (OneScript):
```bsl
AttachScript("C:\git\tirex\src\tirex\Ext\ObjectModule.bsl", "Tirex");
Tirex = New Tirex;

RegexProc = Tirex.Build("Процедура ([\w\d_]+)\(.*\).*");
RegexFunc = Tirex.Build("Функция ([\w\d_]+)\(.*\).*");
Reader = New TextReader;
Reader.Open("Module.bsl");

Str = Reader.ReadLine();
While Str <> Undefined Do
	If Tirex.Match(RegexProc, Str) Then
		Captures = Tirex.Captures(RegexProc);
		For Each Item In Captures Do
			Message(Mid(Str, Item.Beg, Item.End - Item.Beg));
		EndDo;
	ElsIf Tirex.Match(RegexFunc, Str) Then
		Captures = Tirex.Captures(RegexFunc);
		For Each Item In Captures Do
			Message(Mid(Str, Item.Beg, Item.End - Item.Beg));
		EndDo;
	EndIf;
	Str = Reader.ReadLine();
EndDo;
```

Этот код находит имена всех процедур и функций в модуле `Module.bsl`
Производительность примера для процессора i5 8400: около 3 сек на 50k строк
