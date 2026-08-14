#include-once

; Hard-mode travel + GoOut (LocationsIDS titles / Caravan_Ascalon routes).
#include "SmartCast.au3"
#include "VanquishCheck.au3"
#include "maps\LocationsIDS.au3"
#include "maps\GoOutRoutes.au3"

Global $g_b_HardMode = True
Global $g_s_ActiveTitle = ""
Global $g_i_GoOutLastMapHandled = 0
Global $g_i_MapTravelAggro = 0

Func MapTravel_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_i_MapTravelAggro = Number(IniRead($a_s_ConfigPath, "Travel", "PortalAggro", "0"))
	If $g_i_MapTravelAggro < 0 Then $g_i_MapTravelAggro = 0
EndFunc

Func MapTravel_GetPortalAggro()
	If $g_i_MapTravelAggro > 0 Then Return $g_i_MapTravelAggro
	If IsDeclared("g_f_AggroRange") And Number($g_f_AggroRange) > 0 Then Return $g_f_AggroRange
	Return 1320
EndFunc

Func MapTravel_GetPortalFightOut()
	If IsDeclared("g_f_FightRangeOut") And Number($g_f_FightRangeOut) > 0 Then Return $g_f_FightRangeOut
	Return 3500
EndFunc

Func MapTravel_GetPortalFinisher()
	If IsDeclared("g_i_FinisherMode") Then Return $g_i_FinisherMode
	Return 0
EndFunc

Func MapTravel_GetPortalCallFunc()
	If IsFunc("CombatMapper_Tick") Then Return "CombatMapper_Tick"
	Return ""
EndFunc

Func MapTravel_ConfigurePathfinderForPortal()
	Local $l_i_Init = Pathfinder_Initialize()
	If $l_i_Init = 0 Then Return False
	Pathfinder_SetPathUpdateInterval(2500)
	Pathfinder_SetWaypointReachedDistance(250)
	Pathfinder_SetSimplifyRange(1250)
	Return True
EndFunc

Func MapTravel_OnPortalCrossed()
	Map_WaitMapIsLoaded()
	Sleep(500)
	SmartCast_Invalidate()
	VanquishCheck_OnMapLoaded(False)
EndFunc

Func MapTravel_NudgePortal($a_f_X, $a_f_Y, $a_i_BeforeMapID, $a_i_Nudges = 6)
	For $k = 1 To $a_i_Nudges
		If $g_b_StopRequested Then Return False
		SmartCast_EnsureReady(False)
		If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_EXPLORABLE Then
			Local $l_f_Mx = Agent_GetAgentInfo(-2, "X")
			Local $l_f_My = Agent_GetAgentInfo(-2, "Y")
			UAI_Fight($l_f_Mx, $l_f_My, MapTravel_GetPortalAggro(), MapTravel_GetPortalFightOut(), MapTravel_GetPortalFinisher())
		EndIf
		Map_Move($a_f_X, $a_f_Y, 0)
		Sleep(350)
		If Map_GetMapID() <> $a_i_BeforeMapID Or Map_GetInstanceInfo("IsLoading") Then
			MapTravel_OnPortalCrossed()
			Return True
		EndIf
	Next
	Return Map_GetMapID() <> $a_i_BeforeMapID
EndFunc

; Pathfinder to one portal-route waypoint (SmartCast + combat; no portal nudge).
Func MapTravel_MoveToPortalPoint($a_f_X, $a_f_Y, $a_s_Label = "")
	If $g_b_StopRequested Then Return False
	Local $l_i_Before = Map_GetMapID()
	Local $l_s_Lbl = $a_s_Label
	If $l_s_Lbl = "" Then $l_s_Lbl = "Portal WP"
	Local Const $GC_F_PORTAL_WP_REACHED = 400
	Local Const $GC_I_PORTAL_WP_RETRIES = 3
	Local $l_i_Retry = 0

	While $l_i_Retry < $GC_I_PORTAL_WP_RETRIES And Not $g_b_StopRequested
		If Map_GetMapID() <> $l_i_Before Or Map_GetInstanceInfo("IsLoading") Then
			MapTravel_OnPortalCrossed()
			Return True
		EndIf

		Local $l_f_DistBefore = Agent_GetDistanceToXY($a_f_X, $a_f_Y)
		Out($l_s_Lbl & " -> (" & Round($a_f_X) & "," & Round($a_f_Y) & ") dist=" & Round($l_f_DistBefore) & _
			" | aggro=" & MapTravel_GetPortalAggro())

		SmartCast_EnsureReady(False)
		MapTravel_ConfigurePathfinderForPortal()
		Local $l_b_Ok = Pathfinder_MoveTo($a_f_X, $a_f_Y, -1, "UAI_GetObstacles", MapTravel_GetPortalAggro(), _
			MapTravel_GetPortalFightOut(), MapTravel_GetPortalFinisher(), MapTravel_GetPortalCallFunc())

		If Map_GetMapID() <> $l_i_Before Or Map_GetInstanceInfo("IsLoading") Then
			MapTravel_OnPortalCrossed()
			Return True
		EndIf

		Local $l_f_DistAfter = Agent_GetDistanceToXY($a_f_X, $a_f_Y)
		If $l_b_Ok And $l_f_DistAfter <= $GC_F_PORTAL_WP_REACHED Then Return False

		$l_i_Retry += 1
		If $l_i_Retry < $GC_I_PORTAL_WP_RETRIES Then
			Out($l_s_Lbl & " retry " & $l_i_Retry & "/" & $GC_I_PORTAL_WP_RETRIES & " dist=" & Round($l_f_DistAfter))
		EndIf
	WEnd

	Return False
EndFunc

; Pathfinder to exit portal + nudge (final point of a transit/outpost route).
Func MapTravel_WalkToPortal($a_f_X, $a_f_Y, $a_s_Label = "")
	If $g_b_StopRequested Then Return False
	Local $l_i_Before = Map_GetMapID()
	Local $l_s_Lbl = $a_s_Label
	If $l_s_Lbl = "" Then $l_s_Lbl = "Portal"
	Out($l_s_Lbl & " portal -> (" & Round($a_f_X) & "," & Round($a_f_Y) & ") | aggro=" & MapTravel_GetPortalAggro())

	If MapTravel_MoveToPortalPoint($a_f_X, $a_f_Y, $l_s_Lbl) Then Return True
	If MapTravel_NudgePortal($a_f_X, $a_f_Y, $l_i_Before) Then Return True
	Return Map_GetMapID() <> $l_i_Before
EndFunc

; Pick the closest portal-route waypoint (resume after sweep / mid-map start).
Func MapTravel_PortalRouteStartIndex(ByRef $a_af2_Points, $a_f_ReachDist = 500)
	If Not IsArray($a_af2_Points) Or UBound($a_af2_Points) < 1 Then Return 0
	Local $l_f_Mx = Agent_GetAgentInfo(-2, "X")
	Local $l_f_My = Agent_GetAgentInfo(-2, "Y")
	Local $l_i_Best = 0
	Local $l_f_BestDist = 999999999
	Local $l_i_Last = UBound($a_af2_Points) - 1
	Local $i
	For $i = 0 To $l_i_Last
		Local $l_f_Dist = Sqrt(($l_f_Mx - $a_af2_Points[$i][0]) ^ 2 + ($l_f_My - $a_af2_Points[$i][1]) ^ 2)
		If $l_f_Dist < $l_f_BestDist Then
			$l_f_BestDist = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	; If already near a point, skip to the next one along the chain.
	If $l_i_Best < $l_i_Last And $l_f_BestDist <= $a_f_ReachDist Then
		Return $l_i_Best + 1
	EndIf
	Return $l_i_Best
EndFunc

; Walk full vanquish transit/outpost path (all WPs, portal nudge on last) — mirrors _Vanquisher_RunAggroPortalPath.
Func MapTravel_RunPortalRoute(ByRef $a_af2_Points, $a_s_Label = "", $a_b_FromNearest = True)
	If Not IsArray($a_af2_Points) Or UBound($a_af2_Points) < 1 Then Return False
	Local $l_i_Last = UBound($a_af2_Points) - 1
	If $l_i_Last < 0 Then Return False
	Local $l_i_Before = Map_GetMapID()
	Local $l_s_Lbl = $a_s_Label
	If $l_s_Lbl = "" Then $l_s_Lbl = "Transit"
	Local $l_i_Start = 0
	If $a_b_FromNearest Then $l_i_Start = MapTravel_PortalRouteStartIndex($a_af2_Points)

	Local $l_s_StartNote = ""
	If $l_i_Start > 0 Then $l_s_StartNote = " from WP " & ($l_i_Start + 1)
	Out($l_s_Lbl & " transit path " & ($l_i_Last + 1 - $l_i_Start) & "/" & ($l_i_Last + 1) & _
		" waypoint(s)" & $l_s_StartNote)

	For $i = $l_i_Start To $l_i_Last - 1
		If $g_b_StopRequested Then Return False
		If MapTravel_MoveToPortalPoint($a_af2_Points[$i][0], $a_af2_Points[$i][1], _
			$l_s_Lbl & "WP " & ($i + 1) & "/" & ($l_i_Last + 1)) Then Return True
	Next

	If MapTravel_WalkToPortal($a_af2_Points[$l_i_Last][0], $a_af2_Points[$l_i_Last][1], _
		$l_s_Lbl & "WP " & ($l_i_Last + 1) & "/" & ($l_i_Last + 1)) Then Return True
	Return Map_GetMapID() <> $l_i_Before
EndFunc

; Explorable spine crossings keyed by map id (independent of target title string).
Func MapTravel_TryGetExplorableCrossingPath($a_i_CurrentMap, $a_i_TargetMap, ByRef $a_a_Path, ByRef $a_s_Label)
	If $a_i_CurrentMap = $NorthKrytaProvince_Map And $a_i_TargetMap = $ScoundrelsRise_Map Then
		$a_a_Path = $aNorthKrytaProvincePortalPath
		$a_s_Label = "NKP->Scoundrels "
		Return True
	EndIf
	Return False
EndFunc

; Resolve GoOutRoutes path for current map + target title.
; OutpostPath matches when standing in that map's outpost (single-map farm, or leaving TOA).
; TransitPath matches when standing on the previous explorable (caravan portal hop).
; $a_b_TransitOnly is kept for callers; map ID already selects outpost vs transit.
Func MapTravel_TryGetHardcodedPortalPath($a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label, $a_b_TransitOnly = False)
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Target = MapCatalog_GetMapID($a_s_TargetTitle)
	If $l_i_Target > 0 And $l_i_Map = $l_i_Target Then Return False

	If $l_i_Target > 0 And MapTravel_TryGetExplorableCrossingPath($l_i_Map, $l_i_Target, $a_a_Path, $a_s_Label) Then
		Return True
	EndIf

	Switch $a_s_TargetTitle
		Case "TheBlackCurtain"
			If $l_i_Map = $TheBlackCurtain_Outpost Then
				$a_a_Path = $aTheBlackCurtainOutpostPath
				$a_s_Label = "TOA->BlackCurtain "
				Return True
			EndIf
		Case "CursedLands"
			If $l_i_Map = $CursedLands_Outpost Then
				$a_a_Path = $aCursedLandsOutpostPath
				$a_s_Label = "TOA->CursedLands "
				Return True
			EndIf
			If $l_i_Map = $CursedLands_Transit Then
				$a_a_Path = $aCursedLandsTransitPath
				$a_s_Label = "Transit->CursedLands "
				Return True
			EndIf
		Case "NeboTerrace"
			If $l_i_Map = $NeboTerrace_Outpost Then
				$a_a_Path = $aNeboTerraceOutpostPath
				$a_s_Label = "TOA->Nebo "
				Return True
			EndIf
			If $l_i_Map = $NeboTerrace_Transit Then
				$a_a_Path = $aNeboTerraceTransitPath
				$a_s_Label = "Transit->Nebo "
				Return True
			EndIf
			If $l_i_Map = $NeboTerrace_Transit2 Then
				$a_a_Path = $aNeboTerraceTransit2Path
				$a_s_Label = "Transit2->Nebo "
				Return True
			EndIf
		Case "NorthKrytaProvince"
			If $l_i_Map = $NorthKrytaProvince_Outpost Then
				$a_a_Path = $aNorthKrytaProvinceOutpostPath
				$a_s_Label = "LA->NKP "
				Return True
			EndIf
		Case "ScoundrelsRise"
			If $l_i_Map = $ScoundrelsRise_Outpost Then
				$a_a_Path = $aScoundrelsRiseOutpostPath
				$a_s_Label = "GoK->Scoundrels "
				Return True
			EndIf
		Case "GriffonsMouth"
			If $l_i_Map = $GriffonsMouth_Outpost Then
				$a_a_Path = $aGriffonsMouthOutpostPath
				$a_s_Label = "GoK->Griffons "
				Return True
			EndIf
			If $l_i_Map = $GriffonsMouth_Transit Then
				$a_a_Path = $aGriffonsMouthTransitPath
				$a_s_Label = "Transit->Griffons "
				Return True
			EndIf
		Case "DeldrimorBowl"
			If $l_i_Map = $DeldrimorBowl_Outpost Then
				$a_a_Path = $aDeldrimorBowlOutpostPath
				$a_s_Label = "Beacon->Deldrimor "
				Return True
			EndIf
		Case "AnvilRock"
			If $l_i_Map = $AnvilRock_Outpost Then
				$a_a_Path = $aAnvilRockOutpostPath
				$a_s_Label = "ITC->Anvil "
				Return True
			EndIf
			If $l_i_Map = $AnvilRock_Transit Then
				$a_a_Path = $aAnvilRockTransitPath
				$a_s_Label = "Transit->Anvil "
				Return True
			EndIf
		Case "IronHorseMine"
			If $l_i_Map = $IronHorseMine_Outpost Then
				$a_a_Path = $aIronHorseMineOutpostPath
				$a_s_Label = "ITC->IHM "
				Return True
			EndIf
			If $l_i_Map = $IronHorseMine_Transit Then
				$a_a_Path = $aIronHorseMineTransitPath
				$a_s_Label = "Transit->IHM "
				Return True
			EndIf
		Case "TravelersVale"
			If $l_i_Map = $TravelersVale_Outpost Then
				$a_a_Path = $aTravelersValeOutpostPath
				$a_s_Label = "Yaks->TV "
				Return True
			EndIf
		Case "AscalonFoothills"
			If $l_i_Map = $AscalonFoothills_Transit Then
				$a_a_Path = $aAscalonFoothillsTransitPath
				$a_s_Label = "TV->AF "
				Return True
			EndIf
		Case "DiessaLowlands"
			If $l_i_Map = $DiessaLowlands_Transit Then
				$a_a_Path = $aDiessaLowlandsTransitPath
				$a_s_Label = "Transit->Diessa "
				Return True
			EndIf
		Case "FlameTempleCorridor"
			If $l_i_Map = $FlameTempleCorridor_Transit Then
				$a_a_Path = $aFlameTempleCorridorTransitPath
				$a_s_Label = "Transit->FTC "
				Return True
			EndIf
		Case "DragonsGullet"
			If $l_i_Map = $DragonsGullet_Transit Then
				$a_a_Path = $aDragonsGulletTransitPath
				$a_s_Label = "Transit->DG "
				Return True
			EndIf
			If $l_i_Map = $DragonsGullet_Transit2 Then
				$a_a_Path = $aDragonsGulletTransit2Path
				$a_s_Label = "Transit2->DG "
				Return True
			EndIf
		Case "TheBreach"
			If $l_i_Map = $TheBreach_Transit3 Then
				$a_a_Path = $aTheBreachReturnFromDGPath
				$a_s_Label = "DG->Breach "
				Return True
			EndIf
			If $l_i_Map = $TheBreach_Transit2 Then
				$a_a_Path = $aTheBreachReturnFromFTCPath
				$a_s_Label = "FTC->Breach "
				Return True
			EndIf
			If $l_i_Map = $TheBreach_Transit Then
				$a_a_Path = $aTheBreachTransitPath
				$a_s_Label = "Transit->Breach "
				Return True
			EndIf
		Case "RegentValley"
			If $l_i_Map = $RegentValley_Transit Then
				$a_a_Path = $aRegentValleyTransitPath
				$a_s_Label = "Transit->RV "
				Return True
			EndIf
		Case "PockmarkFlats"
			If $l_i_Map = $PockmarkFlats_Transit Then
				$a_a_Path = $aPockmarkFlatsTransitPath
				$a_s_Label = "Transit->Pockmark "
				Return True
			EndIf
		Case "EasternFrontier"
			If $l_i_Map = $EasternFrontier_Transit Then
				$a_a_Path = $aEasternFrontierTransitPath
				$a_s_Label = "Transit->EF "
				Return True
			EndIf
	EndSwitch
	Return False
EndFunc

Func MapTravel_TryDirectPortalTo($a_i_TargetMapID, $a_s_Label = "")
	If $a_i_TargetMapID <= 0 Then Return False
	If Map_GetMapID() = $a_i_TargetMapID Then Return True
	If Not Map_GetInstanceInfo("IsExplorable") And Not Map_IsOutpost(Map_GetMapID()) Then Return False

	Local $l_a_Coords = Map_GetExitPortalsCoords(Map_GetMapID(), $a_i_TargetMapID)
	If Not IsArray($l_a_Coords) Then Return False
	If $l_a_Coords[0] = 0 And $l_a_Coords[1] = 0 Then Return False

	Return MapTravel_WalkToPortal($l_a_Coords[0], $l_a_Coords[1], "Portal->" & $a_s_Label)
EndFunc

; Prefer hardcoded transit/outpost paths, then exit-portal coords, then dynamic multi-hop.
Func MapTravel_TryPortalToTarget($a_s_TargetTitle, $a_b_TransitOnly = False)
	Local $l_i_Target = MapCatalog_GetMapID($a_s_TargetTitle)
	If $l_i_Target > 0 And Map_GetMapID() = $l_i_Target Then Return True

	Local $a_Path, $l_s_Label = ""
	Local $b_TriedHardcoded = False
	If MapTravel_TryGetHardcodedPortalPath($a_s_TargetTitle, $a_Path, $l_s_Label, $a_b_TransitOnly) Then
		$b_TriedHardcoded = True
		If MapTravel_RunPortalRoute($a_Path, $l_s_Label) Then Return True
		If $a_s_TargetTitle = "DeldrimorBowl" And Map_GetMapID() = $DeldrimorBowl_Outpost Then
			Return MapTravel_DynamicPortalTo($DeldrimorBowl_Map, "DeldrimorBowl")
		EndIf
		If $a_s_TargetTitle = "OldAscalon" And Map_GetMapID() = $OldAscalon_Transit Then
			Return MapTravel_DynamicPortalTo($OldAscalon_Map, "OldAscalon")
		EndIf
		Out("Hardcoded portal route to " & $a_s_TargetTitle & " did not cross a portal (map " & Map_GetMapID() & ").")
	EndIf

	If Not $b_TriedHardcoded Then
		If Map_GetInstanceInfo("IsExplorable") Or Map_IsOutpost(Map_GetMapID()) Then
			If $l_i_Target > 0 And MapTravel_TryDirectPortalTo($l_i_Target, $a_s_TargetTitle) Then Return True
		EndIf
	EndIf

	Return False
EndFunc

; True when a multi-waypoint crossing route exists (do not beeline via dynamic portal).
Func MapTravel_HasHardcodedPortalPath($a_s_TargetTitle, $a_b_TransitOnly = False)
	Local $a_Path, $l_s_Label = ""
	Return MapTravel_TryGetHardcodedPortalPath($a_s_TargetTitle, $a_Path, $l_s_Label, $a_b_TransitOnly)
EndFunc

Func MapTravel_EnsureHardMode()
	If Not $g_b_HardMode Then Return True
	Local $l_b_Want = True
	Ui_SetDifficulty($l_b_Want)
	Sleep(300)
	If Party_GetPartyContextInfo("IsHardMode") Then Return True
	Game_SwitchMode(1)
	Sleep(400)
	If Party_GetPartyContextInfo("IsHardMode") Then Return True
	Out("WARNING: Hard Mode not set — be party leader in an outpost.")
	Return False
EndFunc

Func MapTravel_TravelToOutpost($a_i_OutpostID)
	If $a_i_OutpostID <= 0 Then Return False
	If Map_GetMapID() = $a_i_OutpostID And Not Map_GetInstanceInfo("IsExplorable") Then Return True

	If Map_GetInstanceInfo("IsExplorable") Then
		Out("Resigning to return to outpost before travel...")
		If Not MapTravel_ResignToOutpost() Then Return False
	EndIf

	If Map_GetMapID() = $a_i_OutpostID Then Return True
	Out("Traveling to outpost MapID=" & $a_i_OutpostID)
	Map_TravelTo($a_i_OutpostID)
	Map_WaitMapIsLoaded()
	Sleep(750)
	Return Map_GetMapID() = $a_i_OutpostID
EndFunc

Func MapTravel_ResignToOutpost()
	If Not Map_GetInstanceInfo("IsExplorable") Then Return True
	Out("Resigning to outpost...")
	Chat_SendChat("resign", "/")
	Local $l_i_T = TimerInit()
	While TimerDiff($l_i_T) < 45000
		If Map_GetInstanceInfo("IsLoading") Then Map_WaitMapIsLoaded()
		If Party_GetPartyContextInfo("IsDefeated") Then
			Map_ReturnToOutpost(True)
			Sleep(1000)
		EndIf
		If Not Map_GetInstanceInfo("IsExplorable") Then
			Sleep(750)
			Return True
		EndIf
		Sleep(500)
	WEnd
	Out("WARNING: Resign/return to outpost timed out.")
	Return Not Map_GetInstanceInfo("IsExplorable")
EndFunc

; Portal-to-portal hops along Map_GetPathWithPortalCoords.
Func MapTravel_DynamicPortalTo($a_i_TargetMapID, $a_s_Label = "")
	If $a_i_TargetMapID <= 0 Then Return False
	If Map_GetMapID() = $a_i_TargetMapID Then Return True
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	Local $l_a_Path = Map_GetPathWithPortalCoords(Map_GetMapID(), $a_i_TargetMapID)
	If Not IsArray($l_a_Path) Or UBound($l_a_Path) < 1 Then
		Out("No dynamic portal path to " & $a_s_Label & " (" & $a_i_TargetMapID & ")")
		Return False
	EndIf

	Local $l_i_Last = UBound($l_a_Path)
	For $i = 0 To $l_i_Last - 1
		If $g_b_StopRequested Then Return False
		If Map_GetMapID() = $a_i_TargetMapID Then Return True
		If $i > 0 And Map_IsOutpost($l_a_Path[$i][0]) Then
			Out("Dynamic path hits outpost — aborting hop.")
			Return False
		EndIf
		Local $l_f_X = $l_a_Path[$i][2]
		Local $l_f_Y = $l_a_Path[$i][3]
		If $l_f_X = 0 And $l_f_Y = 0 Then ContinueLoop
		If Map_GetMapID() <> $l_a_Path[$i][0] Then ExitLoop
		Out("Portal hop toward " & $a_s_Label & ": " & $l_a_Path[$i][1] & " -> (" & Round($l_f_X) & "," & Round($l_f_Y) & ")")
		MapTravel_WalkToPortal($l_f_X, $l_f_Y, "portal ")
		Sleep(400)
	Next
	Return Map_GetMapID() = $a_i_TargetMapID
EndFunc

; Mirror of vanquish GoOut — transit/outpost paths from GoOutRoutes.au3 (vanquish-bot Maps).
Func MapTravel_GoOut($a_s_Title, $a_b_TransitOnly = False)
	$g_s_ActiveTitle = $a_s_Title
	Local $l_i_Target = MapCatalog_GetMapID($a_s_Title)
	If $l_i_Target > 0 And Map_GetMapID() = $l_i_Target Then Return True

	If MapTravel_TryPortalToTarget($a_s_Title, $a_b_TransitOnly) Then Return True

	If Map_GetInstanceInfo("IsExplorable") And $l_i_Target > 0 Then
		If MapTravel_HasHardcodedPortalPath($a_s_Title, $a_b_TransitOnly) Then Return False
		Return MapTravel_DynamicPortalTo($l_i_Target, $a_s_Title)
	EndIf
	Return False
EndFunc

; Enter target explorable.
; TransitOnly False (single-map farm): TravelTo that title's outpost, then OutpostPath.
; TransitOnly True (caravan): stay on the current map and use TransitPath (or OutpostPath if already in the outpost).
Func MapTravel_EnterTitle($a_s_Title, $a_i_MaxAttempts = 8, $a_b_TransitOnly = False)
	Local $l_i_Target = MapCatalog_GetMapID($a_s_Title)
	Local $l_i_Outpost = MapCatalog_GetOutpostID($a_s_Title)
	If $l_i_Target <= 0 Then
		Out("Unknown map title: " & $a_s_Title)
		Return False
	EndIf

	If Map_GetMapID() = $l_i_Target And Map_GetInstanceInfo("IsExplorable") Then
		Out("Already on " & $a_s_Title & " (" & $l_i_Target & ")")
		VanquishCheck_OnMapLoaded(False)
		Return True
	EndIf

	If Not $a_b_TransitOnly Then
		If $l_i_Outpost <= 0 Then $l_i_Outpost = $TheBlackCurtain_Outpost
		Out("Single-map farm: outpost " & $l_i_Outpost & " -> " & $a_s_Title)
		If Not MapTravel_TravelToOutpost($l_i_Outpost) Then
			Out("Failed to travel to outpost " & $l_i_Outpost & " for " & $a_s_Title)
			Return False
		EndIf
	ElseIf Map_GetInstanceInfo("IsExplorable") Then
		Out("Caravan: transit hop to " & $a_s_Title & " from map " & Map_GetMapID())
	EndIf

	MapTravel_EnsureHardMode()
	$g_i_GoOutLastMapHandled = 0

	Local $l_i_Attempt = 0
	While $l_i_Attempt < $a_i_MaxAttempts And Not $g_b_StopRequested
		If Map_GetMapID() = $l_i_Target And Map_GetInstanceInfo("IsExplorable") Then
			VanquishCheck_OnMapLoaded(False)
			Return True
		EndIf
		Out("GoOut attempt " & ($l_i_Attempt + 1) & " for " & $a_s_Title & " (on map " & Map_GetMapID() & ")")
		MapTravel_GoOut($a_s_Title, $a_b_TransitOnly)
		Map_WaitMapIsLoaded()
		Sleep(750)
		If Map_GetMapID() = $l_i_Target Then Return True
		If $a_b_TransitOnly And Map_GetInstanceInfo("IsExplorable") Then
			If MapTravel_DynamicPortalTo($l_i_Target, $a_s_Title) Then Return True
			MapTravel_GoOut($a_s_Title, $a_b_TransitOnly)
		EndIf
		$l_i_Attempt += 1
	WEnd

	Out("Failed to enter " & $a_s_Title & " — current MapID=" & Map_GetMapID())
	Return Map_GetMapID() = $l_i_Target
EndFunc

; From current explorable, pathfinder portal-to-portal until on $a_s_NextTitle.
; Caravan-only: transit paths only (outpost walks not used on the spine).
Func MapTravel_AdvanceToTitle($a_s_NextTitle, $a_i_MaxAttempts = 10)
	Local $l_b_TransitOnly = True
	Local $l_i_Target = MapCatalog_GetMapID($a_s_NextTitle)
	If $l_i_Target <= 0 Then
		Out("AdvanceToTitle: unknown title " & $a_s_NextTitle)
		Return False
	EndIf

	If Map_GetMapID() = $l_i_Target And Map_GetInstanceInfo("IsExplorable") Then
		Out("Already on " & $a_s_NextTitle)
		Return True
	EndIf

	Local $l_i_Attempt = 0
	While $l_i_Attempt < $a_i_MaxAttempts And Not $g_b_StopRequested
		Local $l_i_Before = Map_GetMapID()
		Out("Advance " & ($l_i_Attempt + 1) & ": map " & $l_i_Before & " -> " & $a_s_NextTitle & " (" & $l_i_Target & ")")

		SmartCast_EnsureReady(False)

		If Map_GetInstanceInfo("IsExplorable") Then
			If MapTravel_TryPortalToTarget($a_s_NextTitle, $l_b_TransitOnly) Then
				SmartCast_Invalidate()
				VanquishCheck_OnMapLoaded(False)
				Out("Arrived at " & $a_s_NextTitle & " via portal path.")
				Return True
			EndIf
		EndIf

		MapTravel_GoOut($a_s_NextTitle, $l_b_TransitOnly)
		If Map_GetInstanceInfo("IsLoading") Then Map_WaitMapIsLoaded()
		Sleep(400)
		If Map_GetMapID() = $l_i_Target Then
			Map_WaitMapIsLoaded()
			Sleep(300)
			VanquishCheck_OnMapLoaded(False)
			Out("Arrived at " & $a_s_NextTitle & " via GoOut.")
			SmartCast_Invalidate()
			Return True
		EndIf

		If Map_GetInstanceInfo("IsExplorable") Then
			If Not MapTravel_HasHardcodedPortalPath($a_s_NextTitle, $l_b_TransitOnly) Then
				If MapTravel_DynamicPortalTo($l_i_Target, $a_s_NextTitle) Then
					SmartCast_Invalidate()
					VanquishCheck_OnMapLoaded(False)
					Out("Arrived at " & $a_s_NextTitle & " via dynamic portal.")
					Return True
				EndIf
			EndIf
		EndIf

		If Map_GetMapID() = $l_i_Before Then
			Out("No progress toward " & $a_s_NextTitle & " this attempt.")
		EndIf
		$l_i_Attempt += 1
	WEnd

	Out("Failed to advance to " & $a_s_NextTitle & " — still on MapID=" & Map_GetMapID())
	Return Map_GetMapID() = $l_i_Target
EndFunc
