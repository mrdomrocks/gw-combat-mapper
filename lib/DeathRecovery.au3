#include-once
#include "VanquishCheck.au3"

; Resume after resurrection and optional Last Stand for nearly-complete vanquishes.

Global $g_b_DeathRecoveryEnabled = True
Global $g_b_LastStandEnabled = False
Global Const $GC_I_LAST_STAND_FOE_LIMIT = 20
Global Const $GC_I_DEATH_RECOVERY_MAX_WAITS = 3
Global $g_i_DeathRecoveryWaits = 0

Func DeathRecovery_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_DeathRecoveryEnabled = Number(IniRead($a_s_ConfigPath, "Recovery", "ResumeAfterRez", "1")) <> 0
	$g_b_LastStandEnabled = Number(IniRead($a_s_ConfigPath, "Recovery", "LastStand", "0")) <> 0
EndFunc

Func DeathRecovery_ShouldLastStand()
	If Not $g_b_LastStandEnabled Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	Local $l_i_Remaining = VanquishCheck_GetFoesToKill()
	Return $l_i_Remaining >= 0 And $l_i_Remaining > 0 And $l_i_Remaining < $GC_I_LAST_STAND_FOE_LIMIT
EndFunc

Func DeathRecovery_WaitForResurrection($a_i_MaxMs = 120000)
	Local $l_h_Wait = TimerInit()
	Out("Death recovery: waiting for resurrection...")
	UpdateStatusLabel("waiting for rez")

	While TimerDiff($l_h_Wait) < $a_i_MaxMs
		If $g_b_StopRequested Or Not $g_b_BotRunning Then Return False
		If Not Party_GetPartyContextInfo("IsDefeated") Then
			If Not Agent_GetAgentInfo(-2, "IsDead") Then
				Out("Death recovery: resurrected — resuming.")
				Sleep(1500)
				Return True
			EndIf
		EndIf
		Sleep(500)
	WEnd
	Return False
EndFunc

Func DeathRecovery_HandleWipe()
	If Not Party_GetPartyContextInfo("IsDefeated") And Not Agent_GetAgentInfo(-2, "IsDead") Then Return True

	If DeathRecovery_ShouldLastStand() Then
		Out("Last Stand: " & VanquishCheck_GetFoesToKill() & " foes remain — waiting for manual finish.")
		UpdateStatusLabel("LAST STAND | missing=" & VanquishCheck_GetFoesToKill())
		While $g_b_BotRunning And Not $g_b_StopRequested
			If VanquishCheck_IsCoverageVanquished() Then
				Out("Last Stand complete — area vanquished.")
				Return True
			EndIf
			If Not Party_GetPartyContextInfo("IsDefeated") And Not Agent_GetAgentInfo(-2, "IsDead") Then
				Out("Last Stand: player alive — resuming bot.")
				Return True
			EndIf
			Sleep(500)
		WEnd
		Return False
	EndIf

	If Not $g_b_DeathRecoveryEnabled Then
		Out("Party defeated — death recovery disabled.")
		Return False
	EndIf

	$g_i_DeathRecoveryWaits += 1
	If $g_i_DeathRecoveryWaits > $GC_I_DEATH_RECOVERY_MAX_WAITS Then
		Out("Party defeated too many times — stopping.")
		Return False
	EndIf

	If Not DeathRecovery_WaitForResurrection() Then
		Out("Death recovery timed out.")
		Return False
	EndIf
	Return True
EndFunc

Func DeathRecovery_ResetSession()
	$g_i_DeathRecoveryWaits = 0
EndFunc
