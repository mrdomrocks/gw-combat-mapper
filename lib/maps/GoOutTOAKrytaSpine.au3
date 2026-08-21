#include-once

; TOA (138) -> Black Curtain -> Talmark Wilderness -> Stingray Strand -> Tears of the Fallen.
; Used for single-map and region-list runs that start from Temple of the Ages with a full party.

Func MapTravel_IsTOAKrytaSpineTarget($a_s_TargetTitle)
	Switch $a_s_TargetTitle
		Case "TalmarkWilderness", "StingrayStrand", "TearsoftheFallen"
			Return True
	EndSwitch
	Return False
EndFunc

Func MapTravel_TOAKrytaSpineNeedsTalmark($a_s_TargetTitle)
	Return $a_s_TargetTitle = "TalmarkWilderness" Or $a_s_TargetTitle = "StingrayStrand" Or _
		$a_s_TargetTitle = "TearsoftheFallen"
EndFunc

; Spine farm order from TOA (Talmark -> Stingray -> Tears).
Func MapTravel_GetTOAKrytaSpineStage($a_s_Title)
	Switch $a_s_Title
		Case "TalmarkWilderness"
			Return 0
		Case "StingrayStrand"
			Return 1
		Case "TearsoftheFallen"
			Return 2
	EndSwitch
	Return -1
EndFunc

; True when already on the prior spine map and can portal to the next (no return to TOA).
Func MapTravel_CanContinueTOASpineFromCurrent($a_s_TargetTitle)
	If Not MapTravel_IsTOAKrytaSpineTarget($a_s_TargetTitle) Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	Local $l_i_TargetStage = MapTravel_GetTOAKrytaSpineStage($a_s_TargetTitle)
	Local $l_i_CurrentStage = -1
	Local $l_i_Current = Map_GetMapID()
	If $l_i_Current = $TalmarkWilderness_Map Then $l_i_CurrentStage = 0
	If $l_i_Current = $StingrayStrand_Map Then $l_i_CurrentStage = 1
	If $l_i_Current = $TearsoftheFallen_Map Then $l_i_CurrentStage = 2
	If $l_i_CurrentStage < 0 Or $l_i_TargetStage < 0 Then Return False
	Return $l_i_TargetStage = $l_i_CurrentStage + 1
EndFunc

; Optional BotEngine hook: vanquish a spine map we crossed in transit before the final target.
Func MapTravel_MaybeVanquishTOASpineTransit($a_s_TargetTitle)
	If IsFunc("BotEngine_VanquishTOASpineTransit") Then BotEngine_VanquishTOASpineTransit($a_s_TargetTitle)
EndFunc

Func MapTravel_TryGetTOAKrytaSpinePath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)
	If Not MapTravel_IsTOAKrytaSpineTarget($a_s_TargetTitle) Then Return False

	; TOA outpost -> The Black Curtain (first portal).
	If $a_i_FromMap = $TheBlackCurtain_Outpost Then
		$a_a_Path = $aTalmarkWildernessOutpostPath
		$a_s_Label = "TOA->BlackCurtain "
		Return True
	EndIf

	; The Black Curtain -> Talmark Wilderness (required for all three farm maps).
	If $a_i_FromMap = $TheBlackCurtain_Map And MapTravel_TOAKrytaSpineNeedsTalmark($a_s_TargetTitle) Then
		$a_a_Path = $aTalmarkWildernessTransitPath
		$a_s_Label = "BlackCurtain->Talmark "
		Return True
	EndIf

	; Stingray Strand -> Tears of the Fallen.
	If $a_i_FromMap = $StingrayStrand_Map And $a_s_TargetTitle = "TearsoftheFallen" Then
		$a_a_Path = $aTearsTransitPath
		$a_s_Label = "Stingray->Tears "
		Return True
	EndIf

	; Talmark -> Stingray / Tears: no recorded path — Pathfinder handles the hop.
	Return False
EndFunc
