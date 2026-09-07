#include-once

; Ice Caves of Sorrow (22) -> Talus Chute (ends at Camp Rankor). After that vanquish,
; TravelTo Camp Rankor (155) -> Snake Dance -> Dreadnought's Drift -> Lornar's Pass.
; Used for single-map and region-list runs that start from Ice Caves of Sorrow with a full party.

Func MapTravel_IsSouthernShiverpeaksSpineTarget($a_s_TargetTitle)
	Switch $a_s_TargetTitle
		Case "TalusChute", "SnakeDance", "DreadnoughtsDrift", "LornarsPass"
			Return True
	EndSwitch
	Return False
EndFunc

Func MapTravel_SouthernShiverpeaksSpineNeedsTalus($a_s_TargetTitle)
	Return $a_s_TargetTitle = "TalusChute"
EndFunc

; Ice Caves of Sorrow town (22). $IceCavesOfSorrow_Outpost is 23 = Thunderhead Keep.
Func MapTravel_IsIceCavesOfSorrowTown($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Return $a_i_Map = $TalusChute_Outpost
EndFunc

; Talus Chute always enters from Ice Caves of Sorrow (22) unless already on that town or on Talus.
Func MapTravel_ShouldTravelToIceCavesForTalus($a_s_TargetTitle)
	If Not MapTravel_SouthernShiverpeaksSpineNeedsTalus($a_s_TargetTitle) Then Return False
	If MapTravel_IsIceCavesOfSorrowTown() Then Return False
	If Map_GetMapID() = $TalusChute_Map And Map_GetInstanceInfo("IsExplorable") Then Return False
	Return True
EndFunc

Func MapTravel_TravelToIceCavesOfSorrowTown()
	If MapTravel_IsIceCavesOfSorrowTown() Then
		Out("Already at Ice Caves of Sorrow.")
		Return True
	EndIf
	Out("Map travel to Ice Caves of Sorrow (" & $TalusChute_Outpost & ")")
	If MapTravel_TravelToOutpost($TalusChute_Outpost) Then
		Out("Arrived at Ice Caves of Sorrow.")
		Return True
	EndIf
	Out("Failed to travel to Ice Caves of Sorrow.")
	Return False
EndFunc

Func MapTravel_SouthernShiverpeaksSpineNeedsCampRankor($a_s_TargetTitle)
	Return $a_s_TargetTitle = "SnakeDance" Or $a_s_TargetTitle = "DreadnoughtsDrift" Or _
		$a_s_TargetTitle = "LornarsPass"
EndFunc

Func MapTravel_IsCampRankorOutpost($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Return $a_i_Map = $CampRankor_Outpost
EndFunc

Func MapTravel_IsOnCampRankorSpineExplorable($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Local $l_s_Title = MapTravel_GetSouthernShiverpeaksSpineTitleForMap($a_i_Map)
	Return $l_s_Title = "SnakeDance" Or $l_s_Title = "DreadnoughtsDrift" Or $l_s_Title = "LornarsPass"
EndFunc

; After Talus Chute (or any non-spine map), TravelTo Camp Rankor instead of walking Talus.
Func MapTravel_ShouldTravelToCampRankor($a_s_TargetTitle)
	If Not MapTravel_SouthernShiverpeaksSpineNeedsCampRankor($a_s_TargetTitle) Then Return False
	If MapTravel_IsCampRankorOutpost() Then Return False
	If MapTravel_IsOnCampRankorSpineExplorable() Then Return False
	Return True
EndFunc

; All Prophecies Southern Shiverpeaks vanquish titles (spines + side maps).
Func MapTravel_IsSouthernShiverpeaksRegionTitle($a_s_TargetTitle)
	Switch $a_s_TargetTitle
		Case "TalusChute", "SnakeDance", "DreadnoughtsDrift", "LornarsPass", _
			"IceDome", "FrozenForest", "IceFloe", "GrenthsFootprint", _
			"SpearheadPeak", "MineralSprings", "TascasDemise", "WitmansFolly"
			Return True
	EndSwitch
	Return False
EndFunc

Func MapTravel_GetSouthernShiverpeaksRegionTitleForMap($a_i_Map)
	Local $l_s_Spine = MapTravel_GetSouthernShiverpeaksSpineTitleForMap($a_i_Map)
	If $l_s_Spine <> "" Then Return $l_s_Spine
	If $a_i_Map = $Icedome_Map Then Return "IceDome"
	If $a_i_Map = $FrozenForest_Map Then Return "FrozenForest"
	If $a_i_Map = $IceFloe_Map Then Return "IceFloe"
	If $a_i_Map = $GrenthsFootprint_Map Then Return "GrenthsFootprint"
	If $a_i_Map = $SpearheadPeak_Map Then Return "SpearheadPeak"
	If $a_i_Map = $MineralSprings_Map Then Return "MineralSprings"
	If $a_i_Map = $TascasDemise_Map Then Return "TascasDemise"
	If $a_i_Map = $WitmansFolly_Map Then Return "WitmansFolly"
	Return ""
EndFunc

; True when already in a Southern Shiverpeaks explorable (including Ice Caves of Sorrow).
Func MapTravel_IsOnSouthernShiverpeaksExplorable($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	If MapTravel_IsIceCavesOutpost($a_i_Map) Then Return True
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	Return MapTravel_GetSouthernShiverpeaksRegionTitleForMap($a_i_Map) <> ""
EndFunc

; Spine farm order: Talus (Ice Caves, ends at Camp Rankor), then Snake / Dreadnought / Lornar (Camp Rankor).
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

; True when already on Snake / Dreadnought and can portal to the next (no return to Camp Rankor).
; Talus Chute -> Snake Dance is not a portal hop; that gap TravelTo's Camp Rankor.
Func MapTravel_CanContinueSouthernShiverpeaksSpineFromCurrent($a_s_TargetTitle)
	If Not MapTravel_IsSouthernShiverpeaksSpineTarget($a_s_TargetTitle) Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	Local $l_i_TargetStage = MapTravel_GetSouthernShiverpeaksSpineStage($a_s_TargetTitle)
	Local $l_i_CurrentStage = MapTravel_GetSouthernShiverpeaksSpineStage(MapTravel_GetSouthernShiverpeaksSpineTitleForMap(Map_GetMapID()))
	If $l_i_CurrentStage < 0 Or $l_i_TargetStage < 0 Then Return False
	If $l_i_CurrentStage = 0 Then Return False
	Return $l_i_TargetStage = $l_i_CurrentStage + 1
EndFunc

Func MapTravel_MaybeVanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
	If IsFunc("BotEngine_VanquishSouthernShiverpeaksSpineTransit") Then BotEngine_VanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
EndFunc

Func MapTravel_TryGetSouthernShiverpeaksSpinePath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)
	If Not MapTravel_IsSouthernShiverpeaksSpineTarget($a_s_TargetTitle) Then Return False

	; Ice Caves of Sorrow outpost -> Talus Chute only (later maps enter from Camp Rankor).
	If $a_i_FromMap = $TalusChute_Outpost And MapTravel_SouthernShiverpeaksSpineNeedsTalus($a_s_TargetTitle) Then
		$a_a_Path = $aTalusChuteOutpostPath
		$a_s_Label = "IceCaves->TalusChute "
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

	; Camp Rankor -> Snake Dance (and later spine maps that enter through Snake Dance).
	; Outpost 155 has two doors; this recorded walk is the Snake Dance exit only.
	If $a_i_FromMap = $CampRankor_Outpost And MapTravel_SouthernShiverpeaksSpineNeedsCampRankor($a_s_TargetTitle) Then
		$a_a_Path = $aSnakeDanceOutpostPath
		$a_s_Label = "CampRankor->SnakeDance "
		Return True
	EndIf

	; Talus Chute does not portal to Snake Dance; callers TravelTo Camp Rankor first.
	Return False
EndFunc
