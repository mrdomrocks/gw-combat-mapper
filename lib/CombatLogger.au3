#include-once
#include "Combat.au3"

; Combat coordinate logger: one player X/Y at combat start and one at combat end.
; Does not log per-enemy positions.

Global $g_i_LoggedCount = 0
Global $g_s_LogFile = ""
Global $g_s_LogDirectory = "logs"
Global $g_f_CombatRadius = 500

Global $g_b_InCombat = False
Global $g_h_CombatClearTimer = 0
Global $g_f_CombatStartX = 0
Global $g_f_CombatStartY = 0
Global $g_b_CombatLogEnabled = False
Global $g_s_CaravanLogStartMap = "DeldrimorBowl"
Global $g_s_MapCoordLogFile = ""
Global $g_i_MapCoordLoggedCount = 0
Global $g_s_StuckLogFile = ""
Global $g_i_StuckLoggedCount = 0
Global $g_i_StuckLogMapID = 0
Global $g_f_StuckLastX = 0
Global $g_f_StuckLastY = 0
Global $g_h_StuckLastTimer = 0
Global Const $GC_F_STUCK_LOG_DEDUP_DIST = 200
Global Const $GC_I_STUCK_LOG_DEDUP_MS = 4000

Func CombatLogger_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"

	Combat_LoadConfig($a_s_ConfigPath)
	$g_s_LogDirectory = IniRead($a_s_ConfigPath, "Log", "Directory", "logs")
	$g_s_CaravanLogStartMap = IniRead($a_s_ConfigPath, "Log", "CaravanLogStartMap", "DeldrimorBowl")
	$g_f_CombatRadius = Number(IniRead($a_s_ConfigPath, "Combat", "CombatRadius", "500"))

	If $g_f_CombatRadius <= 0 Then $g_f_CombatRadius = 500
	If $g_s_CaravanLogStartMap = "" Then $g_s_CaravanLogStartMap = "DeldrimorBowl"
EndFunc

Func CombatLogger_IsSessionActive()
	Return $g_b_CombatLogEnabled And $g_s_LogFile <> ""
EndFunc

Func CombatLogger_StartSession()
	CombatLogger_LoadConfig()

	If Not FileExists(@ScriptDir & "\" & $g_s_LogDirectory) Then
		DirCreate(@ScriptDir & "\" & $g_s_LogDirectory)
	EndIf

	Local $l_i_MapID = Map_GetMapID()
	Local $l_s_Stamp = @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC
	$g_s_LogFile = @ScriptDir & "\" & $g_s_LogDirectory & "\combat_coords_" & $l_i_MapID & "_" & $l_s_Stamp & ".csv"

	Local $l_h = FileOpen($g_s_LogFile, $FO_OVERWRITE + $FO_CREATEPATH)
	If $l_h = -1 Then
		Out("ERROR: Could not create log file: " & $g_s_LogFile)
		$g_b_CombatLogEnabled = False
		Return False
	EndIf
	FileWriteLine($l_h, "timestamp,map_id,event,x,y")
	FileClose($l_h)

	$g_i_LoggedCount = 0
	$g_b_InCombat = False
	$g_h_CombatClearTimer = 0
	$g_f_CombatStartX = 0
	$g_f_CombatStartY = 0
	$g_b_CombatLogEnabled = True

	Out("Logging combat start/end coords to: " & $g_s_LogFile)
	Return True
EndFunc

Func CombatLogger_StopSession()
	CombatLogger_FlushIfInCombat()
	$g_b_CombatLogEnabled = False
	$g_s_LogFile = ""
EndFunc

Func CombatLogger_AppendEvent($a_s_Event, $a_f_X, $a_f_Y)
	If $g_s_LogFile = "" Then Return False

	Local $l_s_Ts = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
	Local $l_s_Line = $l_s_Ts & "," & Map_GetMapID() & "," & $a_s_Event & "," & _
		Round($a_f_X, 2) & "," & Round($a_f_Y, 2)

	Local $l_h = FileOpen($g_s_LogFile, $FO_APPEND)
	If $l_h = -1 Then Return False
	FileWriteLine($l_h, $l_s_Line)
	FileClose($l_h)

	$g_i_LoggedCount += 1
	Return True
EndFunc

; True if any living enemy is currently engaging us.
Func CombatLogger_IsCombatActive()
	Return Combat_IsEngaged()
EndFunc

; Pathfinder_MoveTo CallFunc — log player X/Y once at combat start and once at combat end.
Func CombatLogger_Tick()
	If Not $g_b_CombatLogEnabled Or $g_s_LogFile = "" Then Return

	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	Local $l_b_Active = CombatLogger_IsCombatActive()

	If $l_b_Active Then
		$g_h_CombatClearTimer = 0
		If Not $g_b_InCombat Then
			$g_b_InCombat = True
			$g_f_CombatStartX = $l_f_X
			$g_f_CombatStartY = $l_f_Y
			If CombatLogger_AppendEvent("combat_start", $l_f_X, $l_f_Y) Then
				Out("Combat START @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ") events=" & $g_i_LoggedCount)
			EndIf
		EndIf
		Return
	EndIf

	; No active combat: if we were in combat, wait grace period then log end.
	If Not $g_b_InCombat Then Return

	If $g_h_CombatClearTimer = 0 Then
		$g_h_CombatClearTimer = TimerInit()
		Return
	EndIf

	If TimerDiff($g_h_CombatClearTimer) < $g_i_CombatEndGraceMs Then Return

	$g_b_InCombat = False
	$g_h_CombatClearTimer = 0
	If CombatLogger_AppendEvent("combat_end", $l_f_X, $l_f_Y) Then
		Out("Combat END @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ") " & _
			"(started " & Round($g_f_CombatStartX) & "," & Round($g_f_CombatStartY) & ") events=" & $g_i_LoggedCount)
	EndIf
EndFunc

Func CombatLogger_FlushIfInCombat()
	If Not $g_b_InCombat Or $g_s_LogFile = "" Then Return
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	$g_b_InCombat = False
	$g_h_CombatClearTimer = 0
	If CombatLogger_AppendEvent("combat_end", $l_f_X, $l_f_Y) Then
		Out("Combat END (flush) @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ") events=" & $g_i_LoggedCount)
	EndIf
EndFunc

Func CombatLogger_GetCount()
	Return $g_i_LoggedCount
EndFunc

Func CombatLogger_GetLogFile()
	Return $g_s_LogFile
EndFunc

; Manual map waypoint log (player position) — append to logs/map_waypoints_<mapid>.csv
Func CombatLogger_EnsureMapCoordLog()
	CombatLogger_LoadConfig()

	If Not FileExists(@ScriptDir & "\" & $g_s_LogDirectory) Then
		DirCreate(@ScriptDir & "\" & $g_s_LogDirectory)
	EndIf

	Local $l_i_MapID = Map_GetMapID()
	If $l_i_MapID <= 0 Then
		Out("Log XY: MapID is " & $l_i_MapID & " (character not loaded on a map?)")
		Return False
	EndIf

	Local $l_s_Path = @ScriptDir & "\" & $g_s_LogDirectory & "\map_waypoints_" & $l_i_MapID & ".csv"
	If $g_s_MapCoordLogFile <> $l_s_Path Then
		$g_s_MapCoordLogFile = $l_s_Path
		$g_i_MapCoordLoggedCount = 0
		If Not FileExists($l_s_Path) Then
			Local $l_h = FileOpen($l_s_Path, $FO_OVERWRITE + $FO_CREATEPATH)
			If $l_h = -1 Then
				Out("Log XY: could not create " & $l_s_Path)
				Return False
			EndIf
			FileWriteLine($l_h, "timestamp,map_id,label,x,y")
			FileClose($l_h)
		EndIf
	EndIf
	Return True
EndFunc

Func CombatLogger_LogMapCoord($a_s_Label = "manual")
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	If $l_f_X = 0 And $l_f_Y = 0 Then
		Out("Log XY: player XY is 0,0 (not in a map / not attached?)")
		Return False
	EndIf
	If Not CombatLogger_EnsureMapCoordLog() Then Return False

	Local $l_s_Ts = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
	Local $l_i_Map = Map_GetMapID()
	Local $l_s_Line = $l_s_Ts & "," & $l_i_Map & "," & $a_s_Label & "," & _
		Round($l_f_X, 2) & "," & Round($l_f_Y, 2)

	Local $l_h = FileOpen($g_s_MapCoordLogFile, $FO_APPEND + $FO_CREATEPATH)
	If $l_h = -1 Then
		Out("Log XY: could not append to " & $g_s_MapCoordLogFile)
		Return False
	EndIf
	FileWriteLine($l_h, $l_s_Line)
	FileClose($l_h)

	$g_i_MapCoordLoggedCount += 1
	Return True
EndFunc

Func CombatLogger_GetMapCoordLogFile()
	Return $g_s_MapCoordLogFile
EndFunc

Func CombatLogger_GetMapCoordCount()
	Return $g_i_MapCoordLoggedCount
EndFunc

; Pathfinder stuck spots — append to logs/pathfinder_stuck_<mapid>.csv (same columns as combat logs).
Func CombatLogger_EnsureStuckLog()
	CombatLogger_LoadConfig()

	If Not FileExists(@ScriptDir & "\" & $g_s_LogDirectory) Then
		DirCreate(@ScriptDir & "\" & $g_s_LogDirectory)
	EndIf

	Local $l_i_MapID = Map_GetMapID()
	If $l_i_MapID <= 0 Then Return False

	Local $l_s_Path = @ScriptDir & "\" & $g_s_LogDirectory & "\pathfinder_stuck_" & $l_i_MapID & ".csv"
	If $g_s_StuckLogFile <> $l_s_Path Then
		$g_s_StuckLogFile = $l_s_Path
		$g_i_StuckLoggedCount = 0
		$g_i_StuckLogMapID = $l_i_MapID
		$g_h_StuckLastTimer = 0
		If Not FileExists($l_s_Path) Then
			Local $l_h = FileOpen($l_s_Path, $FO_OVERWRITE + $FO_CREATEPATH)
			If $l_h = -1 Then
				Out("Stuck log: could not create " & $l_s_Path)
				Return False
			EndIf
			FileWriteLine($l_h, "timestamp,map_id,event,x,y")
			FileClose($l_h)
			Out("Pathfinder stuck log: " & $l_s_Path)
		EndIf
	EndIf
	Return True
EndFunc

Func CombatLogger_LogStuck($a_s_Event = "stuck", $a_f_X = Default, $a_f_Y = Default)
	Local $l_f_X = $a_f_X
	Local $l_f_Y = $a_f_Y
	If $l_f_X = Default Or $l_f_Y = Default Then
		$l_f_X = Agent_GetAgentInfo(-2, "X")
		$l_f_Y = Agent_GetAgentInfo(-2, "Y")
	EndIf
	If $l_f_X = 0 And $l_f_Y = 0 Then Return False
	If Not CombatLogger_EnsureStuckLog() Then Return False

	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map = $g_i_StuckLogMapID And $g_h_StuckLastTimer <> 0 Then
		Local $l_f_Dx = $l_f_X - $g_f_StuckLastX
		Local $l_f_Dy = $l_f_Y - $g_f_StuckLastY
		If Sqrt($l_f_Dx * $l_f_Dx + $l_f_Dy * $l_f_Dy) < $GC_F_STUCK_LOG_DEDUP_DIST _
			And TimerDiff($g_h_StuckLastTimer) < $GC_I_STUCK_LOG_DEDUP_MS Then
			Return True
		EndIf
	EndIf

	Local $l_s_Ts = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
	Local $l_s_Line = $l_s_Ts & "," & $l_i_Map & "," & $a_s_Event & "," & _
		Round($l_f_X, 2) & "," & Round($l_f_Y, 2)

	Local $l_h = FileOpen($g_s_StuckLogFile, $FO_APPEND + $FO_CREATEPATH)
	If $l_h = -1 Then
		Out("Stuck log: could not append to " & $g_s_StuckLogFile)
		Return False
	EndIf
	FileWriteLine($l_h, $l_s_Line)
	FileClose($l_h)

	$g_i_StuckLoggedCount += 1
	$g_i_StuckLogMapID = $l_i_Map
	$g_f_StuckLastX = $l_f_X
	$g_f_StuckLastY = $l_f_Y
	$g_h_StuckLastTimer = TimerInit()
	If $g_i_StuckLoggedCount = 1 Then Out("Pathfinder stuck log: " & $g_s_StuckLogFile)
	Return True
EndFunc

Func CombatLogger_GetStuckLogFile()
	Return $g_s_StuckLogFile
EndFunc

Func CombatLogger_GetStuckCount()
	Return $g_i_StuckLoggedCount
EndFunc
