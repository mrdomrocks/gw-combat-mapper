#include-once

; Shared anchor-chain validation for vanquish routes and portal walks.
; Coordinate arrays define strategic waypoints; Pathfinder validates reachability.

; Provided by CombatMapper.au3
Global $g_b_BotRunning = False
Global $g_b_StopRequested = False

Global $g_b_PathRouteValidateVanquish = True
Global $g_b_PathRouteValidatePortal = True
Global $g_b_PathRoutePortalJoinRecorded = True
Global $g_i_PathRouteMaxValidateSegments = 0

Func PathRoute_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_PathRouteValidateVanquish = Number(IniRead($a_s_ConfigPath, "PathRoute", "ValidateVanquishAnchors", "1")) <> 0
	$g_b_PathRouteValidatePortal = Number(IniRead($a_s_ConfigPath, "PathRoute", "ValidatePortalAnchors", "1")) <> 0
	$g_b_PathRoutePortalJoinRecorded = Number(IniRead($a_s_ConfigPath, "PathRoute", "PortalJoinRecordedRoute", "1")) <> 0
	$g_i_PathRouteMaxValidateSegments = Number(IniRead($a_s_ConfigPath, "PathRoute", "MaxValidateSegments", "0"))
	If $g_i_PathRouteMaxValidateSegments < 0 Then $g_i_PathRouteMaxValidateSegments = 0
EndFunc

Func PathRoute_IsSegmentReachable($a_i_MapID, $a_f_X1, $a_f_Y1, $a_f_X2, $a_f_Y2)
	If $a_i_MapID <= 0 Then Return False
	If Not Pathfinder_IsMapAvailable($a_i_MapID) Then Return True

	Local $l_a_Path = Pathfinder_FindPath($a_i_MapID, $a_f_X1, $a_f_Y1, -1, $a_f_X2, $a_f_Y2, -1, 0)
	If IsArray($l_a_Path) And UBound($l_a_Path) >= 0 Then Return True
	Return False
EndFunc

; Walk anchor chain from start position; prune unreachable points in-place.
; Returns kept count (0 if none reachable).
Func PathRoute_ValidateChain($a_i_MapID, ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, $a_f_StartX, $a_f_StartY, _
	$a_b_Verbose = True, $a_s_Context = "")
	If $a_i_Count < 1 Then Return 0
	If Not IsArray($a_a_X) Or Not IsArray($a_a_Y) Then Return 0

	If Not Pathfinder_IsMapAvailable($a_i_MapID) Then
		If $a_b_Verbose Then
			Local $l_s_Ctx = ""
			If $a_s_Context <> "" Then $l_s_Ctx = " (" & $a_s_Context & ")"
			Out("PathRoute: map " & $a_i_MapID & " not in maps.rar — using raw anchors" & $l_s_Ctx)
		EndIf
		Return $a_i_Count
	EndIf

	Local $l_a_KeptX[$a_i_Count]
	Local $l_a_KeptY[$a_i_Count]
	Local $l_i_Kept = 0
	Local $l_f_LastX = $a_f_StartX
	Local $l_f_LastY = $a_f_StartY
	Local $l_i_Checked = 0
	Local $l_i_MaxCheck = $a_i_Count
	If $g_i_PathRouteMaxValidateSegments > 0 And $g_i_PathRouteMaxValidateSegments < $l_i_MaxCheck Then
		$l_i_MaxCheck = $g_i_PathRouteMaxValidateSegments
	EndIf

	For $i = 0 To $a_i_Count - 1
		If $l_i_Checked >= $l_i_MaxCheck Then
			For $j = $i To $a_i_Count - 1
				$l_a_KeptX[$l_i_Kept] = $a_a_X[$j]
				$l_a_KeptY[$l_i_Kept] = $a_a_Y[$j]
				$l_i_Kept += 1
			Next
			ExitLoop
		EndIf

		If Not $g_b_BotRunning Or $g_b_StopRequested Then ExitLoop

		$l_i_Checked += 1
		Local $l_f_AnchorX = $a_a_X[$i]
		Local $l_f_AnchorY = $a_a_Y[$i]

		If PathRoute_IsSegmentReachable($a_i_MapID, $l_f_LastX, $l_f_LastY, $l_f_AnchorX, $l_f_AnchorY) Then
			$l_a_KeptX[$l_i_Kept] = $l_f_AnchorX
			$l_a_KeptY[$l_i_Kept] = $l_f_AnchorY
			$l_f_LastX = $l_f_AnchorX
			$l_f_LastY = $l_f_AnchorY
			$l_i_Kept += 1
		ElseIf $a_b_Verbose Then
			Out("PathRoute: pruned WP " & ($i + 1) & " (" & Round($l_f_AnchorX) & "," & Round($l_f_AnchorY) & _
				") — unreachable from previous kept anchor")
		EndIf

		Sleep(10)
	Next

	If $l_i_Kept < 1 Then
		If $a_b_Verbose Then
			Local $l_s_CtxZero = "PathRoute: kept 0/" & $a_i_Count & " anchors (mapID=" & $a_i_MapID & ")"
			If $a_s_Context <> "" Then $l_s_CtxZero &= " " & $a_s_Context
			Out($l_s_CtxZero)
		EndIf
		Return 0
	EndIf

	ReDim $a_a_X[$l_i_Kept]
	ReDim $a_a_Y[$l_i_Kept]
	For $i = 0 To $l_i_Kept - 1
		$a_a_X[$i] = $l_a_KeptX[$i]
		$a_a_Y[$i] = $l_a_KeptY[$i]
	Next

	If $a_b_Verbose Then
		Local $l_s_Msg = "PathRoute: kept " & $l_i_Kept & "/" & $a_i_Count & " anchors (mapID=" & $a_i_MapID & ")"
		If $a_s_Context <> "" Then $l_s_Msg &= " " & $a_s_Context
		Out($l_s_Msg)
		If $l_i_Kept < $a_i_Count / 2 Then
			Out("PathRoute: WARNING — pruned >50% of anchors; route may be stale or mesh mismatch.")
		EndIf
	EndIf

	Return $l_i_Kept
EndFunc

; Alias for Coverage and MapTravel callers.
Func PathRoute_PruneUnreachable($a_i_MapID, ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, $a_f_StartX, $a_f_StartY, _
	$a_b_Verbose = True, $a_s_Context = "")
	Return PathRoute_ValidateChain($a_i_MapID, $a_a_X, $a_a_Y, $a_i_Count, $a_f_StartX, $a_f_StartY, $a_b_Verbose, $a_s_Context)
EndFunc

; Nearest anchor index for hybrid portal join (mirrors MapTravel_PortalRouteStartIndex on 1D arrays).
Func PathRoute_FindJoinIndex(ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, $a_f_Px, $a_f_Py, $a_f_ReachDist = 500)
	If $a_i_Count < 1 Then Return 0
	If Not IsArray($a_a_X) Or Not IsArray($a_a_Y) Then Return 0

	Local $l_i_Best = 0
	Local $l_f_BestDist = 999999999
	Local $l_i_Last = $a_i_Count - 1

	For $i = 0 To $l_i_Last
		Local $l_f_Dist = Sqrt(($a_f_Px - $a_a_X[$i]) ^ 2 + ($a_f_Py - $a_a_Y[$i]) ^ 2)
		If $l_f_Dist < $l_f_BestDist Then
			$l_f_BestDist = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next

	If $l_i_Best < $l_i_Last And $l_f_BestDist <= $a_f_ReachDist Then Return $l_i_Best + 1
	Return $l_i_Best
EndFunc

; Copy 2D [n][2] portal path into parallel 1D arrays. Returns count.
Func PathRoute_CopyPath2DTo1D(ByRef $a_af2_Source, ByRef $a_a_X, ByRef $a_a_Y)
	If Not IsArray($a_af2_Source) Then Return 0
	Local $l_i_Count = UBound($a_af2_Source)
	If $l_i_Count < 1 Then Return 0

	Local $l_a_X[$l_i_Count]
	Local $l_a_Y[$l_i_Count]
	For $i = 0 To $l_i_Count - 1
		$l_a_X[$i] = $a_af2_Source[$i][0]
		$l_a_Y[$i] = $a_af2_Source[$i][1]
	Next
	$a_a_X = $l_a_X
	$a_a_Y = $l_a_Y
	Return $l_i_Count
EndFunc

; Build 2D [n][2] array from parallel 1D arrays.
Func PathRoute_CopyPath1DTo2D(ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, ByRef $a_af2_Dest)
	If $a_i_Count < 1 Then Return False
	If Not IsArray($a_a_X) Or Not IsArray($a_a_Y) Then Return False

	Local $l_a[$a_i_Count][2]
	For $i = 0 To $a_i_Count - 1
		$l_a[$i][0] = $a_a_X[$i]
		$l_a[$i][1] = $a_a_Y[$i]
	Next
	$a_af2_Dest = $l_a
	Return True
EndFunc

; Prune unreachable anchors on a 2D portal path; returns kept count (0 on failure).
Func PathRoute_PruneUnreachable2D($a_i_MapID, ByRef $a_af2_Points, $a_f_StartX, $a_f_StartY, _
	$a_b_Verbose = True, $a_s_Context = "")
	Local $l_a_X, $l_a_Y
	Local $l_i_Count = PathRoute_CopyPath2DTo1D($a_af2_Points, $l_a_X, $l_a_Y)
	If $l_i_Count < 1 Then Return 0

	Local $l_i_Kept = PathRoute_PruneUnreachable($a_i_MapID, $l_a_X, $l_a_Y, $l_i_Count, $a_f_StartX, $a_f_StartY, _
		$a_b_Verbose, $a_s_Context)
	If $l_i_Kept < 1 Then Return 0

	PathRoute_CopyPath1DTo2D($l_a_X, $l_a_Y, $l_i_Kept, $a_af2_Points)
	Return $l_i_Kept
EndFunc

; Validate 2D candidate grid (lawnmower) from player position. @extended = kept count.
Func PathRoute_FilterReachable2D(ByRef $a_af2_Candidates, $a_i_CandCount, $a_b_Verbose = True)
	Local $l_a_Reachable[1][2]
	$l_a_Reachable[0][0] = 0
	$l_a_Reachable[0][1] = 0
	If $a_i_CandCount < 1 Then Return SetExtended(0, $l_a_Reachable)

	Local $l_i_MapID = Map_GetMapID()
	Local $l_f_StartX = Agent_GetAgentInfo(-2, "X")
	Local $l_f_StartY = Agent_GetAgentInfo(-2, "Y")

	Local $l_a_X[$a_i_CandCount]
	Local $l_a_Y[$a_i_CandCount]
	For $i = 0 To $a_i_CandCount - 1
		$l_a_X[$i] = $a_af2_Candidates[$i][0]
		$l_a_Y[$i] = $a_af2_Candidates[$i][1]
	Next

	Local $l_i_Kept = PathRoute_ValidateChain($l_i_MapID, $l_a_X, $l_a_Y, $a_i_CandCount, $l_f_StartX, $l_f_StartY, _
		$a_b_Verbose, "lawnmower")
	If $l_i_Kept < 1 Then Return SetExtended(0, $l_a_Reachable)

	ReDim $l_a_Reachable[$l_i_Kept][2]
	For $i = 0 To $l_i_Kept - 1
		$l_a_Reachable[$i][0] = $l_a_X[$i]
		$l_a_Reachable[$i][1] = $l_a_Y[$i]
	Next
	Return SetExtended($l_i_Kept, $l_a_Reachable)
EndFunc
