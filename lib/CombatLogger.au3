#include-once

; Combat coordinate logger: one player X/Y at combat start and one at combat end.
; Does not log per-enemy positions.

Global $g_i_LoggedCount = 0
Global $g_s_LogFile = ""
Global $g_s_LogDirectory = "logs"
Global $g_f_AggroRange = 1320
Global $g_f_FightRangeOut = 3500
Global $g_f_CombatRadius = 500
Global $g_i_CombatEndGraceMs = 1500

Global $g_b_InCombat = False
Global $g_h_CombatClearTimer = 0
Global $g_f_CombatStartX = 0
Global $g_f_CombatStartY = 0
Global $g_b_CombatLogEnabled = False
Global $g_s_CaravanLogStartMap = "DeldrimorBowl"
Global $g_s_MapCoordLogFile = ""
Global $g_i_MapCoordLoggedCount = 0

Func CombatLogger_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"

	$g_s_LogDirectory = IniRead($a_s_ConfigPath, "Log", "Directory", "logs")
	$g_s_CaravanLogStartMap = IniRead($a_s_ConfigPath, "Log", "CaravanLogStartMap", "DeldrimorBowl")
	$g_f_AggroRange = Number(IniRead($a_s_ConfigPath, "Combat", "AggroRange", "1320"))
	$g_f_FightRangeOut = Number(IniRead($a_s_ConfigPath, "Combat", "FightRangeOut", "3500"))
	$g_f_CombatRadius = Number(IniRead($a_s_ConfigPath, "Combat", "CombatRadius", "500"))
	$g_i_CombatEndGraceMs = Number(IniRead($a_s_ConfigPath, "Combat", "CombatEndGraceMs", "1500"))

	If $g_f_AggroRange <= 0 Then $g_f_AggroRange = 1320
	If $g_f_FightRangeOut <= 0 Then $g_f_FightRangeOut = 3500
	If $g_f_CombatRadius <= 0 Then $g_f_CombatRadius = 500
	If $g_i_CombatEndGraceMs < 0 Then $g_i_CombatEndGraceMs = 1500
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
	Local $l_b_PlayerAttacking = Agent_GetAgentInfo(-2, "IsAttacking")
	Local $l_i_CurrentTarget = Agent_GetCurrentTarget()
	Local $l_a_Agents = Agent_GetAgentArray(0xDB)

	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return False

	For $i = 1 To $l_a_Agents[0]
		Local $l_p_Agent = $l_a_Agents[$i]
		If $l_p_Agent = 0 Then ContinueLoop

		Local $l_i_ID = Agent_GetAgentInfo($l_p_Agent, "ID")
		If $l_i_ID = 0 Or $l_i_ID = Agent_GetMyID() Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "Allegiance") <> 3 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "HP") <= 0 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "IsDead") Then ContinueLoop

		Local $l_f_Dist = Agent_GetDistance($l_p_Agent, -2)
		If $l_f_Dist > $g_f_FightRangeOut Then ContinueLoop

		If $l_i_CurrentTarget <> 0 And $l_i_ID = $l_i_CurrentTarget Then Return True
		If $l_b_PlayerAttacking And $l_f_Dist <= $g_f_AggroRange Then Return True
		If Agent_GetAgentInfo($l_p_Agent, "IsAttacking") And $l_f_Dist <= $g_f_AggroRange Then Return True
	Next

	Return False
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
