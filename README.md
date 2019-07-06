# tirex

Регулярные выражения для платформы 1С:Предприятие 8 и интерпретатора OneScript

## Введение

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
			Message(Mid(Str, Item.Pos, Item.Len));
		EndDo;
	ElsIf Tirex.Match(RegexFunc, Str) Then
		Captures = Tirex.Captures(RegexFunc);
		For Each Item In Captures Do
			Message(Mid(Str, Item.Pos, Item.Len));
		EndDo;
	EndIf;
	Str = Reader.ReadLine();
EndDo;
```

Этот код находит имена всех процедур и функций в модуле `Module.bsl`

Производительность примера для процессора i5 8400: около 3.5 сек. на 50k строк

## Особенности

Оператор `*` работает лениво. В обычных регулярках аналогом будет `*?`.
Сделано так потому что кажется более удобным. Работает быстрее и матчит то, что интуитивно ожидается.

Оператор `|` реализован только в dev ветке. Его поддержка усложняет реализацию и снижает скорость,
а на практике его всегда можно эмулировать несколькими регулярками как в примере выше.

Скобки в выражениях работают только как захваты почти аналогично регуляркам Lua.
Как следствие за скобкой `)` не могут следовать операторы `*`, `+`, `?`, `|`.
Сделано так из-за сложностей реализации полной поддержки скобок.

Функцию Match() желательно использовать только для небольших строк.
Для поиска шаблона в большом файле следует использовать Search().

Search() использует для сопоставления более эффективный алгоритм, но платой за это является невозможность извлечения захватов внутри выражения.

Класс `\w` содержит только буквы английского и русского алфавитов. При необходимости его можно расширить внеся соответствующие изменения в код.

Поддерживается необычный для регулярок оператор `_` который позволяет игнорировать регистр букв на отдельных частях регулярного выражения. Например, чтобы найти в тексте конструкцию `Если СмыслЖизни = 42 Тогда` можно использовать такое выражение:
`_если_ _смыслжизни_ = 42 _тогда_`
Каждое вхождение символа `_` работает как переключатель зависимости от регистра.

В целом список метасимволов такой:
* `\w` - любая буква
* `\W` - любой символ кроме буквы
* `\d` - любая цифра
* `\D` - любой символ кроме цифры
* `\s` - любой невидимый символ
* `\S` - любой символ кроме невидимых
* `\n` - перевод строки
* `\r` - возврат каретки
* `\t` - табуляция
* `.`  - любой символ
* `*`  - замыкание Клини
* `+`  - один или несколько
* `?`  - один или ничего
* `|`  - альтернатива (только в dev ветке)
* `()` - захваты
* `[...]` - один символ из набора
* `[^...]` - любой символ, кроме символов из набора
* `_`  - включить/выключить режим case insensitive
* `$` - конец строки

## Эффективность

Очевидно регулярки на языке 1С будут в общем случае медленнее нативных,
но для многих задач их скорости более чем достаточно.

Кроме того, в некоторых кейсах они все же могут быть быстрее нативных.

Например, нам нужно построчно сматчить сложный шаблон в большом файле (~50k строк).

Следующий код на OneScript отрабатывает за 77 сек.:
```bsl
AttachScript("ObjectModule.bsl", "Tirex");
Tirex = New Tirex;

Regex = Tirex.Build(".*(\w+ = "".*"")");
Reader = New TextReader;
Reader.Open("Module.bsl");

Start = CurrentUniversalDateInMilliseconds();

Str = Reader.ReadLine();
While Str <> Undefined Do
	If Tirex.Match(Regex, Str) Then
		Captures = Tirex.Captures(Regex);
		For Each Item In Captures Do
			Message(Mid(Str, Item.Pos, Item.Len));
		EndDo;
	EndIf;
	Str = Reader.ReadLine();
EndDo;

Message((CurrentUniversalDateInMilliseconds() - Start) / 1000);
```

Примерный аналог с использованием нативных регулярок отрабатывает за 148 сек.:
```bsl
Regex = New Regex(".*?(\w+ = "".*?"")");
Reader = New TextReader;
Reader.Open("Module.bsl");

Start = CurrentUniversalDateInMilliseconds();

Str = Reader.ReadLine();
While Str <> Undefined Do
	Matches = Regex.Matches(Str);
	If Matches.Count() > 0 Then
		Message(Matches[0].Groups[1].Value);
	EndIf;
	Str = Reader.ReadLine();
EndDo;

Message((CurrentUniversalDateInMilliseconds() - Start) / 1000);
```
Оба примера находят 1383 совпадения. Результат работы полностью идентичен.

Пример с нативной регуляркой конечно можно изменить так, чтобы он работал гораздо быстрее.
Следующий код отработает за 4 сек. Но нужно учитывать что этот код делает не совсем то же самое.
У вас могут быть на входе только отдельные строки, а не весь файл.
```bsl
Regex = New Regex("\w+ = "".*?""");
Reader = New TextReader;
Reader.Open("Module.bsl");

Start = CurrentUniversalDateInMilliseconds();

Str = Reader.Read();
Matches = Regex.Matches(Str);
For Each Item In Matches Do
	Message(Item.Groups[0].Value);
EndDo;

Message((CurrentUniversalDateInMilliseconds() - Start) / 1000);
```

Примерный аналог с использованием tirex будет работать уже 152 сек.

*прим.: из этого примера видно что построчный матчинг лучше делать через Match()*
```bsl
AttachScript("ObjectModule.bsl", "Tirex");
Tirex = New Tirex;

Regex = Tirex.Build("\w+ = "".*""");
Reader = New TextReader;
Reader.Open("Module.bsl");

Start = CurrentUniversalDateInMilliseconds();

Str = Reader.Read();
Capture = Tirex.Search(Regex, Str);
While Capture <> Undefined Do
	Message(Mid(Str, Capture.Pos, Capture.Len));
	Str = Mid(Str, Capture.Pos + Capture.Len);
	Capture = Tirex.Search(Regex, Str);
EndDo;

Message((CurrentUniversalDateInMilliseconds() - Start) / 1000);
```

В общем случае на практике tirex скорее всего будет примерно в 30(+-10) раз медленнее нативных регулярок. 

---
Для тестирования используется фреймворк run.bsl

Установить библиотеку можно с помощью пакетного менеджера <kbd>Ctrl</kbd>+<kbd>C</kbd> <kbd>Ctrl</kbd>+<kbd>V</kbd>
