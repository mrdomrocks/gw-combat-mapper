#include-once

; Droknar's Forge (20) -> Talus Chute -> Snake Dance -> Dreadnought's Drift -> Lornar's Pass.
; Used for single-map and region-list runs that start from Droknar's Forge with a full party.

Func MapTravel_IsSouthernShiverpeaksSpineTarget($a_s_TargetTitle)
	Switch $a_s_TargetTitle
		Case "TalusChute", "SnakeDance", "DreadnoughtsDrift", "LornarsPass"
			Return True
	EndSwitch
	Return False
EndFunc

Func MapTravel_SouthernShiverpeaksSpineNeedsTalus($a_s_TargetTitle)
	Return $a_s_TargetTitle = "TalusChute" Or $a_s_TargetTitle = "SnakeDance" Or _
		$a_s_TargetTitle = "DreadnoughtsDrift" Or $a_s_TargetTitle = "LornarsPass"
EndFunc

; Spine farm order from Droknar's Forge.
Func MapTravel_GetSouthernShiverpeaksSpineStage($a_s_Title)
	Switch $a_s_Title
		Case "TalusChute"
			Return 0
		Case "SnakeDance"
			Return 1
		Case "DreadnoughtsDrift"
			Return 2
		Case "LornarsPass"
			Return 3
	EndSwitch
	Return -1
EndFunc

Func MapTravel_GetSouthernShiverpeaksSpineTitleForMap($a_i_Map)
	If $a_i_Map = $TalusChute_Map Then Return "TalusChute"
	If $a_i_Map = $SnakeDance_Map Then Return "SnakeDance"
	If $a_i_Map = $DreadnoughtsDrift_Map Then Return "DreadnoughtsDrift"
	If $a_i_Map = $LornarsPass_Map Then Return "LornarsPass"
	Return ""
EndFunc

; True when already on the prior spine map and can portal to the next (no return to Droknar's Forge).
Func MapTravel_CanContinueSouthernShiverpeaksSpineFromCurrent($a_s_TargetTitle)
	If Not MapTravel_IsSouthernShiverpeaksSpineTarget($a_s_TargetTitle) Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	Local $l_i_TargetStage = MapTravel_GetSouthernShiverpeaksSpineStage($a_s_TargetTitle)
	Local $l_i_CurrentStage = MapTravel_GetSouthernShiverpeaksSpineStage(MapTravel_GetSouthernShiverpeaksSpineTitleForMap(Map_GetMapID()))
	If $l_i_CurrentStage < 0 Or $l_i_TargetStage < 0 Then Return False
	Return $l_i_TargetStage = $l_i_CurrentStage + 1
EndFunc

Func MapTravel_MaybeVanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
	If IsFunc("BotEngine_VanquishSouthernShiverpeaksSpineTransit") Then BotEngine_VanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
EndFunc

Func MapTravel_TryGetSouthernShiverpeaksSpinePath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)
	If Not MapTravel_IsSouthernShiverpeaksSpineTarget($a_s_TargetTitle) Then Return False

	; Droknar's Forge outpost -> Talus Chute (first portal for all four farm maps).
	If $a_i_FromMap = $TalusChute_Outpost And MapTravel_SouthernShiverpeaksSpineNeedsTalus($a_s_TargetTitle) Then
		$a_a_Path = $aTalusChuteOutpostPath
		$a_s_Label = "Droknar->TalusChute "
		Return True
	EndIf

	; Snake Dance -> Dreadnought's Drift.
	If $a_i_FromMap = $SnakeDance_Map And ($a_s_TargetTitle = "DreadnoughtsDrift" Or $a_s_TargetTitle = "LornarsPass") Then
		$a_a_Path = $aDreadnoughtsDriftTransitPath
		$a_s_Label = "SnakeDance->Dreadnought "
		Return True
	EndIf

	; Dreadnought's Drift -> Lornar's Pass.
	If $a_i_FromMap = $DreadnoughtsDrift_Map And $a_s_TargetTitle = "LornarsPass" Then
		$a_a_Path = $aLornarsPassTransit2Path
		$a_s_Label = "Dreadnought->LornarsPass "
		Return True
	EndIf

	; Talus Chute -> Snake Dance / later maps: Pathfinder handles the hop.
	Return False
EndFunc
