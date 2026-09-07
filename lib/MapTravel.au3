#include-once

; Hard-mode travel + GoOut. Primary hop: dest-aware portal XY + Pathfinder + nudge.
#include "SmartCast.au3"
#include "VanquishCheck.au3"
#include "LootPickup.au3"
#include "maps\LocationsIDS.au3"
#include "maps\GoOutRoutes.au3"
#include "maps\GoOutTOAKrytaSpine.au3"
#include "maps\GoOutSouthernShiverpeaksSpine.au3"
#include "maps\GoOutIceCavesSpine.au3"
#include "maps\GoOutOutpostLookup.au3"
#include "PathRoute.au3"

Global $g_b_HardMode = True
Global $g_s_ActiveTitle = ""
Global $g_i_GoOutLastMapHandled = 0
Global $g_i_MapTravelAggro = 0
Global $g_f_MapTravelPortalCorridor = 500
Global $g_f_MapTravelSegFromX = 0
Global $g_f_MapTravelSegFromY = 0
Global $g_f_MapTravelSegToX = 0
Global $g_f_MapTravelSegToY = 0
Global $g_b_MapTravelSegActive = False
Global $g_b_MapTravelCorridorExceeded = False
Global $g_b_MapTravelCorridorLogged = False
Global Const $GC_F_MAPTRAVEL_PORTAL_AGGRO_DEFAULT = 800
Global Const $GC_F_MAPTRAVEL_PORTAL_CORRIDOR_DEFAULT = 500
; True: leave via recorded caravan portal routes (vanquished / outpost / transit-only).
; False: leave from the current farm position via dest-aware Pathfinder (just swept).
Global $g_b_CaravanPreferPortalRoute = True

Func MapTravel_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_i_MapTravelAggro = Number(IniRead($a_s_ConfigPath, "Travel", "PortalAggro", "0"))
	If $g_i_MapTravelAggro < 0 Then $g_i_MapTravelAggro = 0
	$g_f_MapTravelPortalCorridor = Number(IniRead($a_s_ConfigPath, "Travel", "PortalPathCorridor", _
		String($GC_F_MAPTRAVEL_PORTAL_CORRIDOR_DEFAULT)))
	If $g_f_MapTravelPortalCorridor <= 0 Then $g_f_MapTravelPortalCorridor = $GC_F_MAPTRAVEL_PORTAL_CORRIDOR_DEFAULT
	PathRoute_LoadConfig($a_s_ConfigPath)
EndFunc

Func MapTravel_GetPortalAggro()
	If $g_i_MapTravelAggro > 0 Then Return $g_i_MapTravelAggro
	Return $GC_F_MAPTRAVEL_PORTAL_AGGRO_DEFAULT
EndFunc

Func MapTravel_SetPortalSegment($a_f_FromX, $a_f_FromY, $a_f_ToX, $a_f_ToY)
	$g_f_MapTravelSegFromX = $a_f_FromX
	$g_f_MapTravelSegFromY = $a_f_FromY
	$g_f_MapTravelSegToX = $a_f_ToX
	$g_f_MapTravelSegToY = $a_f_ToY
	$g_b_MapTravelSegActive = True
EndFunc

Func MapTravel_ClearPortalSegment()
	$g_b_MapTravelSegActive = False
	$g_b_MapTravelCorridorExceeded = False
	$g_b_MapTravelCorridorLogged = False
EndFunc

Func MapTravel_CheckPortalCorridor()
	If Not $g_b_MapTravelSegActive Then Return
	Local $l_f_Px = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Py = Agent_GetAgentInfo(-2, "Y")
	Local $l_f_Dist = MapTravel_PointToSegmentDist($l_f_Px, $l_f_Py, $g_f_MapTravelSegFromX, $g_f_MapTravelSegFromY, _
		$g_f_MapTravelSegToX, $g_f_MapTravelSegToY)
	If $l_f_Dist <= $g_f_MapTravelPortalCorridor Then Return

	$g_b_MapTravelCorridorExceeded = True
	If Not $g_b_MapTravelCorridorLogged Then
		Out("PathRoute: corridor deviation " & Round($l_f_Dist) & " (limit " & Round($g_f_MapTravelPortalCorridor) & ")")
		$g_b_MapTravelCorridorLogged = True
	EndIf
EndFunc

Func MapTravel_NudgeTowardSegmentMidpoint()
	If Not $g_b_MapTravelSegActive Then Return
	Local $l_f_Mx = ($g_f_MapTravelSegFromX + $g_f_MapTravelSegToX) / 2
	Local $l_f_My = ($g_f_MapTravelSegFromY + $g_f_MapTravelSegToY) / 2
	Out("PathRoute: nudging toward corridor midpoint (" & Round($l_f_Mx) & "," & Round($l_f_My) & ")")
	SmartCast_EnsureReady(False)
	MapTravel_ConfigurePathfinderForPortal()
	PathRoute_MoveTo($l_f_Mx, $l_f_My, $GC_S_PATHROUTE_PROFILE_PORTAL, MapTravel_GetPortalAggro(), _
		MapTravel_GetPortalFightOut(), MapTravel_GetPortalFinisher(), MapTravel_GetPortalCallFunc())
	$g_b_MapTravelCorridorExceeded = False
	$g_b_MapTravelCorridorLogged = False
EndFunc

; Perpendicular distance from (px,py) to the line segment (x1,y1)-(x2,y2).
Func MapTravel_PointToSegmentDist($a_f_Px, $a_f_Py, $a_f_X1, $a_f_Y1, $a_f_X2, $a_f_Y2)
	Local $l_f_Dx = $a_f_X2 - $a_f_X1
	Local $l_f_Dy = $a_f_Y2 - $a_f_Y1
	Local $l_f_LenSq = $l_f_Dx * $l_f_Dx + $l_f_Dy * $l_f_Dy
	If $l_f_LenSq < 1 Then Return Sqrt(($a_f_Px - $a_f_X1) ^ 2 + ($a_f_Py - $a_f_Y1) ^ 2)

	Local $l_f_T = (($a_f_Px - $a_f_X1) * $l_f_Dx + ($a_f_Py - $a_f_Y1) * $l_f_Dy) / $l_f_LenSq
	If $l_f_T < 0 Then $l_f_T = 0
	If $l_f_T > 1 Then $l_f_T = 1
	Local $l_f_Cx = $a_f_X1 + $l_f_T * $l_f_Dx
	Local $l_f_Cy = $a_f_Y1 + $l_f_T * $l_f_Dy
	Return Sqrt(($a_f_Px - $l_f_Cx) ^ 2 + ($a_f_Py - $l_f_Cy) ^ 2)
EndFunc

; True when a living enemy is within PortalAggro of the player (portal walks ignore distant packs).
Func MapTravel_HasNearbyPortalEnemy()
	Local $l_f_Aggro = MapTravel_GetPortalAggro()
	Local $l_a_Agents = Agent_GetAgentArray(0xDB)
	If Not IsArray($l_a_Agents) Or $l_a_Agents[0] < 1 Then Return False

	Local $i
	For $i = 1 To $l_a_Agents[0]
		Local $l_p_Agent = $l_a_Agents[$i]
		If $l_p_Agent = 0 Then ContinueLoop
		Local $l_i_ID = Agent_GetAgentInfo($l_p_Agent, "ID")
		If $l_i_ID = 0 Or $l_i_ID = Agent_GetMyID() Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "Allegiance") <> 3 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "HP") <= 0 Then ContinueLoop
		If Agent_GetAgentInfo($l_p_Agent, "IsDead") Then ContinueLoop
		If Agent_GetDistance($l_p_Agent, -2) <= $l_f_Aggro Then Return True
	Next
	Return False
EndFunc

; Non-blocking combat tick for portal nudge loops (Pathfinder handles fight-while-walking).
Func MapTravel_PortalCombatTick()
	If Map_GetInstanceInfo("Type") <> $GC_I_MAP_TYPE_EXPLORABLE Then Return
	If Not MapTravel_HasNearbyPortalEnemy() Then Return

	Local $l_f_Mx = Agent_GetAgentInfo(-2, "X")
	Local $l_f_My = Agent_GetAgentInfo(-2, "Y")
	Local $l_f_Aggro = MapTravel_GetPortalAggro()
	UAI_UseSkills($l_f_Mx, $l_f_My, $l_f_Aggro, MapTravel_GetPortalFightOut())
EndFunc

; Pathfinder_CallFunc during portal walks: loot + combat logging (Pathfinder UAI_Fight handles combat).
Func MapTravel_Tick()
	MapTravel_WaitIfPaused()
	If $g_b_StopRequested Then Return
	MapTravel_CheckPortalCorridor()
	SmartCast_EnsureReady(False)
	LootPickup_Tick()
	If IsFunc(Execute("CombatLogger_Tick")) Then CombatLogger_Tick()
EndFunc

Func MapTravel_GetPortalFightOut()
	Return MapTravel_GetPortalAggro()
EndFunc

Func MapTravel_GetPortalFinisher()
	If IsDeclared("g_i_FinisherMode") Then Return $g_i_FinisherMode
	Return 0
EndFunc

Func MapTravel_GetPortalCallFunc()
	Return "MapTravel_Tick"
EndFunc

Func MapTravel_ConfigurePathfinderForPortal()
	Return PathRoute_ConfigurePathfinder($GC_S_PATHROUTE_PROFILE_PORTAL, False)
EndFunc

Func MapTravel_OnPortalCrossed()
	Map_WaitMapIsLoaded()
	Sleep(500)
	SmartCast_Invalidate()
	VanquishCheck_OnMapLoaded(False)
EndFunc

Func MapTravel_WaitIfPaused()
	If IsFunc(Execute("CombatMapper_WaitIfPaused")) Then CombatMapper_WaitIfPaused()
EndFunc

; Keep walking into the portal until the map changes (Unlocker-style), not a fixed nudge count.
Func MapTravel_NudgePortal($a_f_X, $a_f_Y, $a_i_BeforeMapID, $a_i_TimeoutMs = 20000)
	Local $l_i_TypeOld = Map_GetInstanceInfo("Type")
	Local $l_h_T = TimerInit()
	Local $l_f_DestX = $a_f_X
	Local $l_f_DestY = $a_f_Y
	Local $l_i_Layer = Number(Agent_GetAgentInfo(-2, "Plane"))
	Local $l_h_Loot = TimerInit()

	While TimerDiff($l_h_T) < $a_i_TimeoutMs
		MapTravel_WaitIfPaused()
		If $g_b_StopRequested Then Return False
		If Agent_GetAgentInfo(-2, "IsDead") Then Return False
		If Party_GetPartyContextInfo("IsDefeated") Then Return False

		If Map_GetMapID() <> $a_i_BeforeMapID Or Map_GetInstanceInfo("IsLoading") _
			Or Map_GetInstanceInfo("Type") <> $l_i_TypeOld Then
			MapTravel_OnPortalCrossed()
			Return True
		EndIf

		SmartCast_EnsureReady(False)
		If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_EXPLORABLE Then
			MapTravel_PortalCombatTick()
			If Combat_ShouldHoldMovement(MapTravel_GetPortalAggro(), MapTravel_GetPortalFightOut()) Then
				If TimerDiff($l_h_Loot) >= 1000 Then
					LootPickup_Sweep()
					$l_h_Loot = TimerInit()
				EndIf
				Sleep(32)
				ContinueLoop
			EndIf
			If TimerDiff($l_h_Loot) >= 1000 Then
				LootPickup_Sweep()
				$l_h_Loot = TimerInit()
			EndIf
		EndIf

		If Agent_GetAgentInfo(-2, "MoveX") = 0 And Agent_GetAgentInfo(-2, "MoveY") = 0 Then
			$l_f_DestX = $a_f_X + Random(-50, 50)
			$l_f_DestY = $a_f_Y + Random(-50, 50)
			Map_MoveLayer($l_f_DestX, $l_f_DestY, $l_i_Layer)
			Sleep(200)
		Else
			Map_MoveLayer($l_f_DestX, $l_f_DestY, $l_i_Layer)
			Sleep(32)
		EndIf
	WEnd

	If Map_GetMapID() <> $a_i_BeforeMapID Or Map_GetInstanceInfo("IsLoading") Then
		MapTravel_OnPortalCrossed()
		Return True
	EndIf
	Out("Portal cross timed out at (" & Round($a_f_X) & "," & Round($a_f_Y) & ") map " & Map_GetMapID())
	Return False
EndFunc

; Pathfinder to one portal-route waypoint (SmartCast + nearby combat while walking; no portal nudge).
Func MapTravel_MoveToPortalPoint($a_f_X, $a_f_Y, $a_s_Label = "", $a_f_SegFromX = -1, $a_f_SegFromY = -1)
	If $g_b_StopRequested Then Return False
	Local $l_i_Before = Map_GetMapID()
	Local $l_s_Lbl = $a_s_Label
	If $l_s_Lbl = "" Then $l_s_Lbl = "Portal WP"
	Local Const $GC_F_PORTAL_WP_REACHED = 400
	Local Const $GC_I_PORTAL_WP_RETRIES = 3
	Local $l_i_Retry = 0

	Local $l_f_FromX = $a_f_SegFromX
	Local $l_f_FromY = $a_f_SegFromY
	If $l_f_FromX < 0 Or $l_f_FromY < 0 Then
		$l_f_FromX = Agent_GetAgentInfo(-2, "X")
		$l_f_FromY = Agent_GetAgentInfo(-2, "Y")
	EndIf
	MapTravel_SetPortalSegment($l_f_FromX, $l_f_FromY, $a_f_X, $a_f_Y)
	$g_b_MapTravelCorridorExceeded = False
	$g_b_MapTravelCorridorLogged = False

	While $l_i_Retry < $GC_I_PORTAL_WP_RETRIES And Not $g_b_StopRequested
		MapTravel_WaitIfPaused()
		If $g_b_StopRequested Then
			MapTravel_ClearPortalSegment()
			Return False
		EndIf
		If Map_GetMapID() <> $l_i_Before Or Map_GetInstanceInfo("IsLoading") Then
			MapTravel_ClearPortalSegment()
			MapTravel_OnPortalCrossed()
			Return True
		EndIf

		Local $l_f_DistBefore = Agent_GetDistanceToXY($a_f_X, $a_f_Y)
		Out($l_s_Lbl & " -> (" & Round($a_f_X) & "," & Round($a_f_Y) & ") dist=" & Round($l_f_DistBefore) & _
			" | path aggro=" & MapTravel_GetPortalAggro() & " corridor=" & Round($g_f_MapTravelPortalCorridor))

		SmartCast_EnsureReady(False)
		Local $l_b_Ok = PathRoute_MoveTo($a_f_X, $a_f_Y, $GC_S_PATHROUTE_PROFILE_PORTAL, MapTravel_GetPortalAggro(), _
			MapTravel_GetPortalFightOut(), MapTravel_GetPortalFinisher(), MapTravel_GetPortalCallFunc())

		If Map_GetMapID() <> $l_i_Before Or Map_GetInstanceInfo("IsLoading") Then
			MapTravel_ClearPortalSegment()
			MapTravel_OnPortalCrossed()
			Return True
		EndIf

		Local $l_f_DistAfter = Agent_GetDistanceToXY($a_f_X, $a_f_Y)
		If $l_b_Ok And $l_f_DistAfter <= $GC_F_PORTAL_WP_REACHED Then
			MapTravel_ClearPortalSegment()
			Return False
		EndIf

		$l_i_Retry += 1
		If $l_i_Retry < $GC_I_PORTAL_WP_RETRIES Then
			Out($l_s_Lbl & " retry " & $l_i_Retry & "/" & $GC_I_PORTAL_WP_RETRIES & " dist=" & Round($l_f_DistAfter))
			If $g_b_MapTravelCorridorExceeded Then MapTravel_NudgeTowardSegmentMidpoint()
		EndIf
	WEnd

	MapTravel_ClearPortalSegment()
	Return False
EndFunc

; Pathfinder to exit portal, then walk into it until the map changes.
Func MapTravel_WalkToPortal($a_f_X, $a_f_Y, $a_s_Label = "", $a_f_SegFromX = -1, $a_f_SegFromY = -1)
	If $g_b_StopRequested Then Return False
	Local $l_i_Before = Map_GetMapID()
	Local $l_s_Lbl = $a_s_Label
	If $l_s_Lbl = "" Then $l_s_Lbl = "Portal"
	Out($l_s_Lbl & " portal -> (" & Round($a_f_X) & "," & Round($a_f_Y) & ") | path aggro=" & MapTravel_GetPortalAggro() & _
		" corridor=" & Round($g_f_MapTravelPortalCorridor))

	If MapTravel_MoveToPortalPoint($a_f_X, $a_f_Y, $l_s_Lbl, $a_f_SegFromX, $a_f_SegFromY) Then Return True
	If Not $g_b_MapTravelSegActive Then
		Local $l_f_FromX = $a_f_SegFromX
		Local $l_f_FromY = $a_f_SegFromY
		If $l_f_FromX < 0 Or $l_f_FromY < 0 Then
			$l_f_FromX = Agent_GetAgentInfo(-2, "X")
			$l_f_FromY = Agent_GetAgentInfo(-2, "Y")
		EndIf
		MapTravel_SetPortalSegment($l_f_FromX, $l_f_FromY, $a_f_X, $a_f_Y)
	EndIf
	Local $l_b_Crossed = MapTravel_NudgePortal($a_f_X, $a_f_Y, $l_i_Before)
	MapTravel_ClearPortalSegment()
	If $l_b_Crossed Then Return True
	Return Map_GetMapID() <> $l_i_Before
EndFunc

; Dest-aware portal XY. GwAu3 exit table first; Pathfinder maps.rar travel_portals
; have no dest_map connections on the Ascalon spine, so no generated catalog.
Func MapTravel_ResolvePortalCoords($a_i_FromMapID, $a_i_ToMapID)
	If $a_i_FromMapID <= 0 Or $a_i_ToMapID <= 0 Then Return False
	If $a_i_FromMapID = $a_i_ToMapID Then Return False

	Local $l_a_Coords = Map_GetExitPortalsCoords($a_i_FromMapID, $a_i_ToMapID)
	If IsArray($l_a_Coords) Then
		If Not ($l_a_Coords[0] = 0 And $l_a_Coords[1] = 0) Then Return $l_a_Coords
	EndIf
	Return False
EndFunc

; Find path to the dest-aware exit portal and travel through (Pathfinder + nudge).
Func MapTravel_FindPathToPortalAndCross($a_i_TargetMapID, $a_s_Label = "")
	If $a_i_TargetMapID <= 0 Then Return False
	If Map_GetMapID() = $a_i_TargetMapID Then Return True
	If Not Map_GetInstanceInfo("IsExplorable") And Not Map_IsOutpost(Map_GetMapID()) Then Return False

	Local $l_a_Coords = MapTravel_ResolvePortalCoords(Map_GetMapID(), $a_i_TargetMapID)
	If Not IsArray($l_a_Coords) Then Return False
	If $l_a_Coords[0] = 0 And $l_a_Coords[1] = 0 Then Return False

	Return MapTravel_WalkToPortal($l_a_Coords[0], $l_a_Coords[1], "Portal->" & $a_s_Label)
EndFunc

; Pick the closest portal-route waypoint (resume after sweep / mid-map start).
Func MapTravel_PortalRouteStartIndex(ByRef $a_af2_Points, $a_f_ReachDist = 500)
	If Not IsArray($a_af2_Points) Or UBound($a_af2_Points) < 1 Then Return 0
	Local $l_a_X, $l_a_Y
	Local $l_i_Count = PathRoute_CopyPath2DTo1D($a_af2_Points, $l_a_X, $l_a_Y)
	If $l_i_Count < 1 Then Return 0
	Local $l_f_Mx = Agent_GetAgentInfo(-2, "X")
	Local $l_f_My = Agent_GetAgentInfo(-2, "Y")
	Return PathRoute_FindJoinIndex($l_a_X, $l_a_Y, $l_i_Count, $l_f_Mx, $l_f_My, $a_f_ReachDist)
EndFunc

; Validate portal anchor chain; returns kept count (0 = validation failed / too few anchors).
Func MapTravel_ValidatePortalPath(ByRef $a_af2_Points, $a_s_Context = "")
	If Not IsArray($a_af2_Points) Or UBound($a_af2_Points) < 1 Then Return 0
	If Not $g_b_PathRouteValidatePortal Then Return UBound($a_af2_Points)

	Local $l_i_MapID = Map_GetMapID()
	Local $l_f_StartX = Agent_GetAgentInfo(-2, "X")
	Local $l_f_StartY = Agent_GetAgentInfo(-2, "Y")
	Local $l_i_Original = UBound($a_af2_Points)
	Local $l_i_Kept = PathRoute_PruneUnreachable2D($l_i_MapID, $a_af2_Points, $l_f_StartX, $l_f_StartY, True, $a_s_Context)
	If $l_i_Kept < 2 Then
		If $l_i_Kept > 0 Then
			Out("PathRoute: portal path has " & $l_i_Kept & "/" & $l_i_Original & " anchors after prune — need >= 2 for corridor walk.")
		EndIf
		Return 0
	EndIf
	Return $l_i_Kept
EndFunc

; Walk full vanquish transit/outpost path (all WPs, portal nudge on last) — mirrors _Vanquisher_RunAggroPortalPath.
Func MapTravel_RunPortalRoute(ByRef $a_af2_Points, $a_s_Label = "", $a_b_FromNearest = True, $a_b_Validate = True)
	If Not IsArray($a_af2_Points) Or UBound($a_af2_Points) < 1 Then Return False
	If $a_b_Validate And $g_b_PathRouteValidatePortal Then
		Local $l_i_Valid = MapTravel_ValidatePortalPath($a_af2_Points, StringStripWS($a_s_Label, 3))
		If $l_i_Valid < 2 Then Return False
	EndIf
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

	PathRoute_LoadConfig()
	PathRoute_BeginSession($GC_S_PATHROUTE_PROFILE_PORTAL)

	Local $i = $l_i_Start
	While $i <= $l_i_Last - 1
		MapTravel_WaitIfPaused()
		If $g_b_StopRequested Then
			PathRoute_EndSession()
			Return False
		EndIf
		If Combat_ShouldHoldMovement(MapTravel_GetPortalAggro(), MapTravel_GetPortalFightOut()) Then
			Out($l_s_Lbl & "waiting for combat to end before next chain set.")
			If Not Combat_WaitUntilClear(MapTravel_GetPortalAggro(), MapTravel_GetPortalFightOut(), _
				MapTravel_GetPortalFinisher(), MapTravel_GetPortalCallFunc()) Then
				PathRoute_EndSession()
				Return False
			EndIf
		EndIf

		Local $l_i_ChainEnd = PathRoute_FindChainEndIndex2D($a_af2_Points, $i, $l_i_Last - 1)
		Local $l_f_FromX = Agent_GetAgentInfo(-2, "X")
		Local $l_f_FromY = Agent_GetAgentInfo(-2, "Y")
		If $i > 0 Then
			$l_f_FromX = $a_af2_Points[$i - 1][0]
			$l_f_FromY = $a_af2_Points[$i - 1][1]
		EndIf
		Local $l_s_Chain = String($i + 1)
		If $l_i_ChainEnd > $i Then $l_s_Chain &= "-" & ($l_i_ChainEnd + 1)
		If MapTravel_MoveToPortalPoint($a_af2_Points[$l_i_ChainEnd][0], $a_af2_Points[$l_i_ChainEnd][1], _
			$l_s_Lbl & "WP " & $l_s_Chain & "/" & ($l_i_Last + 1), $l_f_FromX, $l_f_FromY) Then
			PathRoute_EndSession()
			Return True
		EndIf
		If Not Combat_WaitUntilClear(MapTravel_GetPortalAggro(), MapTravel_GetPortalFightOut(), _
			MapTravel_GetPortalFinisher(), MapTravel_GetPortalCallFunc()) Then
			PathRoute_EndSession()
			Return False
		EndIf
		$i = $l_i_ChainEnd + 1
	WEnd

	Local $l_f_PortalFromX = Agent_GetAgentInfo(-2, "X")
	Local $l_f_PortalFromY = Agent_GetAgentInfo(-2, "Y")
	If $l_i_Last > 0 Then
		$l_f_PortalFromX = $a_af2_Points[$l_i_Last - 1][0]
		$l_f_PortalFromY = $a_af2_Points[$l_i_Last - 1][1]
	EndIf
	Local $l_b_Crossed = MapTravel_WalkToPortal($a_af2_Points[$l_i_Last][0], $a_af2_Points[$l_i_Last][1], _
		$l_s_Lbl & "WP " & ($l_i_Last + 1) & "/" & ($l_i_Last + 1), $l_f_PortalFromX, $l_f_PortalFromY)
	PathRoute_EndSession()
	If $l_b_Crossed Then Return True
	Return Map_GetMapID() <> $l_i_Before
EndFunc

; Explorable spine crossings keyed by map id (independent of target title string).
Func MapTravel_TryGetExplorableCrossingPath($a_i_CurrentMap, $a_i_TargetMap, ByRef $a_a_Path, ByRef $a_s_Label)
	If $a_i_CurrentMap = $NorthKrytaProvince_Map And $a_i_TargetMap = $ScoundrelsRise_Map Then
		$a_a_Path = $aNorthKrytaToScoundrelsRisePortalPath
		$a_s_Label = "NKP->Scoundrels "
		Return True
	EndIf
	Return False
EndFunc

Func MapTravel_CopyReversedPath(ByRef $a_af2_Src, ByRef $a_af2_Dest)
	If Not IsArray($a_af2_Src) Then Return False
	Local $l_i_N = UBound($a_af2_Src)
	If $l_i_N < 1 Then Return False
	Local $l_a[$l_i_N][2]
	Local $i
	For $i = 0 To $l_i_N - 1
		$l_a[$i][0] = $a_af2_Src[$l_i_N - 1 - $i][0]
		$l_a[$i][1] = $a_af2_Src[$l_i_N - 1 - $i][1]
	Next
	$a_af2_Dest = $l_a
	Return True
EndFunc

; Recorded from->to portal walk for the Ascalon caravan spine.
Func MapTravel_TryGetCaravanPortalPath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)
	If $a_i_FromMap <= 0 Or $a_s_TargetTitle = "" Then Return False

	If MapTravel_TryGetTOAKrytaSpinePath($a_i_FromMap, $a_s_TargetTitle, $a_a_Path, $a_s_Label) Then Return True
	If MapTravel_TryGetSouthernShiverpeaksSpinePath($a_i_FromMap, $a_s_TargetTitle, $a_a_Path, $a_s_Label) Then Return True
	If MapTravel_TryGetIceCavesSpinePath($a_i_FromMap, $a_s_TargetTitle, $a_a_Path, $a_s_Label) Then Return True
	If MapTravel_TryGetOutpostPath($a_i_FromMap, $a_s_TargetTitle, $a_a_Path, $a_s_Label) Then Return True

	Switch $a_s_TargetTitle
		Case "CursedLands"
			If $a_i_FromMap = $TheBlackCurtain_Map Then
				$a_a_Path = $aBlackCurtainToCursedLandsPortalPath
				$a_s_Label = "BlackCurtain->Cursed "
				Return True
			EndIf
		Case "NeboTerrace"
			If $a_i_FromMap = $CursedLands_Map Then
				$a_a_Path = $aCursedLandsToNeboTerracePortalPath
				$a_s_Label = "Cursed->Nebo "
				Return True
			EndIf
		Case "NorthKrytaProvince"
			If $a_i_FromMap = $NeboTerrace_Map Then
				$a_a_Path = $aNeboTerraceToNorthKrytaPortalPath
				$a_s_Label = "Nebo->NKP "
				Return True
			EndIf
		Case "ScoundrelsRise"
			If $a_i_FromMap = $NorthKrytaProvince_Map Then
				$a_a_Path = $aNorthKrytaToScoundrelsRisePortalPath
				$a_s_Label = "NKP->Scoundrels "
				Return True
			EndIf
		Case "GriffonsMouth"
			If $a_i_FromMap = $ScoundrelsRise_Map Then
				$a_a_Path = $aScoundrelsRiseToGriffonsMouthPortalPath
				$a_s_Label = "Scoundrels->Griffons "
				Return True
			EndIf
		Case "DeldrimorBowl"
			If $a_i_FromMap = $GriffonsMouth_Map Then
				$a_a_Path = $aGriffonsMouthToDeldrimorBowlPortalPath
				$a_s_Label = "Griffons->Deldrimor "
				Return True
			EndIf
		Case "AnvilRock"
			If $a_i_FromMap = $DeldrimorBowl_Map Then
				$a_a_Path = $aDeldrimorBowlToAnvilRockPortalPath
				$a_s_Label = "Deldrimor->Anvil "
				Return True
			EndIf
		Case "IronHorseMine"
			If $a_i_FromMap = $AnvilRock_Map Then
				$a_a_Path = $aAnvilRockToIronHorseMinePortalPath
				$a_s_Label = "Anvil->IHM "
				Return True
			EndIf
		Case "TravelersVale"
			If $a_i_FromMap = $IronHorseMine_Map Then
				$a_a_Path = $aIronHorseMineToTravelersValePortalPath
				$a_s_Label = "IHM->TV "
				Return True
			EndIf
		Case "AscalonFoothills"
			If $a_i_FromMap = $TravelersVale_Map Then
				$a_a_Path = $aTravelersValeToAscalonFoothillsPortalPath
				$a_s_Label = "TV->AF "
				Return True
			EndIf
		Case "DiessaLowlands"
			If $a_i_FromMap = $AscalonFoothills_Map Then
				$a_a_Path = $aAscalonFoothillsToDiessaLowlandsPortalPath
				$a_s_Label = "AF->Diessa "
				Return True
			EndIf
			; Return from FTC/DG: walk FTC->DG backward to the Diessa portal.
			If $a_i_FromMap = $FlameTempleCorridor_Map Then
				If MapTravel_CopyReversedPath($aFlameTempleCorridorToDragonsGulletPortalPath, $a_a_Path) Then
					$a_s_Label = "FTC->Diessa (rev) "
					Return True
				EndIf
			EndIf
		Case "FlameTempleCorridor"
			If $a_i_FromMap = $DiessaLowlands_Map Then
				$a_a_Path = $aDiessaLowlandsToFlameTempleCorridorPortalPath
				$a_s_Label = "Diessa->FTC "
				Return True
			EndIf
			; Return from Dragon's Gullet: walk FTC->DG backward to the FTC portal.
			If $a_i_FromMap = $DragonsGullet_Map Then
				If MapTravel_CopyReversedPath($aFlameTempleCorridorToDragonsGulletPortalPath, $a_a_Path) Then
					$a_s_Label = "DG->FTC (rev) "
					Return True
				EndIf
			EndIf
		Case "DragonsGullet"
			If $a_i_FromMap = $FlameTempleCorridor_Map Then
				$a_a_Path = $aFlameTempleCorridorToDragonsGulletPortalPath
				$a_s_Label = "FTC->DG "
				Return True
			EndIf
		Case "TheBreach"
			If $a_i_FromMap = $DiessaLowlands_Map Then
				$a_a_Path = $aDiessaLowlandsToTheBreachPortalPath
				$a_s_Label = "Diessa->Breach "
				Return True
			EndIf
			; No DG->Breach recording: reverse back through FTC then Diessa.
			If $a_i_FromMap = $DragonsGullet_Map Then
				If MapTravel_CopyReversedPath($aFlameTempleCorridorToDragonsGulletPortalPath, $a_a_Path) Then
					$a_s_Label = "DG->FTC (rev toward Breach) "
					Return True
				EndIf
			EndIf
			If $a_i_FromMap = $FlameTempleCorridor_Map Then
				If MapTravel_CopyReversedPath($aFlameTempleCorridorToDragonsGulletPortalPath, $a_a_Path) Then
					$a_s_Label = "FTC->Diessa (rev toward Breach) "
					Return True
				EndIf
			EndIf
		Case "OldAscalon"
			If $a_i_FromMap = $TheBreach_Map Then
				$a_a_Path = $aTheBreachToOldAscalonPortalPath
				$a_s_Label = "Breach->OldAscalon "
				Return True
			EndIf
		Case "RegentValley"
			If $a_i_FromMap = $OldAscalon_Map Then
				$a_a_Path = $aOldAscalonToRegentValleyPortalPath
				$a_s_Label = "OldAscalon->Regent "
				Return True
			EndIf
		Case "PockmarkFlats"
			If $a_i_FromMap = $RegentValley_Map Then
				$a_a_Path = $aRegentValleyToPockmarkFlatsPortalPath
				$a_s_Label = "Regent->Pockmark "
				Return True
			EndIf
		Case "EasternFrontier"
			If $a_i_FromMap = $PockmarkFlats_Map Then
				$a_a_Path = $aPockmarkFlatsToEasternFrontierPortalPath
				$a_s_Label = "Pockmark->EF "
				Return True
			EndIf
	EndSwitch
	Return False
EndFunc

Func MapTravel_ShouldPreferCaravanPortalRoute()
	If MapTravel_IsIceCavesOutpost() Then Return True
	If Not Map_GetInstanceInfo("IsExplorable") Then Return True
	If $g_b_CaravanPreferPortalRoute Then Return True
	If VanquishCheck_IsAreaVanquished() Then Return True
	Return False
EndFunc

Func MapTravel_TryRunCaravanPortalRoute($a_s_TargetTitle)
	Local $a_Path, $l_s_Label = ""
	If Not MapTravel_TryGetCaravanPortalPath(Map_GetMapID(), $a_s_TargetTitle, $a_Path, $l_s_Label) Then Return False
	Out("Caravan portal route " & $l_s_Label & "(combat on, F8 pause for manual XY)")
	Local $l_b_Validate = Not Map_IsOutpost(Map_GetMapID())
	If MapTravel_RunPortalRoute($a_Path, $l_s_Label, True, $l_b_Validate) Then Return True
	Local $l_i_Target = MapCatalog_GetMapID($a_s_TargetTitle)
	If $l_i_Target > 0 And $g_b_PathRouteValidatePortal Then
		Out("Caravan portal route " & $l_s_Label & "validation failed — trying dest-aware beeline.")
		If MapTravel_FindPathToPortalAndCross($l_i_Target, $a_s_TargetTitle) Then Return True
	EndIf
	Out("Caravan portal route " & $l_s_Label & "did not cross (map " & Map_GetMapID() & ").")
	Return False
EndFunc

Func MapTravel_TryJoinRecordedPortalRoute($a_s_TargetTitle)
	If Not $g_b_PathRoutePortalJoinRecorded Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False

	Local $a_Path, $l_s_Label = ""
	If Not MapTravel_TryGetCaravanPortalPath(Map_GetMapID(), $a_s_TargetTitle, $a_Path, $l_s_Label) Then Return False

	Local $l_a_X, $l_a_Y
	Local $l_i_Count = PathRoute_CopyPath2DTo1D($a_Path, $l_a_X, $l_a_Y)
	If $l_i_Count < 2 Then Return False

	Local $l_f_Mx = Agent_GetAgentInfo(-2, "X")
	Local $l_f_My = Agent_GetAgentInfo(-2, "Y")
	Local $l_i_Join = PathRoute_FindJoinIndex($l_a_X, $l_a_Y, $l_i_Count, $l_f_Mx, $l_f_My)
	Out("PathRoute: portal join at WP " & ($l_i_Join + 1) & "/" & $l_i_Count & " (" & $l_s_Label & ")")

	Local $l_i_Trimmed = $l_i_Count - $l_i_Join
	If $l_i_Trimmed < 2 Then Return False

	Local $l_a_Joined[$l_i_Trimmed][2]
	Local $i
	For $i = 0 To $l_i_Trimmed - 1
		$l_a_Joined[$i][0] = $l_a_X[$l_i_Join + $i]
		$l_a_Joined[$i][1] = $l_a_Y[$l_i_Join + $i]
	Next

	If MapTravel_RunPortalRoute($l_a_Joined, $l_s_Label & "join ", False) Then Return True
	Return False
EndFunc

; True when dest-aware beeline would skip the recorded DG->FTC->Diessa return.
Func MapTravel_SkipDirectBreachHop($a_s_TargetTitle)
	If $a_s_TargetTitle <> "TheBreach" Then Return False
	Local $l_i_Map = Map_GetMapID()
	Return $l_i_Map = $DragonsGullet_Map Or $l_i_Map = $FlameTempleCorridor_Map
EndFunc

; Long-crossing GoOutRoutes fallback (Pathfinder beeline is tried first).
; $a_b_TransitOnly is kept for callers; map ID already selects the route.
Func MapTravel_TryGetHardcodedPortalPath($a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label, $a_b_TransitOnly = False)
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Target = MapCatalog_GetMapID($a_s_TargetTitle)
	If $l_i_Target > 0 And $l_i_Map = $l_i_Target Then Return False

	If $l_i_Target > 0 And MapTravel_TryGetExplorableCrossingPath($l_i_Map, $l_i_Target, $a_a_Path, $a_s_Label) Then
		Return True
	EndIf

	Switch $a_s_TargetTitle
		Case "GriffonsMouth"
			If $l_i_Map = $GriffonsMouth_Transit Then
				$a_a_Path = $aScoundrelsRiseToGriffonsMouthPortalPath
				$a_s_Label = "Transit->Griffons "
				Return True
			EndIf
		Case "AnvilRock"
			If $l_i_Map = $AnvilRock_Transit Then
				$a_a_Path = $aDeldrimorBowlToAnvilRockPortalPath
				$a_s_Label = "Transit->Anvil "
				Return True
			EndIf
		Case "IronHorseMine"
			If $l_i_Map = $IronHorseMine_Transit Then
				$a_a_Path = $aAnvilRockToIronHorseMinePortalPath
				$a_s_Label = "Transit->IHM "
				Return True
			EndIf
		Case "AscalonFoothills"
			If $l_i_Map = $AscalonFoothills_Transit Then
				$a_a_Path = $aTravelersValeToAscalonFoothillsPortalPath
				$a_s_Label = "TV->AF "
				Return True
			EndIf
		Case "DiessaLowlands"
			If $l_i_Map = $DiessaLowlands_Transit Then
				$a_a_Path = $aAscalonFoothillsToDiessaLowlandsPortalPath
				$a_s_Label = "Transit->Diessa "
				Return True
			EndIf
		Case "FlameTempleCorridor"
			If $l_i_Map = $FlameTempleCorridor_Transit Then
				$a_a_Path = $aDiessaLowlandsToFlameTempleCorridorPortalPath
				$a_s_Label = "Transit->FTC "
				Return True
			EndIf
		Case "DragonsGullet"
			If $l_i_Map = $DragonsGullet_Transit Then
				$a_a_Path = $aFlameTempleCorridorToDragonsGulletPortalPath
				$a_s_Label = "Transit->DG "
				Return True
			EndIf
			If $l_i_Map = $DragonsGullet_Transit2 Then
				$a_a_Path = $aDiessaLowlandsToFlameTempleCorridorPortalPath
				$a_s_Label = "Transit2->DG "
				Return True
			EndIf
		Case "TheBreach"
			If $l_i_Map = $TheBreach_Transit Then
				$a_a_Path = $aDiessaLowlandsToTheBreachPortalPath
				$a_s_Label = "Transit->Breach "
				Return True
			EndIf
	EndSwitch
	Return False
EndFunc

; Vanquished / outpost / transit-only: recorded caravan portal walk first.
; Unvanquished after a sweep: dest-aware Pathfinder from the farm position, then fallbacks.
; DG/FTC -> TheBreach may cross into FTC then Diessa first; only succeed on the target map.
Func MapTravel_TryPortalToTarget($a_s_TargetTitle, $a_b_TransitOnly = False)
	Local $l_i_Target = MapCatalog_GetMapID($a_s_TargetTitle)
	If $l_i_Target > 0 And Map_GetMapID() = $l_i_Target Then Return True

	Local $l_b_PreferRecorded = MapTravel_ShouldPreferCaravanPortalRoute()
	If MapTravel_ForceRecordedPortalRoute($a_s_TargetTitle) Then $l_b_PreferRecorded = True
	If MapTravel_SkipDirectBreachHop($a_s_TargetTitle) Then $l_b_PreferRecorded = True
	Local $l_i_Hop = 0
	While $l_i_Hop < 8 And $l_i_Target > 0 And Map_GetMapID() <> $l_i_Target And Not $g_b_StopRequested
		$l_i_Hop += 1
		Local $l_i_Before = Map_GetMapID()
		If $l_b_PreferRecorded Or $l_i_Hop > 1 Then
			If MapTravel_TryRunCaravanPortalRoute($a_s_TargetTitle) Then
				If Map_GetMapID() = $l_i_Target Then Return True
				If Map_GetMapID() <> $l_i_Before Then
					If Map_GetMapID() <> $l_i_Target Then
						MapTravel_MaybeVanquishTOASpineTransit($a_s_TargetTitle)
						MapTravel_MaybeVanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
						MapTravel_MaybeVanquishIceCavesSpineTransit($a_s_TargetTitle)
					EndIf
					Out("Portal hop landed on map " & Map_GetMapID() & " — continuing to " & $a_s_TargetTitle)
					ContinueLoop
				EndIf
			EndIf
		EndIf
		If Map_GetMapID() = $l_i_Before Then ExitLoop
	WEnd
	If $l_i_Target > 0 And Map_GetMapID() = $l_i_Target Then Return True

	If $l_i_Target > 0 And Not MapTravel_SkipDirectBreachHop($a_s_TargetTitle) Then
		If Not $l_b_PreferRecorded And $g_b_PathRoutePortalJoinRecorded Then
			If MapTravel_TryJoinRecordedPortalRoute($a_s_TargetTitle) Then
				If Map_GetMapID() = $l_i_Target Then Return True
			EndIf
		EndIf
		If Not MapTravel_IsIceCavesOutpost() Then
			If Map_GetInstanceInfo("IsExplorable") Or Map_IsOutpost(Map_GetMapID()) Then
				Local $l_i_BeforePf = Map_GetMapID()
				If MapTravel_FindPathToPortalAndCross($l_i_Target, $a_s_TargetTitle) Then
					If Map_GetMapID() = $l_i_Target Then Return True
					If Map_GetMapID() <> $l_i_BeforePf Then
						MapTravel_MaybeVanquishTOASpineTransit($a_s_TargetTitle)
						MapTravel_MaybeVanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
						MapTravel_MaybeVanquishIceCavesSpineTransit($a_s_TargetTitle)
					EndIf
				EndIf
			EndIf
		EndIf
		If Not MapTravel_IsIceCavesOutpost() And Map_GetInstanceInfo("IsExplorable") Then
			If MapTravel_DynamicPortalTo($l_i_Target, $a_s_TargetTitle) Then Return True
		EndIf
	EndIf

	Local $a_Path, $l_s_Label = ""
	If MapTravel_TryGetHardcodedPortalPath($a_s_TargetTitle, $a_Path, $l_s_Label, $a_b_TransitOnly) Then
		If MapTravel_RunPortalRoute($a_Path, $l_s_Label) Then
			If Map_GetMapID() = $l_i_Target Then Return True
		Else
			Out("Hardcoded portal route to " & $a_s_TargetTitle & " did not cross a portal (map " & Map_GetMapID() & ").")
		EndIf
	EndIf

	If Not $l_b_PreferRecorded Then
		If MapTravel_TryRunCaravanPortalRoute($a_s_TargetTitle) Then
			If Map_GetMapID() = $l_i_Target Then Return True
		EndIf
	EndIf

	Return $l_i_Target > 0 And Map_GetMapID() = $l_i_Target
EndFunc

; True when a long-crossing recorded fallback exists.
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

Func MapTravel_TravelToTempleOfTheAges()
	Out("Map travel to Temple of the Ages (" & $TheBlackCurtain_Outpost & ")")
	If MapTravel_TravelToOutpost($TheBlackCurtain_Outpost) Then
		Out("Arrived at Temple of the Ages.")
		Return True
	EndIf
	Out("Failed to travel to Temple of the Ages.")
	Return False
EndFunc

Func MapTravel_TravelToIceCavesOfSorrow()
	If MapTravel_IsIceCavesOutpost() Then
		Out("Already at Thunderhead Keep.")
		Return True
	EndIf
	Out("Map travel to Thunderhead Keep (" & $IceCavesOfSorrow_Outpost & ")")
	If MapTravel_TravelToOutpost($IceCavesOfSorrow_Outpost) Then
		Out("Arrived at Thunderhead Keep.")
		Return True
	EndIf
	Out("Failed to travel to Thunderhead Keep.")
	Return False
EndFunc

Func MapTravel_TravelToIronMinesOfMoladune()
	If MapTravel_IsIronMinesOfMoladuneOutpost() Then
		Out("Already at Iron Mines of Moladune.")
		Return True
	EndIf
	Out("Map travel to Iron Mines of Moladune (" & $IronMinesOfMoladune_Outpost & ")")
	If MapTravel_TravelToOutpost($IronMinesOfMoladune_Outpost) Then
		Out("Arrived at Iron Mines of Moladune.")
		Return True
	EndIf
	Out("Failed to travel to Iron Mines of Moladune.")
	Return False
EndFunc

Func MapTravel_TravelToCampRankor()
	If MapTravel_IsCampRankorOutpost() Then
		Out("Already at Camp Rankor.")
		Return True
	EndIf
	Out("Map travel to Camp Rankor (" & $CampRankor_Outpost & ")")
	If MapTravel_TravelToOutpost($CampRankor_Outpost) Then
		Out("Arrived at Camp Rankor.")
		Return True
	EndIf
	Out("Failed to travel to Camp Rankor.")
	Return False
EndFunc

Func MapTravel_TravelToOutpost($a_i_OutpostID)
	If $a_i_OutpostID <= 0 Then Return False
	If Map_GetMapID() = $a_i_OutpostID Then
		If $a_i_OutpostID = $IceCavesOfSorrow_Outpost Then Return True
		If $a_i_OutpostID = $TalusChute_Outpost Then Return True
		If $a_i_OutpostID = $IronMinesOfMoladune_Outpost Then Return True
		If $a_i_OutpostID = $MineralSprings_Outpost Then Return True
		If $a_i_OutpostID = $SpearheadPeak_Outpost Then Return True
		If Not Map_GetInstanceInfo("IsExplorable") Then Return True
	EndIf

	If Map_GetInstanceInfo("IsExplorable") Then
		If MapTravel_IsOnSouthernShiverpeaksExplorable() And $a_i_OutpostID <> $CampRankor_Outpost And _
			$a_i_OutpostID <> $TalusChute_Outpost And $a_i_OutpostID <> $IceCavesOfSorrow_Outpost And _
			$a_i_OutpostID <> $IronMinesOfMoladune_Outpost And $a_i_OutpostID <> $MineralSprings_Outpost And _
			$a_i_OutpostID <> $SpearheadPeak_Outpost Then
			Out("Southern Shiverpeaks: skip resign to outpost " & $a_i_OutpostID & " (stay on map " & Map_GetMapID() & ")")
			Return False
		EndIf
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
		MapTravel_WaitIfPaused()
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

; Leave outpost / cross portal toward title (Pathfinder hop, then recorded fallback).
Func MapTravel_GoOut($a_s_Title, $a_b_TransitOnly = False)
	$g_s_ActiveTitle = $a_s_Title
	Local $l_i_Target = MapCatalog_GetMapID($a_s_Title)
	If $l_i_Target > 0 And Map_GetMapID() = $l_i_Target Then Return True
	Return MapTravel_TryPortalToTarget($a_s_Title, $a_b_TransitOnly)
EndFunc

; Enter target explorable.
; TransitOnly False (single-map farm): TravelTo that title's outpost, then Pathfinder to the exit portal.
; TransitOnly True (caravan): stay on the current map and hop via dest-aware portal coords.
Func MapTravel_EnterTitle($a_s_Title, $a_i_MaxAttempts = 8, $a_b_TransitOnly = False)
	Local $l_i_Target = MapCatalog_GetMapID($a_s_Title)
	Local $l_i_Outpost = MapCatalog_GetOutpostID($a_s_Title)
	Local $l_b_TransitOnly = $a_b_TransitOnly
	If $l_i_Target <= 0 Then
		Out("Unknown map title: " & $a_s_Title)
		Return False
	EndIf

	If Map_GetMapID() = $l_i_Target And Map_GetInstanceInfo("IsExplorable") Then
		Out("Already on " & $a_s_Title & " (" & $l_i_Target & ")")
		VanquishCheck_OnMapLoaded(False)
		Return True
	EndIf

	If MapTravel_ShouldTravelToCampRankor($a_s_Title) Then
		Out("Southern Shiverpeaks: map travel to Camp Rankor for " & $a_s_Title)
		$l_b_TransitOnly = False
	ElseIf MapTravel_ShouldTravelToIceCavesForTalus($a_s_Title) Then
		Out("Talus Chute: map travel to Ice Caves of Sorrow")
		$l_b_TransitOnly = False
	ElseIf MapTravel_ShouldTravelToIceDomeEntry($a_s_Title) Then
		Out("IceDome: map travel to Ice Caves of Sorrow")
		$l_b_TransitOnly = False
	ElseIf MapTravel_ShouldTravelToFrozenForestEntry($a_s_Title) Then
		Out("Frozen Forest: map travel to Iron Mines of Moladune")
		$l_b_TransitOnly = False
	ElseIf MapTravel_ShouldTravelToIceFloeEntry($a_s_Title) Then
		Out("Ice Floe: map travel to Thunderhead Keep")
		$l_b_TransitOnly = False
	ElseIf Not $l_b_TransitOnly And (MapTravel_CanContinueTOASpineFromCurrent($a_s_Title) Or _
		MapTravel_CanContinueSouthernShiverpeaksSpineFromCurrent($a_s_Title) Or _
		MapTravel_CanContinueIceCavesSpineFromCurrent($a_s_Title) Or _
		(MapTravel_IsSouthernShiverpeaksRegionTitle($a_s_Title) And MapTravel_IsOnSouthernShiverpeaksExplorable())) Then
		If MapTravel_CanContinueTOASpineFromCurrent($a_s_Title) Then
			Out("TOA spine: portal hop from map " & Map_GetMapID() & " -> " & $a_s_Title)
		ElseIf MapTravel_CanContinueIceCavesSpineFromCurrent($a_s_Title) Then
			Out("IceDome vanquish done: portal to " & $a_s_Title)
		Else
			Out("Southern Shiverpeaks: portal hop from map " & Map_GetMapID() & " -> " & $a_s_Title & " (no resign)")
		EndIf
		$l_b_TransitOnly = True
	EndIf

	If Not $l_b_TransitOnly Then
		If $a_s_Title = "IceDome" Then
			If Not MapTravel_IsIceCavesOfSorrowTown() And Map_GetMapID() <> $TalusChute_Map Then
				Out("IceDome: map travel to Ice Caves of Sorrow -> Talus Chute")
				If Not MapTravel_TravelToIceCavesOfSorrowTown() Then
					Out("Failed to map travel to Ice Caves of Sorrow for " & $a_s_Title)
					Return False
				EndIf
			Else
				Out("IceDome: leaving toward Ice Dome")
			EndIf
		ElseIf $a_s_Title = "FrozenForest" Then
			If Not MapTravel_TravelToIronMinesOfMoladune() Then
				Out("Failed to map travel to Iron Mines of Moladune for " & $a_s_Title)
				Return False
			EndIf
		ElseIf $a_s_Title = "IceFloe" Then
			If Not MapTravel_TravelToIceCavesOfSorrow() Then
				Out("Failed to map travel to Thunderhead Keep for " & $a_s_Title)
				Return False
			EndIf
		ElseIf MapTravel_ShouldTravelToCampRankor($a_s_Title) Then
			If Not MapTravel_TravelToCampRankor() Then
				Out("Failed to map travel to Camp Rankor for " & $a_s_Title)
				Return False
			EndIf
		ElseIf $a_s_Title = "TalusChute" Then
			If Not MapTravel_IsIceCavesOfSorrowTown() Then
				Out("Talus Chute: not on Ice Caves of Sorrow — TravelTo " & $TalusChute_Outpost)
				If Not MapTravel_TravelToIceCavesOfSorrowTown() Then
					Out("Failed to map travel to Ice Caves of Sorrow for " & $a_s_Title)
					Return False
				EndIf
			Else
				Out("Talus Chute: leaving Ice Caves of Sorrow")
			EndIf
		Else
			If $l_i_Outpost <= 0 Then $l_i_Outpost = $TheBlackCurtain_Outpost
			Out("Single-map farm: outpost " & $l_i_Outpost & " -> " & $a_s_Title)
			If Not MapTravel_TravelToOutpost($l_i_Outpost) Then
				Out("Failed to travel to outpost " & $l_i_Outpost & " for " & $a_s_Title)
				Return False
			EndIf
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
		MapTravel_GoOut($a_s_Title, $l_b_TransitOnly)
		Map_WaitMapIsLoaded()
		Sleep(750)
		If Map_GetMapID() = $l_i_Target Then Return True
		If $l_b_TransitOnly And Map_GetInstanceInfo("IsExplorable") Then
			If MapTravel_DynamicPortalTo($l_i_Target, $a_s_Title) Then Return True
			MapTravel_GoOut($a_s_Title, $l_b_TransitOnly)
		EndIf
		$l_i_Attempt += 1
	WEnd

	Out("Failed to enter " & $a_s_Title & " — current MapID=" & Map_GetMapID())
	Return Map_GetMapID() = $l_i_Target
EndFunc

; From current explorable, Pathfinder portal hop until on $a_s_NextTitle.
; Caravan-only: no mid-route TravelTo.
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
			If MapTravel_DynamicPortalTo($l_i_Target, $a_s_NextTitle) Then
				SmartCast_Invalidate()
				VanquishCheck_OnMapLoaded(False)
				Out("Arrived at " & $a_s_NextTitle & " via dynamic portal.")
				Return True
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
