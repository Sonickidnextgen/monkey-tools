Strict

Public

' Preprocessor related:
#VIRTUAL_DIR_GEN_SMART = True

' Imports:
Import brl.stream
Import brl.filestream

Import brl.filesystem
Import brl.filepath
Import brl.process

' Aliases:
Alias FileTime_t = Int

' Constant variable(s):
Const RCODE_NORMAL:= 0
Const RCODE_ERROR:= 1

Const FILE_EXTENSION:= "dir"

' Functions:
Function Main:Int()
	Local Arguments:= AppArgs() ' ["reserved", "data", "directory.txt"]
	Local Arguments_Length:= Arguments.Length
	
	Local InPath:String, OutPath:String
	
	#If Not VIRTUAL_DIR_GEN_SMART
		If (Arguments_Length < 3) Then
			Print("Invalid number of arguments.")
			
			Return RCODE_ERROR
		Endif
		
		InPath = Arguments[1]
		OutPath = Arguments[2]
	#Else
		If (Arguments_Length < 2) Then
			InPath = CurrentDir()
		Else
			InPath = Arguments[1]
		Endif
		
		If (Arguments_Length < 3) Then
			OutPath = StripDir(InPath) + "." + FILE_EXTENSION
		Else
			OutPath = Arguments[2]
		Endif
	#End
	
	Try
		MapFileSystem(InPath, OutPath)
	Catch E:StreamError
		Print("Failed to create ~qvirtual directory~q: " + E)
		
		Return RCODE_ERROR
	End
	
	Return RCODE_NORMAL
End

Function MapFileSystem:Void(InPath:String, OutPath:String)
	Local Master:= New Folder(StripDir(InPath))
	
	For Local Entry:= Eachin LoadDir(InPath, True)
		Local RealPath:= (InPath + "/" + Entry)
		Local Parent:= GetFolderFromPath(Master, RealPath)
		Local Name:= StripDir(Entry)
		
		Select FileType(RealPath)
			Case FILETYPE_FILE
				Parent.Files.PushLast(New File(Name, FileTime(RealPath)))
			Case FILETYPE_DIR
				Parent.SubFolders.PushLast(New Folder(Name))
		End Select
	Next
	
	Local F:= FileStream.Open(OutPath, "w")
	
	WriteFileSystem(F, Master)
	
	F.Close()
	
	Return
End

Function WriteFileSystem:Void(S:Stream, F:Folder, Offset:Int=1)
	Local Base:String
	
	For Local I:= 1 Until Offset
		Base += "~t"
	Next
	
	If (Base.Length > 0) Then
		S.WriteString(Base)
	Endif
	
	S.WriteLine(F.Name)
	
	S.WriteString(Base)
	S.WriteLine("{")
	
	Local Tabs:= Base+"~t"
	
	Local Files:= F.Files
	
	If (Not Files.IsEmpty) Then
		S.WriteString(Tabs)
		S.WriteString("!")
		
		For Local I:= 0 Until (Files.Length - 1)
			WriteFileEntry(S, Files.Get(I))
			
			S.WriteString(", ")
		Next
		
		WriteFileEntry(S, Files.Get(Files.Length-1), True)
	Endif
	
	Local Folders:= F.SubFolders

	For Local F:= Eachin Folders
		WriteFileSystem(S, F, Offset+1)
	Next
	
	S.WriteString(Base)
	S.WriteLine("}")
	
	Return
End

Function WriteFileEntry:Void(S:Stream, F:File, FinishLine:Bool=False)
	S.WriteString(F.Name)
	S.WriteString("[")
	S.WriteString(String(F.Time))
	
	If (Not FinishLine) Then
		S.WriteString("]")
	Else
		S.WriteLine("]")
	Endif
	
	Return
End

Function GetFolderByName:Folder(Master:Folder, FolderName:String)
	For Local F:= Eachin Master.SubFolders
		If (F.Name = FolderName) Then
			Return F
		Endif
	Next
	
	Return Null
End

Function GetFolderFromPath:Folder(Master:Folder, Path:String)
	If (Not Path.Contains("/")) Then
		Return Master
	Endif
	
	Local Folders:= Path.Split("/")
	
	Local F:Folder = Master
	
	For Local I:= 0 Until (Folders.Length - 1)
		Local NextFolder:= GetFolderByName(F, Folders[I])
		
		If (NextFolder <> Null) Then
			F = NextFolder
		Endif
	Next
	
	Return F
End

' Classes:
Class File
	' Constructor(s):
	Method New(Name:String, Time:FileTime_t)
		Self.Name = Name
		Self.Time = Time
	End
	
	' Fields:
	Field Name:String
	Field Time:FileTime_t
End

Class Folder
	' Constructor(s):
	Method New(Name:String)
		Self.Name = Name
	End
	
	' Fields:
	Field Name:String
	Field SubFolders:= New Deque<Folder>()
	Field Files:= New Deque<File>()
End