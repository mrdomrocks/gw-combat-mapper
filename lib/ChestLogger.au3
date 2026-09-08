#include-once

; Log chest spawn coordinates encountered during sweeps.

Global $g_b_ChestLoggerEnabled = False
Global $g_s_ChestLogFile = ""
Global $g_o_ChestLogged = 0
Global Const $GC_AI_CHEST_MODELS[] = [ _
	24, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657]

Func ChestLogger_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_ChestLoggerEnabled = Number(IniRead($a_s_ConfigPath, "Log", "ChestLogging", "0")) <> 0
EndFunc

Func ChestLogger_IsChestModel($a_i_ModelID)
	Local $i
	For $i = 1 To $GC_AI_CHEST_MODELS[0]
		If $GC_AI_CHEST_MODELS[$i] = $a_i_ModelID Then Return True
	Next
	Return False
EndFunc

Func ChestLogger_EnsureFile()
	If Not $g_b_ChestLoggerEnabled Then Return False
	Local $l_s_LogDir = @ScriptDir & "\logs"
	If Not FileExists($l_s_LogDir) Then DirCreate($l_s_LogDir)
	Local $l_i_Map = Map_GetMapID()
	$g_s_ChestLogFile = $l_s_LogDir & "\chest_spawns_" & $l_i_Map & ".csv"
	If Not FileExists($g_s_ChestLogFile) Then
		Local $l_h = FileOpen($g_s_ChestLogFile, $FO_OVERWRITE + $FO_CREATEPATH)
		If $l_h = -1 Then Return False
		FileWriteLine($l_h, "timestamp,map_id,model_id,x,y")
		FileClose($l_h)
		Out("Chest log: " & $g_s_ChestLogFile)
	EndIf
	If Not IsObj($g_o_ChestLogged) Then $g_o_ChestLogged = ObjCreate("Scripting.Dictionary")
	Return True
EndFunc

Func ChestLogger_Tick()
	If Not $g_b_ChestLoggerEnabled Then Return
	If Not ChestLogger_EnsureFile() Then Return

	Local $l_a_Agents = Agent_GetAgentArray(0x400)
	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return

	Local $i
	For $i = 1 To $l_a_Agents[0]
		Local $l_p_Agent = $l_a_Agents[$i]
		If $l_p_Agent = 0 Then ContinueLoop
		Local $l_i_Model = Agent_GetAgentInfo($l_p_Agent, "ModelID")
		If Not ChestLogger_IsChestModel($l_i_Model) Then ContinueLoop
		Local $l_i_ID = Agent_GetAgentInfo($l_p_Agent, "ID")
		Local $l_s_Key = String($l_i_ID)
		If $g_o_ChestLogged.Exists($l_s_Key) Then ContinueLoop

		Local $l_f_X = Agent_GetAgentInfo($l_p_Agent, "X")
		Local $l_f_Y = Agent_GetAgentInfo($l_p_Agent, "Y")
		Local $l_s_Ts = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
		Local $l_s_Line = $l_s_Ts & "," & Map_GetMapID() & "," & $l_i_Model & "," & Round($l_f_X, 2) & "," & Round($l_f_Y, 2)
		Local $l_h = FileOpen($g_s_ChestLogFile, $FO_APPEND)
		If $l_h = -1 Then Return
		FileWriteLine($l_h, $l_s_Line)
		FileClose($l_h)
		$g_o_ChestLogged.Add($l_s_Key, True)
		Out("Chest logged model=" & $l_i_Model & " @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ")")
	Next
EndFunc
