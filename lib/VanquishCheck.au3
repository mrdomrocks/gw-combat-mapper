#include-once

; Runtime vanquish detection (HM foe counter). Mirrors vanquish-bot GetAreaVanquished().

Global $g_i_VanquishCheck_MapID = 0
Global $g_i_VanquishCheck_InitialFoesToKill = -1
Global $g_i_VanquishCheck_InitialFoesKilled = 0
Global $g_i_VanquishCheck_SessionStartKilled = 0
Global $g_b_VanquishCheck_CounterUnreliable = False

Func VanquishCheck_GetFoesToKill()
	If World_GetWorldContextPtr() = 0 Then Return -1
	Return Number(World_GetWorldInfo("FoesToKill"))
EndFunc

Func VanquishCheck_GetFoesKilled()
	If World_GetWorldContextPtr() = 0 Then Return 0
	Return Number(World_GetWorldInfo("FoesKilled"))
EndFunc

Func VanquishCheck_IsHardMode()
	Return Party_GetPartyContextInfo("IsHardMode") <> 0
EndFunc

; Call after Map_WaitMapIsLoaded / explorable entry — resets baseline when map id changes.
Func VanquishCheck_OnMapLoaded($a_b_Verbose = True)
	Local $l_i_Map = Number(Map_GetMapID())
	If $l_i_Map <> $g_i_VanquishCheck_MapID Then
		$g_i_VanquishCheck_MapID = $l_i_Map
		$g_i_VanquishCheck_InitialFoesToKill = -1
		$g_i_VanquishCheck_InitialFoesKilled = 0
		$g_i_VanquishCheck_SessionStartKilled = VanquishCheck_GetFoesKilled()
		$g_b_VanquishCheck_CounterUnreliable = False
	EndIf

	Local $l_i_Remaining = VanquishCheck_GetFoesToKill()
	Local $l_i_Killed = VanquishCheck_GetFoesKilled()
	If $l_i_Remaining > 0 Then
		If $g_i_VanquishCheck_InitialFoesToKill < 0 Or $g_b_VanquishCheck_CounterUnreliable Then
			$g_i_VanquishCheck_InitialFoesToKill = $l_i_Remaining
			$g_i_VanquishCheck_InitialFoesKilled = $l_i_Killed
			$g_b_VanquishCheck_CounterUnreliable = False
		EndIf
	EndIf

	If $a_b_Verbose And Map_GetInstanceInfo("IsExplorable") Then
		If VanquishCheck_IsAreaVanquished() Then
			Out("Vanquish: area complete on MapID=" & $l_i_Map & " (foes " & $l_i_Killed & "/" & ($l_i_Killed + $l_i_Remaining) & ") — skip route sweep.")
		ElseIf $l_i_Remaining >= 0 Then
			Out("Vanquish: MapID=" & $l_i_Map & " remaining=" & $l_i_Remaining & " killed=" & $l_i_Killed)
		EndIf
	EndIf
EndFunc

Func VanquishCheck_IsAreaVanquished()
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	If Not VanquishCheck_IsHardMode() Then Return False

	Local $l_i_Remaining = VanquishCheck_GetFoesToKill()
	Local $l_i_Killed = VanquishCheck_GetFoesKilled()
	If $l_i_Remaining < 0 Then Return False

	If $l_i_Remaining > 0 Then
		If $g_i_VanquishCheck_InitialFoesToKill < 0 Or $g_b_VanquishCheck_CounterUnreliable Then
			$g_i_VanquishCheck_InitialFoesToKill = $l_i_Remaining
			$g_i_VanquishCheck_InitialFoesKilled = $l_i_Killed
			$g_b_VanquishCheck_CounterUnreliable = False
		EndIf
		Return False
	EndIf

	If $g_i_VanquishCheck_InitialFoesToKill > 0 Then
		If $l_i_Killed <= $g_i_VanquishCheck_InitialFoesKilled Then Return False
		$g_b_VanquishCheck_CounterUnreliable = False
		Return True
	EndIf

	If $l_i_Killed > $g_i_VanquishCheck_SessionStartKilled And $l_i_Killed > 0 Then Return True
	Return False
EndFunc
