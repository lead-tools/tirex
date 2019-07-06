
// MIT License

// Copyright (c) 2019 Tsukanov Alexander

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#Region Public

// Function - Проверяет соответствует ли строка регулярному выражению.
// Сопоставление выполняется обходом в глубину с мемоизацией.
//
// Parameters:
//  Regex	 - Array - скомпилированная функцией Build() регулярка 
//  Str		 - String - проверяемая строка 
// 
// Returns:
//  Boolean - признак что строка соответствует регулярному выражению
//
Function Match(Regex, Str) Export
	Memo = New Array(Regex.Count(), 1);
	Ok = MatchRecursive(Regex, Memo, Str, 1, 1);
	Return Ok;
EndFunction

// Function - Ищет в строке первое совпадение с регулярным выражением.
// Сопоставление выполняется обходом в ширину.
// В текущей реализации возвращает только один захват на все выражение (скобки в выражении игнорируются).
//
// Не тестировалось. Использовать в бою нельзя.
//
// Parameters:
//  Regex	 - Array - скомпилированная функцией Build() регулярка 
//  Str		 - String - проверяемая строка 
// 
// Returns:
//  Undefined, Structure("Pos, Len") - найденный диапазон
//
Function Search(Regex, Str) Export
	List = New Array;
	NewList = New Array;
	For Beg = 1 To StrLen(Str) Do
		List.Add(1);
		For Pos = Beg To StrLen(Str) + 1 Do
			Char = Mid(Str, Pos, 1);
			For Each Target In List Do
				While Target <> Undefined Do 
					Node = Regex[Target];
					If Node["end"] = True Then // это разрешенное конечное состояние?
						Return New Structure("Pos, Len", Beg, Pos - Beg);
					EndIf;
					Target = Node[Char];
					If Target = Undefined Then
						Target = Node["any"]; // разрешен любой символ?  
					EndIf;
					If Target <> Undefined Then
						If NewList.Find(Target) = Undefined Then
							NewList.Add(Target);
						EndIf; 
					EndIf;	
					Target = Node["next"]; // можно пропустить без поглощения символа?
				EndDo; 
			EndDo;
			Temp = List;
			List = NewList;
			NewList = Temp;
			NewList.Clear();
			If List.Count() = 0 Then
				Break;
			EndIf;
		EndDo;
		For Each Target In List Do // если образец найден в конце строки, то эти узлы еще не проверены
			If Regex[Target]["end"] = True Then // это разрешенное конечное состояние?
				Return New Structure("Pos, Len", Beg, Pos - Beg);
			EndIf;
		EndDo;
		List.Clear();
	EndDo;
	Return Undefined;
EndFunction

// Function - Возвращает скомпилированную регулярку
//
// Parameters:
//  Pattern - String - регулярное выражение
//		\w - любая буква
//		\W - любой символ кроме буквы
//		\d - любая цифра
//		\D - любой символ кроме цифры
//		\s - любой невидимый символ
//		\S - любой символ кроме невидимых
//		\n - перевод строки
//		\r - возврат каретки
//		\t - табуляция
//		.  - любой символ
//		*  - замыкание Клини
//		+  - один или несколько
//		?  - один или ничего
//		() - захваты
//		[...] - один символ из набора
//		[^...] - любой символ, кроме символов из набора
//		_  - включить/выключить режим case insensitive
//		$ - конец строки
// 
// Returns:
// Array - скомпилированная регулярка
//
Function Build(Pattern) Export
	Lexer = Lexer(Pattern);
	Regex = New Array;
	CharSet = NextChar(Lexer);
	Balance = 0;
	Node = NewNode(Regex); // нулевой узел
	Node = NewNode(Regex); // первый узел
	While CharSet <> "" Do
		If CharSet = "\" Then	
			CharSet = CharSet(Lexer, NextChar(Lexer));
		ElsIf CharSet = "." Then
			CharSet = Lexer.AnyChar;
		ElsIf CharSet = "[" Then
			Set = New Map;	
			Complement = False;
			CharSet = NextChar(Lexer);
			If CharSet = "^" Then
				Complement = True;
				CharSet = NextChar(Lexer);
			ElsIf CharSet = "]" Then
				Set[CharSet] = Complement;
				CharSet = NextChar(Lexer);
			EndIf;
			While CharSet <> "]" Do
				If CharSet = "\" Then
					CharSet = CharSet(Lexer, NextChar(Lexer));
				EndIf;
				If CharSet = "" Then
					Raise "expected ']'";
				EndIf;
				If Complement Then
					Lexer.Complement = Not Lexer.Complement;
				EndIf;
				Set[CharSet] = Lexer.Complement;
				Lexer.Complement = False;
				CharSet = NextChar(Lexer);
			EndDo;
			CharSet = Set;
		ElsIf CharSet = "(" Then
			Count = 0;
			While CharSet = "(" Do
				Count = Count + 1;
				CharSet = NextChar(Lexer);
			EndDo;
			Balance = Balance + Count;
			Node["++"] = Count;
			Node["next"] = Regex.Count();
			Node = NewNode(Regex);
			Continue;
		ElsIf CharSet = ")" Then
			Count = 0;
			While CharSet = ")" Do
				Count = Count + 1;
				CharSet = NextChar(Lexer);
			EndDo;
			Balance = Balance - Count;
			Node["next"] = Regex.Count();
			Node["--"] = Count;
			Node = NewNode(Regex);
			Continue;
		ElsIf CharSet = "_" Then
			Lexer.IgnoreCase = Not Lexer.IgnoreCase;
			CharSet = NextChar(Lexer);
			Continue;
		ElsIf CharSet = "$" Then
			Node[""]= Regex.Count();
			Node = NewNode(Regex);
			Break;
		ElsIf CharSet = "*" Or CharSet = "+" Or CharSet = "?" Then
			Raise StrTemplate("unexpected character '%1' in position '%2'", CharSet, Lexer.Pos);
		EndIf;
		NextChar = NextChar(Lexer); 
		If NextChar = "*" Then
			AddArrows(Lexer, Node, CharSet, Regex.UBound());
			Node["next"] = Regex.Count();
			CharSet = NextChar(Lexer);
		ElsIf NextChar = "+" Then
			AddArrows(Lexer, Node, CharSet, Regex.Count());
			Node = NewNode(Regex);
			AddArrows(Lexer, Node, CharSet, Regex.UBound());
			Node["next"] = Regex.Count();
			CharSet = NextChar(Lexer);
		ElsIf NextChar = "?" Then
			AddArrows(Lexer, Node, CharSet, Regex.Count());
			Node["next"] = Regex.Count();
			CharSet = NextChar(Lexer);
		Else
			AddArrows(Lexer, Node, CharSet, Regex.Count());
			CharSet = NextChar;
		EndIf;
		Node = NewNode(Regex);
		Lexer.Complement = False;
	EndDo;
	If Balance <> 0 Then
		Raise "unbalanced brackets";
	EndIf; 
	Node["end"] = True; // разрешенное конечное состояние
	Return Regex;
EndFunction

// Function - Возвращает захваченные диапазоны из регулярки.
// Порядок диапазонов в списке определен так:
// если строка "xy" и регулярное выражение "((x)(y))",
// то будут захвачены диапазоны [{"Pos":1,"Len":1},{"Pos":2,"Len":1},{"Pos":1,"Len":2}]
// т.е. "x", "y", "xy"
//
// Parameters:
//  Regex	 - Array - регулярка после выполнения на ней Match() 
// 
// Returns:
//  Array - список захваченных диапазонов
//
Function Captures(Regex) Export
	Number = New TypeDescription("Number");
	Captures = New Array;
	Stack = New Map;
	Level = 0;
	For Each Node In Regex Do
		Pos = Number.AdjustValue(Node["pos"]); 
		Inc = Node["++"];
		If Inc <> Undefined Then
			For n = 1 To Inc Do
				Level = Level + 1;
				Stack[Level] = Pos;
			EndDo; 
		EndIf;  
		Dec = Node["--"];
		If Dec <> Undefined Then
			For n = 1 To Dec Do
				Beg = Number.AdjustValue(Stack[Level]);
				Captures.Add(New Structure("Pos, Len", Beg, Pos - Beg));
				Level = Level - 1;
			EndDo;
		EndIf; 
	EndDo;
	Return Captures;
EndFunction

#EndRegion // Public

#Region Private

Function MatchRecursive(Regex, Memo, Str, Val Target = 1, Val Pos = 1)
	Node = Regex[Target];		
	NodeMemo = Memo[Target];
	If NodeMemo.Find(Pos) <> Undefined Then
		Return False;
	EndIf;
	Node["pos"] = Pos;
	Char = Mid(Str, Pos, 1);	
	Target = Node["next"]; // можно пропустить без поглощения символа?
	If Target <> Undefined Then
		If MatchRecursive(Regex, Memo, Str, Target, Pos) Then // попытка сопоставить символ со следующим узлом
			Return True;
		EndIf; 
	EndIf;
	Target = Node[Char];
	If Target = Undefined Then
		Target = Node["any"]; // разрешен любой символ?  
	EndIf;	
	If Target <> Undefined Then
		If MatchRecursive(Regex, Memo, Str, Target, Pos + 1) Then
			Return True;
		EndIf; 
	EndIf; 	
	NodeMemo.Add(Pos);	
	Return Node["end"] = True; // это разрешенное конечное состояние?
EndFunction

Function NewNode(Regex)
	Node = New Map;
	Regex.Add(Node);	
	Return Node;
EndFunction 

Function Lexer(Pattern)
	AlphaSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZабвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ";
	DigitSet = "0123456789";
	SpaceSet = " " + Chars.NBSp + Chars.Tab + Chars.LF;
	Lexer = New Structure;
	// константы
	Lexer.Insert("AlphaSet", AlphaSet);
	Lexer.Insert("DigitSet", DigitSet);
	Lexer.Insert("SpaceSet", SpaceSet);
	Lexer.Insert("Pattern", Pattern);
	Lexer.Insert("AnyChar", New Structure);
	// состояние
	Lexer.Insert("Pos", 0);
	Lexer.Insert("IgnoreCase", False);
	Lexer.Insert("Complement", False);
	Return Lexer;
EndFunction 

Function NextChar(Lexer)
	Lexer.Pos = Lexer.Pos + 1;
	Char = Mid(Lexer.Pattern, Lexer.Pos, 1);
	Return Char;
EndFunction 

Function CharSet(Lexer, Char)
	If Char = "n" Then
		CharSet = Chars.LF;
	ElsIf Char = "r" Then
		CharSet = Chars.CR;
	ElsIf Char = "t" Then
		CharSet = Chars.Tab;
	ElsIf Char = "w" Then
		CharSet = Lexer.AlphaSet;
	ElsIf Char = "d" Then
		CharSet = Lexer.DigitSet;
	ElsIf Char = "s" Then
		CharSet = Lexer.SpaceSet; 
	ElsIf Char = "W" Then
		CharSet = Lexer.AlphaSet;
		Lexer.Complement = True;
	ElsIf Char = "D" Then
		CharSet = Lexer.DigitSet;
		Lexer.Complement = True;
	ElsIf Char = "S" Then
		CharSet = Lexer.SpaceSet;
		Lexer.Complement = True;
	Else
		CharSet = Char;
	EndIf;
	Return CharSet;
EndFunction

Procedure AddArrows(Lexer, Node, CharSet, Val Target)
	If CharSet = Lexer.AnyChar Then
		Node["any"] = Target; // стрелка для любого символа
		Node[""] = 0;         // кроме конца текста
	ElsIf TypeOf(CharSet) = Type("Map") Then
		For Each Item In CharSet Do
			Lexer.Complement = Item.Value;
			AddArrows(Lexer, Node, Item.Key, Target);
		EndDo;
	Else
		If Lexer.Complement Then
			Node["any"] = Target;
			Target = 0; // стрелка на нулевой узел (запрещенное состояние)
		EndIf;
		For Num = 1 To Max(1, StrLen(CharSet)) Do
			Char = Mid(CharSet, Num, 1); 
			If Lexer.IgnoreCase Then
				Node[Lower(Char)] = Target;
				Node[Upper(Char)] = Target;
			Else
				Node[Char] = Target;
			EndIf;
		EndDo;
	EndIf; 
EndProcedure  

#EndRegion // Private

#Region Tests

Procedure RunAllTests() Export
	For Num = 1 To 24 Do
		Try
			Execute StrTemplate("Test%1()", Num);
		Except
			Message(ErrorDescription());
		EndTry;
	EndDo;
EndProcedure

Function Elapsed(Start)
	Return (CurrentUniversalDateInMilliseconds() - Start) / 1000;
EndFunction

Procedure Test1() Export
	Regex = Build(".*_world_.*my \w*$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "World in my eyes");
	Message(StrTemplate("Test1 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test2() Export
	Regex = Build(".*_world_.*my \w*$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "Word in my eyes");
	Message(StrTemplate("Test2 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test3() Export
	Regex = Build("a*a*a*a*a*a*a*a*a*a*a*a*a*a*aaaaaaaaaaaaaaa$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "aaaaaaaaaaaaaa");
	Message(StrTemplate("Test3 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test4() Export
	Regex = Build("\W*digits$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "123456789digits");
	Message(StrTemplate("Test4 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test5() Export
	Regex = Build("\w*digits$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "123456789digits");
	Message(StrTemplate("Test5 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test6() Export
	Regex = Build("_Case_.*_When_.*_Then_.*_Else_.*END$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "CASE Value WHEN 1 THEN '1' ELSE '0' END");
	Message(StrTemplate("Test6 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test7() Export
	Regex = Build("_\SoRd*_$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "wordDDD");
	Message(StrTemplate("Test7 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test8() Export
	Regex = Build("word[147]*word1$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word1417word1");
	Message(StrTemplate("Test8 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test9() Export
	Regex = Build("word[147]*word1$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word14217word1");
	Message(StrTemplate("Test9 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test10() Export
	Regex = Build("word[\d]*word1$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word14217word1");
	Message(StrTemplate("Test10 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test11() Export
	Regex = Build("word[\D]*word1$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word14217word1");
	Message(StrTemplate("Test11 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test12() Export
	Regex = Build("word[\D]*word1$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "wordword1");
	Message(StrTemplate("Test12 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test13() Export
	Regex = Build("If.*(_then_).*_ENDIF_;$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "If x > 0 Then x = 0 EndIf;");
	Message(StrTemplate("Test13 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test14() Export
	Regex = Build("_If.*__(_then_).*_ENDIF_;$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "If x > 0 Then x = 0 EndIf;");
	Message(StrTemplate("Test14 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test15() Export
	Regex = Build(".*xyz$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "sfds1 $565 fdv\_fvdf dfvdf\0\9\)xyz");
	Message(StrTemplate("Test15 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test16() Export
	Regex = Build("\\\(\)\_\*$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "\()_*");
	Message(StrTemplate("Test16 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test17() Export
	Regex = Build("a+b+c+$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "aaabcccc");
	Message(StrTemplate("Test17 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test18() Export
	Regex = Build("\.$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, ".");
	Message(StrTemplate("Test18 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test19() Export
	Regex = Build("\.$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "a");
	Message(StrTemplate("Test19 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test20() Export
	Regex = Build("[]]*$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "]]]]");
	Message(StrTemplate("Test20 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test21() Export
	Regex = Build("[\w]+$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "sadadw");
	Message(StrTemplate("Test21 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test22() Export
	Regex = Build("[\W]+$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "sadadw");
	Message(StrTemplate("Test22 - %1 (%2 sec)", ?(Ok, "Failed!", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test23() Export
	Regex = Build("[\W]+$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "12314324");
	Message(StrTemplate("Test23 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

Procedure Test24() Export
	Regex = Build("[^\W]+$");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "sadadw");
	Message(StrTemplate("Test24 - %1 (%2 sec)", ?(Ok, "Passed", "Failed!"), Elapsed(Start)));
EndProcedure

#EndRegion // Tests

#Region Examples

// Вывод списка экспортных процедур из этого модуля
// Например, для данной процедуры будет выведено:
// Example1()
Procedure Example1() Export
	Regex = Build("Procedure (\w*\d*\(.*\)) Export");
	Reader = New TextReader;
	Reader.Open("ObjectModule.bsl");
	Start = CurrentUniversalDateInMilliseconds();
	Str = Reader.ReadLine();
	While Str <> Undefined Do
		If Match(Regex, Str) Then
			Captures = Captures(Regex);
			For Each Item In Captures Do
				Message(Mid(Str, Item.Pos, Item.Len));
			EndDo;
		EndIf;
		Str = Reader.ReadLine();
	EndDo;
	Message(StrTemplate("Example1 - Completed (%1 sec)", Elapsed(Start)));
EndProcedure

// Вывод списка имен и номеров экспортных процедур из этого модуля
// Например, для данной процедуры будет выведено:
// Example
// 2
Procedure Example2() Export
	Regex = Build("Procedure (\w*)(\d*)\(\) Export");
	Reader = New TextReader;
	Reader.Open("ObjectModule.bsl");
	Start = CurrentUniversalDateInMilliseconds();
	Str = Reader.ReadLine();
	While Str <> Undefined Do
		If Match(Regex, Str) Then
			Captures = Captures(Regex);
			For Each Item In Captures Do
				Message(Mid(Str, Item.Pos, Item.Len));
			EndDo;
		EndIf;
		Str = Reader.ReadLine();
	EndDo;
	Message(StrTemplate("Example2 - Completed (%1 sec)", Elapsed(Start)));
EndProcedure

// Вывод списка простых условий на равенство. Это пример вложенных захватов.
// Например, для кода 'ElsIf Char = "d" Then' будет выведено:
// Char
// "d"
// Char = "d"
Procedure Example3() Export
	Regex = Build(".*If\s+((\S+)\s*=\s*(\S+))\s*Then.*");
	Reader = New TextReader;
	Reader.Open("ObjectModule.bsl");
	Start = CurrentUniversalDateInMilliseconds();
	Str = Reader.ReadLine();
	While Str <> Undefined Do
		If Match(Regex, Str) Then
			Captures = Captures(Regex);
			For Each Item In Captures Do
				Message(Mid(Str, Item.Pos, Item.Len));
			EndDo;
			Message(Chars.LF);
		EndIf;
		Str = Reader.ReadLine();
	EndDo;
	Message(StrTemplate("Example3 - Completed (%1 sec)", Elapsed(Start)));
EndProcedure

// Поиск первого совпадения с регулярным выражением. Это пример использования Search().
// Будет выведено:
// `Example4() Export`
Procedure Example4() Export
	Regex = Build("Example4.*Export");
	Reader = New TextReader;
	Reader.Open("ObjectModule.bsl");
	Str = Reader.Read();
	Start = CurrentUniversalDateInMilliseconds();
	Capture = Search(Regex, Str);
	If Capture = Undefined Then
		Message("fail");
	Else
		Message("`" + Mid(Str, Capture.Pos, Capture.Len) + "`");
	EndIf;
	Message(StrTemplate("Example4 - Completed (%1 sec)", Elapsed(Start)));
EndProcedure

#EndRegion // Examples