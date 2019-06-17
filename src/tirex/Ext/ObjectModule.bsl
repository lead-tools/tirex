#Region Public

// Function - Проверяет соответствует ли строка регулярному выражению
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
	Return MatchRecursive(Regex, Str, 1, 1);
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
			CharSet = CharSet(Lexer, NextChar(Lexer, True));
			AddArrows(Lexer, Node, CharSet, Regex.Count());
		ElsIf CharSet = "[" Then
			List = New Array;
			CharSet = NextChar(Lexer);
			While CharSet <> "]" Do
				If CharSet = "\" Then
					CharSet = CharSet(Lexer, NextChar(Lexer, True));
				EndIf;
				If CharSet = "" Then
					Raise "expected ']'";
				EndIf;
				List.Add(CharSet);
				CharSet = NextChar(Lexer);
			EndDo;
			CharSet = StrConcat(List);
			AddArrows(Lexer, Node, CharSet, Regex.Count());
		ElsIf CharSet = "." Then
			Targets(Node, "any").Add(Regex.Count()); // стрелка для любого символа
			Targets(Node, "").Add(0); // кроме конца текста
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
		ElsIf CharSet = "*" Or CharSet = "?" Then
			Raise StrTemplate("unexpected character '%1' in position '%2'", CharSet, Lexer.Pos);
		ElsIf CharSet = "" Then 
			Targets(Node, "").Add(Regex.Count());
			Break;
		Else
			AddArrows(Lexer, Node, CharSet, Regex.Count());
		EndIf;
		NextChar = NextChar(Lexer); 
		If NextChar = "*" Then
			If CharSet = "." Then
				Targets(Node, "any").Add(Regex.Count() - 1);
			Else
				AddArrows(Lexer, Node, CharSet, Regex.Count() - 1);
			EndIf; 
			Node["next"] = Regex.Count();
			CharSet = NextChar(Lexer);
		ElsIf NextChar = "?" Then
			Node["next"] = Regex.Count();
			CharSet = NextChar(Lexer);
		Else
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

Function MatchRecursive(Regex, Str, Val Index = 1, Val Pos = 1)
	~init:
	Map = Regex[Index];
	Char = Mid(Str, Pos, 1);
	Targets = Map[Char];
	If Targets = Undefined Then
		Targets = Map["any"]; // разрешен любой символ?
		If Targets = Undefined Then
			Index = Map["next"]; // можно пропустить без поглощения символа?
			If Index <> Undefined Then
				Map["pos"] = Pos - 1;
				Goto ~init; // попытка сопоставить символ со следующим узлом
			EndIf;
			Return Map["end"] = True; // это разрешенное конечное состояние?
		EndIf;  
	EndIf; 
	Map["pos"] = Pos;
	// эмуляция NFA
	// выполняется попытка сопоставления в каждом из миров
	For Each Index In Targets Do
		If MatchRecursive(Regex, Str, Index, Pos + 1) Then
			Return True;
		EndIf; 
	EndDo;
	Index = Map["next"]; // можно пропустить без поглощения символа?
	If Index <> Undefined Then
		Return MatchRecursive(Regex, Str, Index, Pos)
	EndIf; 
	Return False;
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

Function NextChar(Lexer, Escape = False)
	Lexer.Pos = Lexer.Pos + 1;
	Char = Mid(Lexer.Pattern, Lexer.Pos, 1);
	If Not Escape Then
		While Char = "_" Do
			Lexer.IgnoreCase = Not Lexer.IgnoreCase;
			Lexer.Pos = Lexer.Pos + 1;
			Char = Mid(Lexer.Pattern, Lexer.Pos, 1); // next char
		EndDo; 
	EndIf;
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
		Complement = True;
	ElsIf Char = "D" Then
		CharSet = Lexer.DigitSet;
		Complement = True;
	ElsIf Char = "S" Then
		CharSet = Lexer.SpaceSet;
		Complement = True;
	Else
		CharSet = Char;
	EndIf;
	Return CharSet;
EndFunction

Procedure AddArrows(Lexer, Node, CharSet, Val Target)
	If Lexer.Complement Then
		Targets(Node, "any").Add(Target);
		Target = 0; // arrow to null
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