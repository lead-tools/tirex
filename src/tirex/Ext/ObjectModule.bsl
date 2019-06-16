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
	AlphaSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZабвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ";
	DigitSet = "0123456789";
	SpaceSet = " " + Chars.NBSp + Chars.Tab + Chars.LF;
	Regex = New Array;
	Pos = 1; CharSet = Mid(Pattern, Pos, 1); // first char
	Balance = 0;
	IgnoreCase = False;
	Complement = False;
	Map = New Map; Regex.Add(Map); // null node
	Map = New Map; Regex.Add(Map); // first node
	While True Do
		If CharSet = "\" Then
			Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char	
			If CharSet = "n" Then
				CharSet = Chars.LF;
			ElsIf CharSet = "w" Then
				CharSet = AlphaSet;
			ElsIf CharSet = "d" Then
				CharSet = DigitSet;
			ElsIf CharSet = "s" Then
				CharSet = SpaceSet; 
			ElsIf CharSet = "W" Then
				CharSet = AlphaSet;
				Complement = True;
			ElsIf CharSet = "D" Then
				CharSet = DigitSet;
				Complement = True;
			ElsIf CharSet = "S" Then
				CharSet = SpaceSet;
				Complement = True;
			EndIf;
			AddArrows(Map, CharSet, Regex.Count(), IgnoreCase, Complement);
		ElsIf CharSet = "[" Then
			List = New Array;
			Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
			While CharSet <> "]" Do
				If CharSet = "\" Then
					Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
				EndIf;
				If CharSet = "" Then
					Raise "Expected ']'";
				EndIf;
				List.Add(CharSet);
				Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
			EndDo;
			CharSet = StrConcat(List);
			AddArrows(Map, CharSet, Regex.Count(), IgnoreCase, Complement);
		ElsIf CharSet = "." Then
			List = New Array;
			List.Add(Regex.Count()); // arrow for any char
			Map["any"] = List;
		ElsIf CharSet = "_" Then
			IgnoreCase = Not IgnoreCase;
			Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
			Continue;
		ElsIf CharSet = "(" Then
			Count = 0;
			While CharSet = "(" Do
				Count = Count + 1;
				Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
			EndDo;
			Balance = Balance + Count;
			Map["++"] = Count;
			Map["next"] = Regex.Count();
			Map = New Map; Regex.Add(Map); // new node
			Continue;
		ElsIf CharSet = "*" Or CharSet = "?" Then
			Raise StrTemplate("unexpected character '%1' in position '%2'", CharSet, Pos);
		ElsIf CharSet = "" Then
			List = New Array;
			List.Add(Regex.Count());
			Map[""] = List; 
			Break;
		Else
			AddArrows(Map, CharSet, Regex.Count(), IgnoreCase, Complement);
		EndIf;
		Pos = Pos + 1; NextChar = Mid(Pattern, Pos, 1); // next char
		If NextChar = "*" Then
			AddArrows(Map, CharSet, Regex.Count() - 1, IgnoreCase, Complement);
			Map["next"] = Regex.Count();
			Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
		ElsIf NextChar = "?" Then
			Map["next"] = Regex.Count();
			Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
		Else
			CharSet = NextChar;
		EndIf;
		If CharSet = ")" Then
			Count = 0;
			While CharSet = ")" Do
				Count = Count + 1;
				Pos = Pos + 1; CharSet = Mid(Pattern, Pos, 1); // next char
			EndDo;
			Map["--"] = Count;
			Balance = Balance - Count;
		EndIf;
		Map = New Map; Regex.Add(Map); // new node 
		Complement = False;
	EndDo;
	If Balance <> 0 Then
		Raise "unbalanced brackets"
	EndIf; 
	Map = New Map; Regex.Add(Map); // new node
	Map["end"] = True; // end state	
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
				Captures.Add(New Structure("Beg, End", Stack[Level], Pos ));
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
		Index = Map["next"];
		If Index <> Undefined Then
			Map["pos"] = Pos - 1;
			Goto ~init;
		EndIf; 
		Targets = Map["any"]; // any char
		If Targets = Undefined Then
			Return Map["end"] = True; // end
		EndIf; 
	EndIf; 
	Map["pos"] = Pos;
	For Each Index In Targets Do
		If MatchRecursive(Regex, Str, Index, Pos + 1) Then
			Return True;
		EndIf; 
	EndDo;
	Index = Map["next"];
	If Index <> Undefined Then
		Return MatchRecursive(Regex, Str, Index, Pos)
	EndIf; 
	Return False;
EndFunction

Procedure AddArrows(Map, CharSet, Val Target, IgnoreCase = False, Complement = False)
	If Complement Then
		Targets(Map, "any").Add(Target);
		Target = 0; // arrow to null
	EndIf;
	For Num = 1 To Max(1, StrLen(CharSet)) Do
		Char = Mid(CharSet, Num, 1); 
		If IgnoreCase Then
			Targets(Map, Lower(Char)).Add(Target);
			Targets(Map, Upper(Char)).Add(Target);
		Else
			Targets(Map, Char).Add(Target);
		EndIf;
	EndDo;
EndProcedure 

Function Targets(Map, Char)
	Targets = Map[Char];
	If Targets = Undefined Then
		Targets = New Array;
		Map[Char] = Targets;
	EndIf; 
	Return Targets;
EndFunction  

#EndRegion // Private