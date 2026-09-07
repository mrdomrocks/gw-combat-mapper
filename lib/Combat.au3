#include-once

; Shared combat detection and fight-until-clear for vanquish routes and portal walks.

Global $g_f_AggroRange = 1320
Global $g_f_FightRangeOut = 3500
Global $g_i_CombatEndGraceMs = 1500

Func Combat_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"

	$g_f_AggroRange = Number(IniRead($a_s_ConfigPath, "Combat", "AggroRange", "1320"))
	$g_f_FightRangeOut = Number(IniRead($a_s_ConfigPath, "Combat", "FightRangeOut", "3500"))
	$g_i_CombatEndGraceMs = Number(IniRead($a_s_ConfigPath, "Combat", "CombatEndGraceMs", "1500"))

	If $g_f_AggroRange <= 0 Then $g_f_AggroRange = 1320
	If $g_f_FightRangeOut <= 0 Then $g_f_FightRangeOut = 3500
	If $g_i_CombatEndGraceMs < 0 Then $g_i_CombatEndGraceMs = 1500
EndFunc

Func Combat_GetEndGraceMs()
	Return $g_i_CombatEndGraceMs
EndFunc

; True when any living foe is within range of the player.
Func Combat_HasFoesInRange($a_f_Range)
	If $a_f_Range <= 0 Then Return False

	Local $l_a_Agents = Agent_GetAgentArray(0xDB)
	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return False

	Local $i
	For $i = 1 To $l_a_Agents[0]
		Local $l_p_Agent = $l_a_Agents[$i]
		If $l_p_Agent = 0 Then ContinueLoop

		Local $l_i_ID = Agent_GetAgentInfo($l_p_Agent, "ID")
		If $l_i_ID = 0 Or $l_i_ID = Agent_GetMyID() Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "Allegiance") <> 3 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "HP") <= 0 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "IsDead") Then ContinueLoop
		If Agent_GetDistance($l_p_Agent, -2) <= $a_f_Range Then Return True
	Next

	Return False
EndFunc

; True if combat is actively underway (targeting / attacking), not just nearby idle foes.
Func Combat_IsEngaged()
	Local $l_b_PlayerAttacking = Agent_GetAgentInfo(-2, "IsAttacking")
	Local $l_i_CurrentTarget = Agent_GetCurrentTarget()
	Local $l_a_Agents = Agent_GetAgentArray(0xDB)

	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return False

	Local $i
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

Func Combat_ShouldHoldMovement($a_f_Aggro, $a_f_FightOut)
	If Combat_IsEngaged() Then Return True
	If $a_f_Aggro > 0 And Combat_HasFoesInRange($a_f_Aggro) Then Return True
	Return False
EndFunc

Func Combat_AnyFoesRemain($a_f_FightOut)
	If Combat_IsEngaged() Then Return True
	If $a_f_FightOut > 0 And Combat_HasFoesInRange($a_f_FightOut) Then Return True
	Return False
EndFunc

; Fight until aggro/engagement is clear (+ grace). Distant idle packs in FightRangeOut
; are left for later waypoints. Returns False if stopped.
Func Combat_WaitUntilClear($a_f_Aggro, $a_f_FightOut, $a_i_Finisher, $a_s_CallFunc = "")
	If Not Combat_ShouldHoldMovement($a_f_Aggro, $a_f_FightOut) Then Return True

	Local $l_h_Clear = 0
	While True
		If $g_b_StopRequested Then Return False
		If $a_s_CallFunc <> "" Then Call($a_s_CallFunc)

		If Map_GetInstanceInfo("Type") <> $GC_I_MAP_TYPE_EXPLORABLE Then Return True

		If Combat_ShouldHoldMovement($a_f_Aggro, $a_f_FightOut) Then
			$l_h_Clear = 0
			Local $l_f_Cx = Agent_GetAgentInfo(-2, "X")
			Local $l_f_Cy = Agent_GetAgentInfo(-2, "Y")
			UAI_Fight($l_f_Cx, $l_f_Cy, $a_f_Aggro, $a_f_FightOut, $a_i_Finisher)
			If IsFunc(Execute("SmartCast_EnsureReady")) Then SmartCast_EnsureReady(False)
		ElseIf $l_h_Clear = 0 Then
			$l_h_Clear = TimerInit()
		ElseIf TimerDiff($l_h_Clear) >= $g_i_CombatEndGraceMs Then
			Return True
		EndIf

		Sleep(32)
	WEnd
EndFunc
