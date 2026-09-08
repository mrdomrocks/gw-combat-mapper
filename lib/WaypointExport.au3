#include-once

; Convert logged CSV coordinates into MVR / combat-mapper AutoIt route snippets.

Global Const $GC_S_WAYPOINT_EXPORT_DIR = @ScriptDir & "\exports"
Global Const $GC_F_WAYPOINT_EXPORT_DEDUPE = 250
Global $g_i_WaypointExportAggroRange = 1450

Func WaypointExport_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_i_WaypointExportAggroRange = Number(IniRead($a_s_ConfigPath, "Export", "AggroRange", "1450"))
	If $g_i_WaypointExportAggroRange <= 0 Then $g_i_WaypointExportAggroRange = 1450
EndFunc

Func WaypointExport_EnsureDir()
	If Not FileExists($GC_S_WAYPOINT_EXPORT_DIR) Then DirCreate($GC_S_WAYPOINT_EXPORT_DIR)
EndFunc

Func WaypointExport_Distance($a_f_X1, $a_f_Y1, $a_f_X2, $a_f_Y2)
	Local $l_f_Dx = $a_f_X1 - $a_f_X2
	Local $l_f_Dy = $a_f_Y1 - $a_f_Y2
	Return Sqrt($l_f_Dx * $l_f_Dx + $l_f_Dy * $l_f_Dy)
EndFunc

Func WaypointExport_AppendPoint(ByRef $a_a_X, ByRef $a_a_Y, ByRef $a_i_Count, $a_f_X, $a_f_Y, $a_f_Dedupe = $GC_F_WAYPOINT_EXPORT_DEDUPE)
	If $a_f_X = 0 And $a_f_Y = 0 Then Return False
	If $a_i_Count > 0 Then
		Local $l_f_D = WaypointExport_Distance($a_a_X[$a_i_Count - 1], $a_a_Y[$a_i_Count - 1], $a_f_X, $a_f_Y)
		If $l_f_D < $a_f_Dedupe Then Return False
	EndIf
	ReDim $a_a_X[$a_i_Count + 1]
	ReDim $a_a_Y[$a_i_Count + 1]
	$a_a_X[$a_i_Count] = $a_f_X
	$a_a_Y[$a_i_Count] = $a_f_Y
	$a_i_Count += 1
	Return True
EndFunc

; Parse one CSV line into x,y. Supports map_waypoints, combat_coords, combat_entities, coverage_route.
Func WaypointExport_TryParseLine($a_s_Line, ByRef $a_f_X, ByRef $a_f_Y)
	$a_f_X = 0
	$a_f_Y = 0
	Local $l_s = StringStripWS($a_s_Line, 3)
	If $l_s = "" Then Return False
	If StringLeft($l_s, 1) = "x" Then Return False

	Local $l_a = StringSplit($l_s, ",", $STR_NOCOUNT)
	If Not IsArray($l_a) Then Return False
	Local $l_i_N = UBound($l_a)
	If $l_i_N < 2 Then Return False

	Switch $l_i_N
		Case 2
			$a_f_X = Number($l_a[0])
			$a_f_Y = Number($l_a[1])
		Case 5
			; timestamp,map_id,label,x,y
			$a_f_X = Number($l_a[3])
			$a_f_Y = Number($l_a[4])
		Case Else
			; timestamp,map_id,event,x,y OR timestamp,map_id,agent_id,...,entity_x,entity_y,...
			If $l_i_N >= 5 Then
				$a_f_X = Number($l_a[$l_i_N - 2])
				$a_f_Y = Number($l_a[$l_i_N - 1])
			Else
				Return False
			EndIf
	EndSwitch
	Return Not ($a_f_X = 0 And $a_f_Y = 0)
EndFunc

Func WaypointExport_LoadCsvFile($a_s_Path, ByRef $a_a_X, ByRef $a_a_Y, ByRef $a_i_Count)
	If Not FileExists($a_s_Path) Then Return False
	Local $l_a_Lines = FileReadToArray($a_s_Path)
	If @error Or Not IsArray($l_a_Lines) Then Return False

	Local $i, $l_f_X, $l_f_Y
	For $i = 0 To UBound($l_a_Lines) - 1
		If WaypointExport_TryParseLine($l_a_Lines[$i], $l_f_X, $l_f_Y) Then
			WaypointExport_AppendPoint($a_a_X, $a_a_Y, $a_i_Count, $l_f_X, $l_f_Y)
		EndIf
	Next
	Return $a_i_Count > 0
EndFunc

Func WaypointExport_FindLogFilesForMap($a_i_MapID)
	Local $l_s_LogDir = @ScriptDir & "\logs"
	Local $l_a_Files[1]
	Local $l_i_N = 0

	Local $l_s_Fixed = $l_s_LogDir & "\map_waypoints_" & $a_i_MapID & ".csv"
	If FileExists($l_s_Fixed) Then
		ReDim $l_a_Files[$l_i_N + 1]
		$l_a_Files[$l_i_N] = $l_s_Fixed
		$l_i_N += 1
	EndIf

	Local $l_s_Search = FileFindFirstFile($l_s_LogDir & "\*_" & $a_i_MapID & "_*.csv")
	If $l_s_Search <> -1 Then
		While 1
			Local $l_s_File = FileFindNextFile($l_s_Search)
			If @error Then ExitLoop
			If StringInStr($l_s_File, ".") = 1 Then ContinueLoop
			ReDim $l_a_Files[$l_i_N + 1]
			$l_a_Files[$l_i_N] = $l_s_LogDir & "\" & $l_s_File
			$l_i_N += 1
		WEnd
		FileClose($l_s_Search)
	EndIf

	If $a_i_MapID = Map_GetMapID() And FileExists(@ScriptDir & "\coverage_route.csv") Then
		ReDim $l_a_Files[$l_i_N + 1]
		$l_a_Files[$l_i_N] = @ScriptDir & "\coverage_route.csv"
		$l_i_N += 1
	EndIf

	Return SetExtended($l_i_N, $l_a_Files)
EndFunc

Func WaypointExport_LoadFromMapID($a_i_MapID, ByRef $a_a_X, ByRef $a_a_Y, ByRef $a_i_Count)
	$a_i_Count = 0
	ReDim $a_a_X[0]
	ReDim $a_a_Y[0]

	Local $l_a_Files = WaypointExport_FindLogFilesForMap($a_i_MapID)
	Local $l_i_FileCount = @extended
	If $l_i_FileCount < 1 Then Return False

	Local $i
	For $i = 0 To $l_i_FileCount - 1
		WaypointExport_LoadCsvFile($l_a_Files[$i], $a_a_X, $a_a_Y, $a_i_Count)
	Next
	Return $a_i_Count > 0
EndFunc

Func WaypointExport_FormatCoord($a_f_X, $a_f_Y)
	If Abs($a_f_X - Round($a_f_X)) < 0.01 And Abs($a_f_Y - Round($a_f_Y)) < 0.01 Then
		Return "[" & Round($a_f_X) & ", " & Round($a_f_Y) & "]"
	EndIf
	Return "[" & Round($a_f_X, 2) & ", " & Round($a_f_Y, 2) & "]"
EndFunc

; MVR / combat-mapper vanquish row: [x, y, " ", $vqrange]
Func WaypointExport_FormatVqRow($a_f_X, $a_f_Y)
	If Abs($a_f_X - Round($a_f_X)) < 0.01 And Abs($a_f_Y - Round($a_f_Y)) < 0.01 Then
		Return "[" & Round($a_f_X) & ", " & Round($a_f_Y) & ", "" "", $vqrange]"
	EndIf
	Return "[" & Round($a_f_X, 2) & ", " & Round($a_f_Y, 2) & ", "" "", $vqrange]"
EndFunc

Func WaypointExport_BuildMvrArray($a_s_Title, ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, $a_b_Reverse = False, $a_b_FullRoute = True)
	If $a_i_Count < 1 Then Return ""

	Local $l_s = "Local $vqrange = " & $g_i_WaypointExportAggroRange & @CRLF
	$l_s &= "Local $aWaypoints[" & $a_i_Count & "][4] = [ _" & @CRLF

	Local $i, $l_i_Start, $l_i_End, $l_i_Step
	If $a_b_Reverse Then
		$l_i_Start = $a_i_Count - 1
		$l_i_End = -1
		$l_i_Step = -1
	Else
		$l_i_Start = 0
		$l_i_End = $a_i_Count
		$l_i_Step = 1
	EndIf

	For $i = $l_i_Start To $l_i_End Step $l_i_Step
		$l_s &= "		" & WaypointExport_FormatVqRow($a_a_X[$i], $a_a_Y[$i]) & ", _" & @CRLF
	Next
	$l_s = StringTrimRight(StringStripWS($l_s, 3), 2) & @CRLF & "	]" & @CRLF & @CRLF

	If $a_b_FullRoute Then
		$l_s &= "MoveandAggroVQFullRoute($aWaypoints)" & @CRLF
	Else
		$l_s &= "MoveandAggroVQ($aWaypoints)" & @CRLF
	EndIf
	Return $l_s
EndFunc

Func WaypointExport_BuildMapperArray($a_s_Title, ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count)
	If $a_i_Count < 1 Then Return ""

	Local $l_s_Var = "$a" & $a_s_Title & "Route01"
	Local $l_s = "Global $vqrange = " & $g_i_WaypointExportAggroRange & @CRLF
	$l_s &= "Global " & $l_s_Var & "[" & $a_i_Count & "][4] = [ _" & @CRLF

	Local $i
	For $i = 0 To $a_i_Count - 1
		$l_s &= "	" & WaypointExport_FormatVqRow($a_a_X[$i], $a_a_Y[$i]) & ", _" & @CRLF
	Next
	$l_s = StringTrimRight(StringStripWS($l_s, 3), 2) & @CRLF & "]"
	Return $l_s
EndFunc

Func WaypointExport_WriteFile($a_s_Path, $a_s_Content)
	WaypointExport_EnsureDir()
	Local $l_h = FileOpen($a_s_Path, $FO_OVERWRITE + $FO_CREATEPATH)
	If $l_h = -1 Then Return False
	FileWrite($l_h, $a_s_Content)
	FileClose($l_h)
	Return True
EndFunc

; Export current map logs to exports/<Title>_MVR.au3 and exports/<Title>_Route.au3
Func WaypointExport_ExportMap($a_i_MapID = -1, $a_s_Title = "", $a_b_Reverse = False)
	WaypointExport_LoadConfig()
	If $a_i_MapID < 0 Then $a_i_MapID = Map_GetMapID()
	If $a_s_Title = "" Then $a_s_Title = $g_s_CoverageMapTitle
	If $a_s_Title = "" Then $a_s_Title = "Map" & $a_i_MapID

	Local $l_a_X[0], $l_a_Y[0], $l_i_Count = 0
	If Not WaypointExport_LoadFromMapID($a_i_MapID, $l_a_X, $l_a_Y, $l_i_Count) Then
		Out("Export: no coordinates found for MapID=" & $a_i_MapID)
		Return False
	EndIf

	WaypointExport_EnsureDir()
	Local $l_s_MvrPath = $GC_S_WAYPOINT_EXPORT_DIR & "\" & $a_s_Title & "_MVR.au3"
	Local $l_s_RoutePath = $GC_S_WAYPOINT_EXPORT_DIR & "\" & $a_s_Title & "_Route.au3"
	Local $l_s_RevPath = $GC_S_WAYPOINT_EXPORT_DIR & "\" & $a_s_Title & "_MVR_Reverse.au3"

	Local $l_s_Header = "; Exported from Combat Mapper logs — MapID=" & $a_i_MapID & " points=" & $l_i_Count & @CRLF
	Local $l_s_Mvr = $l_s_Header & WaypointExport_BuildMvrArray($a_s_Title, $l_a_X, $l_a_Y, $l_i_Count, False, True)
	Local $l_s_Rev = $l_s_Header & WaypointExport_BuildMvrArray($a_s_Title, $l_a_X, $l_a_Y, $l_i_Count, True, False)
	Local $l_s_Route = $l_s_Header & WaypointExport_BuildMapperArray($a_s_Title, $l_a_X, $l_a_Y, $l_i_Count)

	If Not WaypointExport_WriteFile($l_s_MvrPath, $l_s_Mvr) Then
		Out("Export: could not write " & $l_s_MvrPath)
		Return False
	EndIf
	WaypointExport_WriteFile($l_s_RoutePath, $l_s_Route)
	If $a_b_Reverse Then WaypointExport_WriteFile($l_s_RevPath, $l_s_Rev)

	Out("Export: " & $l_i_Count & " waypoints -> " & $l_s_MvrPath)
	Out("Export: combat-mapper route -> " & $l_s_RoutePath)
	If $a_b_Reverse Then Out("Export: reverse pass -> " & $l_s_RevPath)
	Return True
EndFunc
