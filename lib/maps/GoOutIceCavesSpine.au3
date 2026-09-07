#include-once

; Per-map Southern ice entries (not a shared Ice Caves start):
;   IceDome: Ice Caves of Sorrow (22) -> Talus Chute -> Ice Dome
;   FrozenForest: Iron Mines of Moladune (24), or portal from Ice Dome after vanquish
;   IceFloe: Thunderhead Keep (23)

Func MapTravel_IsIceCavesSpineTarget($a_s_TargetTitle)
	Switch $a_s_TargetTitle
		Case "IceDome", "FrozenForest", "IceFloe"
			Return True
	EndSwitch
	Return False
EndFunc

Func MapTravel_IceCavesSpineNeedsIceFloe($a_s_TargetTitle)
	Return $a_s_TargetTitle = "IceFloe"
EndFunc

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

; Portal Ice Dome -> Frozen Forest after the Ice Dome vanquish; other hops TravelTo.
Func MapTravel_CanContinueIceCavesSpineFromCurrent($a_s_TargetTitle)
	If $a_s_TargetTitle <> "FrozenForest" Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	Return Map_GetMapID() = $Icedome_Map
EndFunc

Func MapTravel_ShouldTravelToIceDomeEntry($a_s_TargetTitle)
	If $a_s_TargetTitle <> "IceDome" Then Return False
	If MapTravel_IsIceCavesOfSorrowTown() Then Return False
	If Map_GetMapID() = $TalusChute_Map And Map_GetInstanceInfo("IsExplorable") Then Return False
	Return True
EndFunc

Func MapTravel_ShouldTravelToFrozenForestEntry($a_s_TargetTitle)
	If $a_s_TargetTitle <> "FrozenForest" Then Return False
	If Map_GetMapID() = $IronMinesOfMoladune_Outpost Then Return False
	If MapTravel_CanContinueIceCavesSpineFromCurrent($a_s_TargetTitle) Then Return False
	Return True
EndFunc

Func MapTravel_ShouldTravelToIceFloeEntry($a_s_TargetTitle)
	If $a_s_TargetTitle <> "IceFloe" Then Return False
	If Map_GetMapID() = $IceCavesOfSorrow_Outpost Then Return False
	Return True
EndFunc

Func MapTravel_MaybeVanquishIceCavesSpineTransit($a_s_TargetTitle)
	If IsFunc("BotEngine_VanquishIceCavesSpineTransit") Then BotEngine_VanquishIceCavesSpineTransit($a_s_TargetTitle)
EndFunc

; Thunderhead Keep (23). Ice Caves of Sorrow town is $TalusChute_Outpost (22).
Func MapTravel_IsIceCavesOutpost($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Return $a_i_Map = $IceCavesOfSorrow_Outpost
EndFunc

Func MapTravel_IsIronMinesOfMoladuneOutpost($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Return $a_i_Map = $IronMinesOfMoladune_Outpost
EndFunc

Func MapTravel_ForceRecordedPortalRoute($a_s_TargetTitle)
	If MapTravel_IsIceCavesOfSorrowTown() And $a_s_TargetTitle = "IceDome" Then Return True
	If $a_s_TargetTitle = "TalusChute" And Map_GetMapID() = $TalusChute_Outpost Then Return True
	If MapTravel_IsIceCavesOutpost() And $a_s_TargetTitle = "IceFloe" Then Return True
	If MapTravel_IsIronMinesOfMoladuneOutpost() And $a_s_TargetTitle = "FrozenForest" Then Return True
	If Map_GetMapID() = $Icedome_Map And $a_s_TargetTitle = "FrozenForest" Then Return True
	If MapTravel_IsCampRankorOutpost() And MapTravel_SouthernShiverpeaksSpineNeedsCampRankor($a_s_TargetTitle) Then Return True
	Return False
EndFunc

Func MapTravel_TryGetIceCavesSpinePath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)
	If $a_s_TargetTitle = "IceDome" Then
		If $a_i_FromMap = $TalusChute_Outpost Then
			$a_a_Path = $aTalusChuteOutpostPath
			$a_s_Label = "IceCaves->Talus "
			Return True
		EndIf
		If $a_i_FromMap = $TalusChute_Map Then
			$a_a_Path = $aIcedomeTransitPath
			$a_s_Label = "Talus->IceDome "
			Return True
		EndIf
	EndIf

	If $a_s_TargetTitle = "FrozenForest" Then
		If $a_i_FromMap = $Icedome_Map Then
			$a_a_Path = $aFrozenForestTransitPath
			$a_s_Label = "IceDome->FrozenForest "
			Return True
		EndIf
		If $a_i_FromMap = $IronMinesOfMoladune_Outpost Then
			$a_a_Path = $aFrozenForestOutpostPath
			$a_s_Label = "IronMines->FrozenForest "
			Return True
		EndIf
	EndIf

	If $a_s_TargetTitle = "IceFloe" And $a_i_FromMap = $IceCavesOfSorrow_Outpost Then
		$a_a_Path = $aIceFloeOutpostPath
		$a_s_Label = "Thunderhead->IceFloe "
		Return True
	EndIf

	Return False
EndFunc
