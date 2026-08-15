#include-once

; Runtime vanquish detection:
; - Character vanquish history (VanquishedAreasArray) for maps already completed.
; - HM foe counter for maps finished in the current instance.
; History is required for already-vanquished maps: a new instance is 0 remaining / 0 killed,
; which the foe-counter logic must not treat as "still open".

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

; Character-wide vanquish bit for a map id (same source as the vanquish-bot history scan).
Func VanquishCheck_IsMapHistoricallyVanquished($a_i_MapID = -1)
	If $a_i_MapID < 0 Then $a_i_MapID = Number(Map_GetMapID())
	If $a_i_MapID <= 0 Then Return False
	If World_GetWorldContextPtr() = 0 Then Return False

	Local $l_p_Array = World_GetWorldInfo("VanquishedAreasArray")
	Local $l_i_Size = Number(World_GetWorldInfo("VanquishedAreasArraySize"))
	If $l_p_Array = 0 Or $l_i_Size <= 0 Then Return False

	Local $l_i_WordIndex = Floor($a_i_MapID / 32)
	If $l_i_WordIndex < 0 Or $l_i_WordIndex >= $l_i_Size Then Return False

	Local $l_i_Bit = Mod($a_i_MapID, 32)
	Local $l_i_Mask = BitShift(1, -$l_i_Bit)
	Local $l_i_Word = Number(Memory_Read($l_p_Array + ($l_i_WordIndex * 4), "dword"))
	Return BitAND($l_i_Word, $l_i_Mask) <> 0
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
		If VanquishCheck_IsMapHistoricallyVanquished($l_i_Map) Then
			Out("Vanquish: MapID=" & $l_i_Map & " already complete (history) — skip route sweep, use portal route.")
		ElseIf VanquishCheck_IsAreaVanquished() Then
			Out("Vanquish: area complete on MapID=" & $l_i_Map & " (foes " & $l_i_Killed & "/" & ($l_i_Killed + $l_i_Remaining) & ") — skip route sweep.")
		ElseIf $l_i_Remaining >= 0 Then
			Out("Vanquish: MapID=" & $l_i_Map & " remaining=" & $l_i_Remaining & " killed=" & $l_i_Killed)
		EndIf
	EndIf
EndFunc

; Wait briefly after explorable entry so history / foe counter can populate before sweep vs portal.
Func VanquishCheck_WaitUntilReady($a_b_Verbose = True)
	If Map_GetInstanceInfo("IsExplorable") Then
		Local $l_i_Map = Number(Map_GetMapID())
		Local $l_h_Wait = TimerInit()
		While TimerDiff($l_h_Wait) < 2500
			If IsDeclared("g_b_StopRequested") And $g_b_StopRequested Then ExitLoop
			If VanquishCheck_IsMapHistoricallyVanquished($l_i_Map) Then ExitLoop
			If VanquishCheck_GetFoesToKill() > 0 Then ExitLoop
			Sleep(250)
		WEnd
	EndIf
	VanquishCheck_OnMapLoaded($a_b_Verbose)
EndFunc

Func VanquishCheck_IsAreaVanquished()
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	If VanquishCheck_IsMapHistoricallyVanquished() Then Return True
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
