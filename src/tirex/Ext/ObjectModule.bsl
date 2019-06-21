#Region Public

// Function - Проверяет соответствует ли строка регулярному выражению
// Сопоставление выполняется обходом в глубину с мемоизацией.
//
// Не тестировалось. Использовать в бою нельзя.
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

// Альтернативное сопоставление обходом в ширину.
// В текущей реализации не позволяет получить захваты.
//
// Не тестировалось. Использовать в бою нельзя.
//
// Parameters:
//  Regex	 - Array - скомпилированная функцией Build() регулярка 
//  Str		 - String - проверяемая строка 
// 
// Returns:
//  Boolean - признак что строка соответствует регулярному выражению
//
Function Match2(Regex, Str) Export
	List = New Array; NewList = New Array;
	List.Add(1);
	For Pos = 1 To StrLen(Str) + 1 Do
		Char = Mid(Str, Pos, 1);
		For Each Target In List Do
			While Target <> Undefined Do 
				Node = Regex[Target];
				Targets = Node[Char];
				If Targets = Undefined Then
					Targets = Node["any"]; // разрешен любой символ?  
				EndIf;
				If Targets <> Undefined Then
					For Each Target In Targets Do
						If NewList.Find(Target) = Undefined Then
							NewList.Add(Target);
						EndIf; 
					EndDo;
				EndIf;	
				Target = Node["next"]; // можно пропустить без поглощения символа?
			EndDo; 
		EndDo;
		Temp = List;
		List = NewList;
		NewList = Temp;
		NewList.Clear();
	EndDo;
	For Each Target In List Do
		If Regex[Target]["end"] = True Then
			Return True;
		EndIf; 
	EndDo; 
	Return False;
EndFunction

// Function - Возвращает скомпилированную регулярку
//
// Не тестировалось. Использовать в бою нельзя.
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
//		.  - любой символ
//		*  - замыкание Клини
//		?  - один или ничего
//		() - захваты
//		[] - один символ из набора
//		_  - включить/выключить режим case insensitive
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
	While True Do
		If CharSet = "\" Then	
			CharSet = CharSet(Lexer, NextChar(Lexer));
			AddArrows(Lexer, Node, CharSet, Regex.Count());
		ElsIf CharSet = "[" Then
			List = New Array;
			CharSet = NextChar(Lexer);
			While CharSet <> "]" Do
				If CharSet = "\" Then
					CharSet = CharSet(Lexer, NextChar(Lexer));
				EndIf;
				If CharSet = "" Then
					Raise "expected ']'";
				EndIf;
				List.Add(CharSet);
				CharSet = NextChar(Lexer);
			EndDo;
			CharSet = StrConcat(List);
			AddArrows(Lexer, Node, CharSet, Regex.Count());
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
			Node["--"] = Count;
			Balance = Balance - Count;
		ElsIf CharSet = "_" Then
			Lexer.IgnoreCase = Not Lexer.IgnoreCase;
			CharSet = NextChar(Lexer);
			Continue;
		ElsIf CharSet = "*" Or CharSet = "?" Then
			Raise StrTemplate("unexpected character '%1' in position '%2'", CharSet, Lexer.Pos);
		ElsIf CharSet = "" Then 
			Targets(Node, "").Add(Regex.Count());
			Break;
		EndIf;
		NextChar = NextChar(Lexer); 
		If NextChar = "*" Then
			AddArrows(Lexer, Node, CharSet, Regex.Count() - 1);
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
		If CharSet = ")" Then
			Count = 0;
			While CharSet = ")" Do
				Count = Count + 1;
				CharSet = NextChar(Lexer);
			EndDo;
			Node["--"] = Count;
			Balance = Balance - Count;
		EndIf;
		Node = NewNode(Regex); 
		Lexer.Complement = False;
	EndDo;
	If Balance <> 0 Then
		Raise "unbalanced brackets"
	EndIf; 
	Node = NewNode(Regex);
	Node["end"] = True; // разрешенное конечное состояние
	Return Regex;
EndFunction 

// Function - Возвращает захваченные диапазоны из регулярки
//
// Не тестировалось. Использовать в бою нельзя.
//
// Parameters:
//  Regex	 - Array - регулярка после выполнения на ней Match() 
// 
// Returns:
//  Array - список захваченных диапазонов
//
Function Captures(Regex) Export
	Captures = New Array;
	Stack = New Map;
	Level = 0;
	For Each Node In Regex Do
		Pos = Node["pos"]; 
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
				Captures.Add(New Structure("Beg, End", Stack[Level], Pos));
				Level = Level - 1;
			EndDo;
		EndIf; 
	EndDo;
	Return Captures;
EndFunction

#EndRegion // Public

#Region Private

Function MatchRecursive(Regex, Memo, Str, Val Index = 1, Val Pos = 1)
	Node = Regex[Index];		
	NodeMemo = Memo[Index];
	If NodeMemo.Find(Pos) <> Undefined Then
		Return False;
	EndIf; 	
	Char = Mid(Str, Pos, 1);	
	Index = Node["next"]; // можно пропустить без поглощения символа?
	If Index = Undefined Then
		Node["pos"] = Pos;
	Else
		Node["pos"] = Pos - 1;
		If MatchRecursive(Regex, Memo, Str, Index, Pos) Then // попытка сопоставить символ со следующим узлом
			Return True;
		EndIf; 
	EndIf;
	Targets = Node[Char];
	If Targets = Undefined Then
		Targets = Node["any"]; // разрешен любой символ?  
	EndIf;	
	If Targets <> Undefined Then
		For Each Index In Targets Do
			If MatchRecursive(Regex, Memo, Str, Index, Pos + 1) Then
				Return True;
			EndIf; 
		EndDo;
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
	If CharSet = "." Then
		Targets(Node, "any").Add(Target); // стрелка для любого символа
		Targets(Node, "").Add(0);         // кроме конца текста
	Else
		If Lexer.Complement Then
			Targets(Node, "any").Add(Target);
			Target = 0; // стрелка на нулевой узел (запрещенное состояние)
		EndIf;
		For Num = 1 To Max(1, StrLen(CharSet)) Do
			Char = Mid(CharSet, Num, 1); 
			If Lexer.IgnoreCase Then
				Targets(Node, Lower(Char)).Add(Target);
				Targets(Node, Upper(Char)).Add(Target);
			Else
				Targets(Node, Char).Add(Target);
			EndIf;
		EndDo;
	EndIf; 
EndProcedure 

Function Targets(Node, Key)
	Targets = Node[Key];
	If Targets = Undefined Then
		Targets = New Array;
		Node[Key] = Targets;
	EndIf; 
	Return Targets;
EndFunction  

#EndRegion // Private

#Region Tests

Procedure RunAllTests() Export
	Test1();
	Test2();
	Test3();
	Test4();
	Test5();
	Test6();
	Test7();
	Test8();
	Test9();
	Test10();
	Test11();
	Test12();
	Test13();
EndProcedure

Function Elapsed(Start)
	Return (CurrentUniversalDateInMilliseconds() - Start) / 1000;
EndFunction

Procedure Test1() Export
	Regex = Build(".*_world_.*my \w*");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "World in my eyes");
	Message(StrTemplate("Test1 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test2() Export
	Regex = Build(".*_world_.*my \w*");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "Word in my eyes");
	Message(StrTemplate("Test2 - %1 (%2 sec)", ?(Ok, "Failed", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test3() Export
	Regex = Build("a*a*a*a*a*a*a*a*a*a*a*a*a*a*aaaaaaaaaaaaaaa");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "aaaaaaaaaaaaaa");
	Message(StrTemplate("Test3 - %1 (%2 sec)", ?(Ok, "Failed", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test4() Export
	Regex = Build("\W*digits");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "123456789digits");
	Message(StrTemplate("Test4 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test5() Export
	Regex = Build("\w*digits");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "123456789digits");
	Message(StrTemplate("Test5 - %1 (%2 sec)", ?(Ok, "Failed", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test6() Export
	Regex = Build("_Case_.*_When_.*_Then_.*_Else_.*END");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "CASE Value WHEN 1 THEN '1' ELSE '0' END");
	Message(StrTemplate("Test6 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test7() Export
	Regex = Build("_\SoRd*_");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "wordDDD");
	Message(StrTemplate("Test7 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test8() Export
	Regex = Build("word[147]*word1");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word1417word1");
	Message(StrTemplate("Test8 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test9() Export
	Regex = Build("word[147]*word1");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word14217word1");
	Message(StrTemplate("Test9 - %1 (%2 sec)", ?(Ok, "Failed", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test10() Export
	Regex = Build("word[\d]*word1");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word14217word1");
	Message(StrTemplate("Test10 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test11() Export
	Regex = Build("word[\D]*word1");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "word14217word1");
	Message(StrTemplate("Test11 - %1 (%2 sec)", ?(Ok, "Failed", "Passed"), Elapsed(Start)));
EndProcedure

Procedure Test12() Export
	Regex = Build("word[\D]*word1");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "wordword1");
	Message(StrTemplate("Test12 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

Procedure Test13() Export
	Regex = Build("If.*(_then_).*_ENDIF_;");
	Start = CurrentUniversalDateInMilliseconds();
	Ok = Match(Regex, "If x > 0 Then x = 0 EndIf;");
	Message(StrTemplate("Test13 - %1 (%2 sec)", ?(Ok, "Passed", "Failed"), Elapsed(Start)));
EndProcedure

#EndRegion // Tests