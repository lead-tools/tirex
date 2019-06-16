
&AtClient
Procedure MatchAtClient(Command)
	ClearMessages();
	MatchAtServer();
EndProcedure

&AtServer
Procedure MatchAtServer()
	
	Tirex = FormAttributeToValue("Object");
	
	Regex = Tirex.Build(Patt);	
	
	Ok = Tirex.Match(Regex, Text);
	
	Message(Ok);
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(, Chars.Tab));
	WriteJSON(JSONWriter, Regex);
	Graph.SetText(JSONWriter.Close());
	
	Captures = Tirex.Captures(Regex);
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
	WriteJSON(JSONWriter, Captures);
	Message(JSONWriter.Close()); 
	
EndProcedure	


