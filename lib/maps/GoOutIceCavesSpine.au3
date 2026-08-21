#include-once

; Ice Caves of Sorrow (23) -> Ice Floe -> Frozen Forest -> Ice Dome (transit), then vanquish
; Ice Dome -> Frozen Forest -> Ice Floe in farm order.
; Used for single-map and region-list runs that start from Ice Caves of Sorrow with a full party.

Func MapTravel_IsIceCavesSpineTarget($a_s_TargetTitle)
	Switch $a_s_TargetTitle
		Case "IceDome", "FrozenForest", "IceFloe"
			Return True
	EndSwitch
	Return False
EndFunc

Func MapTravel_IceCavesSpineNeedsIceFloe($a_s_TargetTitle)
	Return $a_s_TargetTitle = "IceDome" Or $a_s_TargetTitle = "FrozenForest" Or $a_s_TargetTitle = "IceFloe"
EndFunc

; Spine farm order from Ice Caves of Sorrow.
Func MapTravel_GetIceCavesSpineStage($a_s_Title)
	Switch $a_s_Title
		Case "IceDome"
			Return 0
		Case "FrozenForest"
			Return 1
		Case "IceFloe"
			Return 2
	EndSwitch
	Return -1
EndFunc

Func MapTravel_GetIceCavesSpineTitleForMap($a_i_Map)
	If $a_i_Map = $Icedome_Map Then Return "IceDome"
	If $a_i_Map = $FrozenForest_Map Then Return "FrozenForest"
	If $a_i_Map = $IceFloe_Map Then Return "IceFloe"
	Return ""
EndFunc

; True when already on the prior spine map and can portal to the next (no return to Ice Caves).
Func MapTravel_CanContinueIceCavesSpineFromCurrent($a_s_TargetTitle)
	If Not MapTravel_IsIceCavesSpineTarget($a_s_TargetTitle) Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	Local $l_i_TargetStage = MapTravel_GetIceCavesSpineStage($a_s_TargetTitle)
	Local $l_i_CurrentStage = MapTravel_GetIceCavesSpineStage(MapTravel_GetIceCavesSpineTitleForMap(Map_GetMapID()))
	If $l_i_CurrentStage < 0 Or $l_i_TargetStage < 0 Then Return False
	Return $l_i_TargetStage = $l_i_CurrentStage + 1
EndFunc

Func MapTravel_MaybeVanquishIceCavesSpineTransit($a_s_TargetTitle)
	If IsFunc("BotEngine_VanquishIceCavesSpineTransit") Then BotEngine_VanquishIceCavesSpineTransit($a_s_TargetTitle)
EndFunc

; Ice Caves mission outpost: map travel in, recorded portal out only (no pathfinder/coverage here).
Func MapTravel_IsIceCavesOutpost($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Return $a_i_Map = $IceCavesOfSorrow_Outpost
EndFunc

Func MapTravel_ForceRecordedPortalRoute($a_s_TargetTitle)
	If MapTravel_IsIceCavesOutpost() And MapTravel_IsIceCavesSpineTarget($a_s_TargetTitle) Then Return True
	Return False
EndFunc

Func MapTravel_TryGetIceCavesSpinePath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)
	If Not MapTravel_IsIceCavesSpineTarget($a_s_TargetTitle) Then Return False

	; Ice Caves of Sorrow outpost -> Ice Floe (first portal for all three farm maps).
	If $a_i_FromMap = $IceCavesOfSorrow_Outpost And MapTravel_IceCavesSpineNeedsIceFloe($a_s_TargetTitle) Then
		$a_a_Path = $aIceFloeOutpostPath
		$a_s_Label = "IceCaves->IceFloe "
		Return True
	EndIf

	; Ice Floe / Frozen Forest -> Ice Dome and later maps: Pathfinder handles intermediate hops.
	Return False
EndFunc
