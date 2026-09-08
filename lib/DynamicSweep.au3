#include-once
#include "VanquishCheck.au3"
#include "PathRoute.au3"
#include "Combat.au3"

; Hunt nearest living enemies via Pathfinder instead of lawnmower grid.

Global Const $GC_I_DYNAMIC_MAX_BLACKLIST = 64
Global Const $GC_I_DYNAMIC_MAX_IDLE_LOOPS = 12
Global $g_i_DynamicBlocked[$GC_I_DYNAMIC_MAX_BLACKLIST]
Global $g_i_DynamicBlockedCount = 0
Global $g_i_DynamicIdleLoops = 0

Func DynamicSweep_Reset()
	$g_i_DynamicBlockedCount = 0
	$g_i_DynamicIdleLoops = 0
EndFunc

Func DynamicSweep_IsBlocked($a_i_AgentID)
	Local $i
	For $i = 0 To $g_i_DynamicBlockedCount - 1
		If $g_i_DynamicBlocked[$i] = $a_i_AgentID Then Return True
	Next
	Return False
EndFunc

Func DynamicSweep_BlockTarget($a_i_AgentID)
	If $a_i_AgentID <= 0 Then Return
	If DynamicSweep_IsBlocked($a_i_AgentID) Then Return
	If $g_i_DynamicBlockedCount >= $GC_I_DYNAMIC_MAX_BLACKLIST Then Return
	$g_i_DynamicBlocked[$g_i_DynamicBlockedCount] = $a_i_AgentID
	$g_i_DynamicBlockedCount += 1
EndFunc

Func DynamicSweep_FindNearestEnemy()
	Local $l_a_Agents = Agent_GetAgentArray(0xDB)
	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return 0

	Local $l_f_MeX = Agent_GetAgentInfo(-2, "X")
	Local $l_f_MeY = Agent_GetAgentInfo(-2, "Y")
	Local $l_f_Best = 999999999
	Local $l_p_Best = 0

	Local $i
	For $i = 1 To $l_a_Agents[0]
		Local $l_p_Agent = $l_a_Agents[$i]
		If $l_p_Agent = 0 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "Allegiance") <> 3 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "HP") <= 0 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "IsDead") Then ContinueLoop

		Local $l_i_ID = Agent_GetAgentInfo($l_p_Agent, "ID")
		If DynamicSweep_IsBlocked($l_i_ID) Then ContinueLoop

		Local $l_f_X = Agent_GetAgentInfo($l_p_Agent, "X")
		Local $l_f_Y = Agent_GetAgentInfo($l_p_Agent, "Y")
		If $l_f_X = 0 And $l_f_Y = 0 Then ContinueLoop

		Local $l_f_Dx = $l_f_X - $l_f_MeX
		Local $l_f_Dy = $l_f_Y - $l_f_MeY
		Local $l_f_D = Sqrt($l_f_Dx * $l_f_Dx + $l_f_Dy * $l_f_Dy)
		If $l_f_D < $l_f_Best Then
			$l_f_Best = $l_f_D
			$l_p_Best = $l_p_Agent
		EndIf
	Next
	Return $l_p_Best
EndFunc

Func DynamicSweep_Run($a_s_Label = "dynamic")
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	DynamicSweep_Reset()
	PathRoute_ConfigurePathfinder($GC_S_PATHROUTE_PROFILE_COVERAGE, True)
	PathRoute_BeginSession($GC_S_PATHROUTE_PROFILE_COVERAGE, False)

	Out("Dynamic enemy hunt started on MapID=" & Map_GetMapID())

	While $g_b_BotRunning And Not $g_b_StopRequested
		If IsFunc("BotEngine_WaitIfPaused") Then BotEngine_WaitIfPaused()
		If $g_b_StopRequested Then ExitLoop

		If VanquishCheck_IsCoverageVanquished() Then
			Out("Dynamic hunt complete — area vanquished.")
			ExitLoop
		EndIf

		If IsFunc("DeathRecovery_HandleWipe") Then
			If Not DeathRecovery_HandleWipe() Then ExitLoop
		ElseIf Party_GetPartyContextInfo("IsDefeated") Then
			Out("Dynamic hunt stopped — party defeated.")
			ExitLoop
		EndIf

		Local $l_p_Target = DynamicSweep_FindNearestEnemy()
		If $l_p_Target = 0 Then
			$g_i_DynamicIdleLoops += 1
			If $g_i_DynamicIdleLoops >= $GC_I_DYNAMIC_MAX_IDLE_LOOPS Then
				Out("Dynamic hunt: no reachable enemies after " & $GC_I_DYNAMIC_MAX_IDLE_LOOPS & " scans.")
				ExitLoop
			EndIf
			Sleep(500)
			ContinueLoop
		EndIf
		$g_i_DynamicIdleLoops = 0

		Local $l_i_ID = Agent_GetAgentInfo($l_p_Target, "ID")
		Local $l_f_X = Agent_GetAgentInfo($l_p_Target, "X")
		Local $l_f_Y = Agent_GetAgentInfo($l_p_Target, "Y")

		UpdateStatusLabel("dynamic -> enemy " & $l_i_ID & " @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ")" & _
			VanquishCheck_StatusSuffix())
		Out("Dynamic target " & $l_i_ID & " @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ")")

		Local $l_s_Call = "BotEngine_Tick"
		If Not IsFunc("BotEngine_Tick") Then $l_s_Call = ""
		Local $l_b_Ok = PathRoute_MoveTo($l_f_X, $l_f_Y, $GC_S_PATHROUTE_PROFILE_COVERAGE, $g_f_AggroRange, _
			$g_f_FightRangeOut, 0, $l_s_Call)

		If Not Combat_WaitUntilClear($g_f_AggroRange, $g_f_FightRangeOut, 0, $l_s_Call) Then ExitLoop

		If Not $l_b_Ok Then
			DynamicSweep_BlockTarget($l_i_ID)
			Out("Dynamic: blacklisted unreachable target " & $l_i_ID)
		EndIf
	WEnd

	PathRoute_EndSession()
	Return VanquishCheck_IsCoverageVanquished()
EndFunc
