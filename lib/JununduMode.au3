#include-once

; Simplified Junundu handling for Desolation mapping sweeps.

Global Const $GC_AS_JUNUNDU_DESOLATION_TITLES = "JokosDomain|PoisonedOutcrops|TheAlkaliPan|TheRupturedHeart|TheShatteredRavines|CrystalOverlook|TheSulfurousWastes"
Global $g_b_JununduModeEnabled = False

Func JununduMode_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_JununduModeEnabled = Number(IniRead($a_s_ConfigPath, "Junundu", "Enabled", "0")) <> 0
EndFunc

Func JununduMode_IsDesolationTitle($a_s_Title)
	If $a_s_Title = "" Then Return False
	Return StringInStr("|" & $GC_AS_JUNUNDU_DESOLATION_TITLES & "|", "|" & $a_s_Title & "|") > 0
EndFunc

Func JununduMode_PlayerInJunundu()
	Local $l_i_Model = Agent_GetAgentInfo(-2, "ModelID")
	; Junundu forms use high model IDs; also check skillbar name fallback
	If $l_i_Model >= 30000 And $l_i_Model <= 32000 Then Return True
	Local $l_s_Name = Agent_GetAgentInfo(-2, "Name")
	If StringInStr($l_s_Name, "Junundu") Then Return True
	Return False
EndFunc

Func JununduMode_HasSulfurHaze()
	Local $l_a_Effects = Effect_GetEffectsArray()
	If Not IsArray($l_a_Effects) Then Return False
	Local $i
	For $i = 1 To $l_a_Effects[0]
		Local $l_i_ID = Effect_GetEffectInfo($l_a_Effects[$i], "SkillID")
		; Sulfurous Haze / environmental debuff common IDs in GW1 automation
		If $l_i_ID = 572 Or $l_i_ID = 573 Then Return True
	Next
	Return False
EndFunc

Func JununduMode_TryMountNearby()
	Local $l_a_Agents = Agent_GetAgentArray(0x400)
	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return False

	Local $i
	For $i = 1 To $l_a_Agents[0]
		Local $l_p_Agent = $l_a_Agents[$i]
		If $l_p_Agent = 0 Then ContinueLoop
		Local $l_s_Name = Agent_GetAgentInfo($l_p_Agent, "Name")
		If StringInStr($l_s_Name, "Junundu") = 0 And StringInStr($l_s_Name, "Spoor") = 0 Then ContinueLoop
		If Agent_GetDistance($l_p_Agent, -2) > 2500 Then ContinueLoop
		Agent_Move($l_p_Agent)
		Sleep(500)
		Agent_Interact($l_p_Agent)
		Sleep(1500)
		If JununduMode_PlayerInJunundu() Then
			Out("Junundu: mounted.")
			Return True
		EndIf
	Next
	Return False
EndFunc

Func JununduMode_OnMapEnter($a_s_Title)
	If Not $g_b_JununduModeEnabled Then Return
	If Not JununduMode_IsDesolationTitle($a_s_Title) Then Return
	Out("Junundu mode active for " & $a_s_Title)
	If JununduMode_HasSulfurHaze() And Not JununduMode_PlayerInJunundu() Then
		JununduMode_TryMountNearby()
	EndIf
EndFunc

Func JununduMode_Tick()
	If Not $g_b_JununduModeEnabled Then Return
	If Not Map_GetInstanceInfo("IsExplorable") Then Return
	If JununduMode_HasSulfurHaze() And Not JununduMode_PlayerInJunundu() Then
		JununduMode_TryMountNearby()
	EndIf
EndFunc
