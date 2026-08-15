#include-once

; Lawnmower grid generation, reachability filter, and progress resume.
; Route storage uses parallel 1D arrays (AutoIt global 2D arrays are unreliable).

#include "MapRoute.au3"

Global $g_a_CoverageX[1]
Global $g_a_CoverageY[1]
Global $g_i_CoverageIndex = 0
Global $g_i_CoverageCount = 0
Global $g_f_CovMinX = 0
Global $g_f_CovMaxX = 0
Global $g_f_CovMinY = 0
Global $g_f_CovMaxY = 0
Global $g_f_GridStep = 2000
Global $g_f_BoundPad = 15000
Global Const $GC_S_COVERAGE_PROGRESS = @ScriptDir & "\coverage_progress.ini"
Global Const $GC_S_COVERAGE_ROUTE = @ScriptDir & "\coverage_route.csv"
Global Const $GC_F_COVERAGE_WAYPOINT_REACHED = 400
; Extra full-route walks after the initial vanquish pass (stop early if the area completes).
Global Const $GC_I_VANQUISH_ROUTE_REPEATS = 2

Global $g_b_CoverageIsVanquishRoute = False
Global $g_i_CoverageRepeatPass = 0
Global $g_b_CoverageHoldSkipPassed = False

; Provided by CombatMapper.au3
Global $g_b_BotRunning = False
Global $g_b_StopRequested = False
Global $g_s_CoverageMapTitle = ""

; Load coverage settings from config.ini and resolve AABB.
; Zero Min/Max bounds => player position +/- BoundPad.
Func Coverage_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"

	$g_f_GridStep = Number(IniRead($a_s_ConfigPath, "Coverage", "GridStep", "2000"))
	$g_f_BoundPad = Number(IniRead($a_s_ConfigPath, "Coverage", "BoundPad", "15000"))
	$g_f_CovMinX = Number(IniRead($a_s_ConfigPath, "Coverage", "MinX", "0"))
	$g_f_CovMaxX = Number(IniRead($a_s_ConfigPath, "Coverage", "MaxX", "0"))
	$g_f_CovMinY = Number(IniRead($a_s_ConfigPath, "Coverage", "MinY", "0"))
	$g_f_CovMaxY = Number(IniRead($a_s_ConfigPath, "Coverage", "MaxY", "0"))

	If $g_f_GridStep <= 0 Then $g_f_GridStep = 2000
	If $g_f_BoundPad <= 0 Then $g_f_BoundPad = 15000

	If $g_f_CovMinX = 0 And $g_f_CovMaxX = 0 And $g_f_CovMinY = 0 And $g_f_CovMaxY = 0 Then
		Local $l_f_X = Agent_GetAgentInfo(-2, "X")
		Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
		$g_f_CovMinX = $l_f_X - $g_f_BoundPad
		$g_f_CovMaxX = $l_f_X + $g_f_BoundPad
		$g_f_CovMinY = $l_f_Y - $g_f_BoundPad
		$g_f_CovMaxY = $l_f_Y + $g_f_BoundPad
	EndIf

	If $g_f_CovMinX > $g_f_CovMaxX Then
		Local $l_f_Tmp = $g_f_CovMinX
		$g_f_CovMinX = $g_f_CovMaxX
		$g_f_CovMaxX = $l_f_Tmp
	EndIf
	If $g_f_CovMinY > $g_f_CovMaxY Then
		Local $l_f_TmpY = $g_f_CovMinY
		$g_f_CovMinY = $g_f_CovMaxY
		$g_f_CovMaxY = $l_f_TmpY
	EndIf
EndFunc

Func _Coverage_ResetRoute()
	ReDim $g_a_CoverageX[1]
	ReDim $g_a_CoverageY[1]
	$g_a_CoverageX[0] = 0
	$g_a_CoverageY[0] = 0
	$g_i_CoverageCount = 0
	$g_i_CoverageIndex = 0
	$g_b_CoverageIsVanquishRoute = False
	$g_i_CoverageRepeatPass = 0
	$g_b_CoverageHoldSkipPassed = False
EndFunc

; Copy parallel X/Y arrays into globals.
Func _Coverage_SetRoute1D(ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count)
	If $a_i_Count < 1 Then
		_Coverage_ResetRoute()
		Return
	EndIf
	If Not IsArray($a_a_X) Or Not IsArray($a_a_Y) Then
		_Coverage_ResetRoute()
		Return
	EndIf
	Local $l_i_UX = UBound($a_a_X)
	Local $l_i_UY = UBound($a_a_Y)
	If $l_i_UX < 1 Or $l_i_UY < 1 Then
		_Coverage_ResetRoute()
		Return
	EndIf
	If $a_i_Count > $l_i_UX Then $a_i_Count = $l_i_UX
	If $a_i_Count > $l_i_UY Then $a_i_Count = $l_i_UY
	$a_i_Count = MapRoute_DedupePath1D($a_a_X, $a_a_Y, $a_i_Count)
	If $a_i_Count < 1 Then
		_Coverage_ResetRoute()
		Return
	EndIf
	ReDim $g_a_CoverageX[$a_i_Count]
	ReDim $g_a_CoverageY[$a_i_Count]
	For $i = 0 To $a_i_Count - 1
		$g_a_CoverageX[$i] = $a_a_X[$i]
		$g_a_CoverageY[$i] = $a_a_Y[$i]
	Next
	$g_i_CoverageCount = $a_i_Count
EndFunc

; Copy local 2D [n][2] grid into global 1D route storage.
Func _Coverage_AssignRoute(ByRef $a_af2_Source, $a_i_Count)
	Local $l_i_Max = _Coverage_PointCount2D($a_af2_Source)
	If $l_i_Max < 1 Or $a_i_Count < 1 Then
		_Coverage_ResetRoute()
		Return
	EndIf
	If $a_i_Count > $l_i_Max Then $a_i_Count = $l_i_Max

	Local $l_a_X[$a_i_Count]
	Local $l_a_Y[$a_i_Count]
	For $i = 0 To $a_i_Count - 1
		$l_a_X[$i] = $a_af2_Source[$i][0]
		$l_a_Y[$i] = $a_af2_Source[$i][1]
	Next
	_Coverage_SetRoute1D($l_a_X, $l_a_Y, $a_i_Count)
EndFunc

Func _Coverage_PointCount2D(ByRef $a_af2_Points)
	If Not IsArray($a_af2_Points) Then Return 0
	If UBound($a_af2_Points, 0) <> 2 Then Return 0
	Local $l_i_U = UBound($a_af2_Points, 1)
	If $l_i_U < 0 Then Return 0
	Return $l_i_U + 1
EndFunc

Func _Coverage_AppendPoint2D(ByRef $a_af2_Points, $a_f_X, $a_f_Y)
	Local $l_i_Count = _Coverage_PointCount2D($a_af2_Points)
	If $l_i_Count < 1 Then
		Local $l_a_New[1][2]
		$l_a_New[0][0] = $a_f_X
		$l_a_New[0][1] = $a_f_Y
		$a_af2_Points = $l_a_New
		Return
	EndIf
	ReDim $a_af2_Points[$l_i_Count + 1][2]
	$a_af2_Points[$l_i_Count][0] = $a_f_X
	$a_af2_Points[$l_i_Count][1] = $a_f_Y
EndFunc

; Build snake/lawnmower lanes from player position outward (fallback when no map route).
; @extended = point count.
Func Coverage_BuildLawnmowerGrid()
	Local $l_f_StartX = Agent_GetAgentInfo(-2, "X")
	Local $l_f_StartY = Agent_GetAgentInfo(-2, "Y")
	Local $l_i_Lanes = Floor(($g_f_BoundPad * 2) / $g_f_GridStep) + 1
	Local $l_i_Cols = Floor(($g_f_BoundPad * 2) / $g_f_GridStep) + 1
	If $l_i_Lanes < 1 Then $l_i_Lanes = 1
	If $l_i_Cols < 1 Then $l_i_Cols = 1

	Local $l_i_Total = $l_i_Lanes * $l_i_Cols
	Local $l_a_Points[$l_i_Total][2]
	Local $l_i_Idx = 0
	Local $l_f_MinX = $l_f_StartX - $g_f_BoundPad
	Local $l_f_MaxX = $l_f_StartX + $g_f_BoundPad
	Local $l_f_MinY = $l_f_StartY - $g_f_BoundPad

	Local $l_i_Lane = 0
	While $l_i_Lane < $l_i_Lanes And $l_i_Idx < $l_i_Total
		Local $l_f_Y = $l_f_MinY + ($l_i_Lane * $g_f_GridStep)
		If Mod($l_i_Lane, 2) = 0 Then
			Local $l_f_X = $l_f_MinX
			While $l_f_X <= $l_f_MaxX + 0.01 And $l_i_Idx < $l_i_Total
				$l_a_Points[$l_i_Idx][0] = $l_f_X
				$l_a_Points[$l_i_Idx][1] = $l_f_Y
				$l_i_Idx += 1
				$l_f_X += $g_f_GridStep
			WEnd
		Else
			Local $l_f_XRev = $l_f_MaxX
			While $l_f_XRev >= $l_f_MinX - 0.01 And $l_i_Idx < $l_i_Total
				$l_a_Points[$l_i_Idx][0] = $l_f_XRev
				$l_a_Points[$l_i_Idx][1] = $l_f_Y
				$l_i_Idx += 1
				$l_f_XRev -= $g_f_GridStep
			WEnd
		EndIf
		$l_i_Lane += 1
	WEnd

	If $l_i_Idx < 1 Then
		$l_a_Points[0][0] = $l_f_StartX
		$l_a_Points[0][1] = $l_f_StartY
		$l_i_Idx = 1
	ElseIf $l_i_Idx < $l_i_Total Then
		ReDim $l_a_Points[$l_i_Idx][2]
	EndIf

	Return SetExtended($l_i_Idx, $l_a_Points)
EndFunc

; @extended = kept count. Returns 2D array for _Coverage_AssignRoute.
Func Coverage_FilterReachable(ByRef $a_af2_Candidates, $a_b_Verbose = True)
	Local $l_a_Reachable[1][2]
	$l_a_Reachable[0][0] = 0
	$l_a_Reachable[0][1] = 0
	Local $l_i_Kept = 0

	Local $l_i_CandCount = _Coverage_PointCount2D($a_af2_Candidates)
	If $l_i_CandCount < 1 Then Return SetExtended(0, $l_a_Reachable)

	Local $l_i_MapID = Map_GetMapID()
	Local $l_f_StartX = Agent_GetAgentInfo(-2, "X")
	Local $l_f_StartY = Agent_GetAgentInfo(-2, "Y")
	Local $l_i_Checked = 0

	If Not Pathfinder_IsMapAvailable($l_i_MapID) Then
		If $a_b_Verbose Then Out("ERROR: Map " & $l_i_MapID & " is not available in Pathfinder maps.rar")
		Return SetExtended(0, $l_a_Reachable)
	EndIf

	For $i = 0 To $l_i_CandCount - 1
		If Not $g_b_BotRunning Or $g_b_StopRequested Then ExitLoop

		$l_i_Checked += 1
		Local $l_f_CellX = $a_af2_Candidates[$i][0]
		Local $l_f_CellY = $a_af2_Candidates[$i][1]

		Local $l_a_Path = Pathfinder_FindPath($l_i_MapID, $l_f_StartX, $l_f_StartY, -1, $l_f_CellX, $l_f_CellY, -1, 0)
		If IsArray($l_a_Path) And UBound($l_a_Path) >= 0 Then
			If $l_i_Kept < 1 Then
				$l_a_Reachable[0][0] = $l_f_CellX
				$l_a_Reachable[0][1] = $l_f_CellY
				$l_i_Kept = 1
			Else
				_Coverage_AppendPoint2D($l_a_Reachable, $l_f_CellX, $l_f_CellY)
				$l_i_Kept += 1
			EndIf
		EndIf

		If $a_b_Verbose And Mod($l_i_Checked, 25) = 0 Then
			Out("Reachability filter: " & $l_i_Checked & "/" & $l_i_CandCount & " (kept " & $l_i_Kept & ")")
		EndIf

		Sleep(10)
	Next

	Return SetExtended($l_i_Kept, $l_a_Reachable)
EndFunc

Func Coverage_ConfigurePathfinder($a_b_Verbose = False)
	Local $l_i_Init = Pathfinder_Initialize()
	If $l_i_Init = 0 Then
		If $a_b_Verbose Then Out("ERROR: Pathfinder_Initialize failed")
		Return False
	ElseIf $l_i_Init = 2 And $a_b_Verbose Then
		Out("WARNING: maps.rar missing - pathfinding may fail")
	EndIf
	; Less frequent recalc reduces path-index resets; tighter simplify keeps routes direct.
	Pathfinder_SetPathUpdateInterval(2500)
	Pathfinder_SetWaypointReachedDistance(200)
	Pathfinder_SetSimplifyRange(900)
	Return True
EndFunc

; Skip waypoints already reached or passed (fight pull / overshoot on vanquish reversals).
; Held at the start of a vanquish repeat so the walk back to waypoint 1 is not skipped.
Func Coverage_TrySkipPassedWaypoints($a_f_ReachDist = $GC_F_COVERAGE_WAYPOINT_REACHED)
	If $g_b_CoverageHoldSkipPassed Then Return
	If $g_i_CoverageCount < 2 Then Return

	While $g_i_CoverageIndex < $g_i_CoverageCount - 1
		Local $l_f_Cx = $g_a_CoverageX[$g_i_CoverageIndex]
		Local $l_f_Cy = $g_a_CoverageY[$g_i_CoverageIndex]
		Local $l_f_Nx = $g_a_CoverageX[$g_i_CoverageIndex + 1]
		Local $l_f_Ny = $g_a_CoverageY[$g_i_CoverageIndex + 1]
		Local $l_f_DistCur = Agent_GetDistanceToXY($l_f_Cx, $l_f_Cy)

		If $l_f_DistCur <= $a_f_ReachDist Then
			Out("Skip reached waypoint " & ($g_i_CoverageIndex + 1) & " dist=" & Round($l_f_DistCur))
			Coverage_Advance()
			ContinueLoop
		EndIf

		Local $l_f_DistNext = Agent_GetDistanceToXY($l_f_Nx, $l_f_Ny)
		If $l_f_DistCur > $a_f_ReachDist And $l_f_DistNext + 50 < $l_f_DistCur Then
			Out("Skip passed waypoint " & ($g_i_CoverageIndex + 1) & " dist=" & Round($l_f_DistCur) & _
				" next=" & Round($l_f_DistNext))
			Coverage_Advance()
			ContinueLoop
		EndIf

		ExitLoop
	WEnd
EndFunc

Func Coverage_BuildRoute($a_b_Verbose = True)
	Coverage_LoadConfig()

	; Prefer hand-tuned vanquish route for this map title (caravan / single-map by title).
	If $g_s_CoverageMapTitle <> "" Then
		Local $l_a_RouteX, $l_a_RouteY
		Local $l_i_RouteCount = MapRoute_TryLoadForTitle($g_s_CoverageMapTitle, $l_a_RouteX, $l_a_RouteY)
		If $l_i_RouteCount > 0 Then
			Coverage_ConfigurePathfinder($a_b_Verbose)
			_Coverage_SetRoute1D($l_a_RouteX, $l_a_RouteY, $l_i_RouteCount)
			$g_i_CoverageIndex = 0
			$g_b_CoverageIsVanquishRoute = True
			$g_i_CoverageRepeatPass = 0
			$g_b_CoverageHoldSkipPassed = False
			Coverage_SaveRoute()
			Coverage_SaveProgress()
			If $a_b_Verbose Then Out("Map route for " & $g_s_CoverageMapTitle & ": " & $l_i_RouteCount & _
				" waypoints (vanquish path, up to " & $GC_I_VANQUISH_ROUTE_REPEATS & " extra passes if still open)")
			Return True
		ElseIf $a_b_Verbose Then
			Out("No hand-tuned route for " & $g_s_CoverageMapTitle & " — using lawnmower fallback.")
		EndIf
	EndIf

	If $a_b_Verbose Then
		Out("Coverage AABB: (" & Round($g_f_CovMinX) & "," & Round($g_f_CovMinY) & ") -> (" & _
			Round($g_f_CovMaxX) & "," & Round($g_f_CovMaxY) & ") step=" & $g_f_GridStep)
	EndIf

	Local $l_a_Grid = Coverage_BuildLawnmowerGrid()
	Local $l_i_GridCount = @extended
	If $a_b_Verbose Then Out("Lawnmower candidates: " & $l_i_GridCount)

	If Not Coverage_ConfigurePathfinder($a_b_Verbose) Then
		_Coverage_ResetRoute()
		Return False
	EndIf

	Local $l_b_Filter = Number(IniRead(@ScriptDir & "\config.ini", "Coverage", "FilterReachable", "0")) <> 0
	If $l_b_Filter Then
		If $a_b_Verbose Then Out("Filtering reachable cells (slow)...")
		Local $l_a_Filtered = Coverage_FilterReachable($l_a_Grid, $a_b_Verbose)
		Local $l_i_Kept = @extended
		_Coverage_AssignRoute($l_a_Filtered, $l_i_Kept)
	Else
		If $a_b_Verbose Then Out("Using full lawnmower grid (FilterReachable=0) — movement starts now.")
		_Coverage_AssignRoute($l_a_Grid, $l_i_GridCount)
	EndIf

	If $g_i_CoverageCount < 1 Then
		_Coverage_ResetRoute()
		If $a_b_Verbose Then Out("Reachable coverage points: 0")
		Return False
	EndIf

	$g_i_CoverageIndex = 0
	$g_b_CoverageIsVanquishRoute = False
	$g_i_CoverageRepeatPass = 0
	$g_b_CoverageHoldSkipPassed = False
	Coverage_SaveRoute()
	Coverage_SaveProgress()

	If $a_b_Verbose Then Out("Reachable coverage points: " & $g_i_CoverageCount)
	Return True
EndFunc

Func Coverage_SaveRoute()
	Local $l_h = FileOpen($GC_S_COVERAGE_ROUTE, $FO_OVERWRITE + $FO_CREATEPATH)
	If $l_h = -1 Then Return False
	FileWriteLine($l_h, "x,y")
	For $i = 0 To $g_i_CoverageCount - 1
		FileWriteLine($l_h, $g_a_CoverageX[$i] & "," & $g_a_CoverageY[$i])
	Next
	FileClose($l_h)
	Return True
EndFunc

Func Coverage_LoadRoute()
	_Coverage_ResetRoute()
	If Not FileExists($GC_S_COVERAGE_ROUTE) Then Return False

	Local $l_a_Lines = FileReadToArray($GC_S_COVERAGE_ROUTE)
	If @error Or Not IsArray($l_a_Lines) Then Return False

	Local $l_a_X[1]
	Local $l_a_Y[1]
	Local $l_i_Count = 0

	For $i = 0 To UBound($l_a_Lines) - 1
		Local $l_s_Line = StringStripWS($l_a_Lines[$i], 3)
		If $l_s_Line = "" Or StringLeft($l_s_Line, 1) = "x" Then ContinueLoop
		Local $l_a_Parts = StringSplit($l_s_Line, ",", $STR_NOCOUNT)
		If Not IsArray($l_a_Parts) Or UBound($l_a_Parts) < 1 Then ContinueLoop
		If $l_i_Count < 1 Then
			$l_a_X[0] = Number($l_a_Parts[0])
			$l_a_Y[0] = Number($l_a_Parts[1])
			$l_i_Count = 1
		Else
			ReDim $l_a_X[$l_i_Count + 1]
			ReDim $l_a_Y[$l_i_Count + 1]
			$l_a_X[$l_i_Count] = Number($l_a_Parts[0])
			$l_a_Y[$l_i_Count] = Number($l_a_Parts[1])
			$l_i_Count += 1
		EndIf
	Next

	If $l_i_Count < 1 Then Return False

	_Coverage_SetRoute1D($l_a_X, $l_a_Y, $l_i_Count)
	Return True
EndFunc

Func Coverage_SaveProgress()
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "MapID", Map_GetMapID())
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "Index", $g_i_CoverageIndex)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "Count", $g_i_CoverageCount)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "MinX", $g_f_CovMinX)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "MaxX", $g_f_CovMaxX)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "MinY", $g_f_CovMinY)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "MaxY", $g_f_CovMaxY)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "GridStep", $g_f_GridStep)
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "IsVanquishRoute", Int($g_b_CoverageIsVanquishRoute))
	IniWrite($GC_S_COVERAGE_PROGRESS, "Progress", "RepeatPass", $g_i_CoverageRepeatPass)
EndFunc

Func Coverage_TryResume($a_b_Verbose = True)
	If Not FileExists($GC_S_COVERAGE_PROGRESS) Then Return False

	Local $l_i_SavedMap = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "MapID", "0"))
	Local $l_i_SavedIndex = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "Index", "0"))
	If $l_i_SavedMap <> Map_GetMapID() Then Return False
	If Not Coverage_LoadRoute() Then Return False
	If $l_i_SavedIndex < 0 Then $l_i_SavedIndex = 0
	If $l_i_SavedIndex >= $g_i_CoverageCount Then Return False

	$g_i_CoverageIndex = $l_i_SavedIndex
	$g_f_CovMinX = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "MinX", String($g_f_CovMinX)))
	$g_f_CovMaxX = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "MaxX", String($g_f_CovMaxX)))
	$g_f_CovMinY = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "MinY", String($g_f_CovMinY)))
	$g_f_CovMaxY = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "MaxY", String($g_f_CovMaxY)))
	$g_f_GridStep = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "GridStep", String($g_f_GridStep)))
	$g_b_CoverageIsVanquishRoute = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "IsVanquishRoute", "0")) <> 0
	$g_i_CoverageRepeatPass = Number(IniRead($GC_S_COVERAGE_PROGRESS, "Progress", "RepeatPass", "0"))
	If $g_i_CoverageRepeatPass < 0 Then $g_i_CoverageRepeatPass = 0
	If $g_i_CoverageRepeatPass > $GC_I_VANQUISH_ROUTE_REPEATS Then $g_i_CoverageRepeatPass = $GC_I_VANQUISH_ROUTE_REPEATS
	$g_b_CoverageHoldSkipPassed = ($g_i_CoverageRepeatPass > 0 And $g_i_CoverageIndex = 0)

	If $a_b_Verbose Then Out("Resuming coverage at " & ($g_i_CoverageIndex + 1) & "/" & $g_i_CoverageCount & Coverage_PassLogSuffix())
	Return True
EndFunc

Func Coverage_ClearProgress()
	If FileExists($GC_S_COVERAGE_PROGRESS) Then FileDelete($GC_S_COVERAGE_PROGRESS)
	If FileExists($GC_S_COVERAGE_ROUTE) Then FileDelete($GC_S_COVERAGE_ROUTE)
	_Coverage_ResetRoute()
EndFunc

Func Coverage_GetCurrentPoint(ByRef $a_f_X, ByRef $a_f_Y)
	If $g_i_CoverageIndex < 0 Or $g_i_CoverageIndex >= $g_i_CoverageCount Then Return False
	$a_f_X = $g_a_CoverageX[$g_i_CoverageIndex]
	$a_f_Y = $g_a_CoverageY[$g_i_CoverageIndex]
	Return True
EndFunc

Func Coverage_Advance()
	$g_i_CoverageIndex += 1
	Coverage_SaveProgress()
EndFunc

; First waypoint of a vanquish repeat was actually reached — skip-passed can resume.
Func Coverage_MarkWaypointReached()
	$g_b_CoverageHoldSkipPassed = False
EndFunc

Func Coverage_IsComplete()
	Return $g_i_CoverageCount <= 0 Or $g_i_CoverageIndex >= $g_i_CoverageCount
EndFunc

Func Coverage_CanStartVanquishRepeat()
	If Not $g_b_CoverageIsVanquishRoute Then Return False
	If $g_i_CoverageCount < 1 Then Return False
	Return $g_i_CoverageRepeatPass < $GC_I_VANQUISH_ROUTE_REPEATS
EndFunc

Func Coverage_StartVanquishRepeat()
	$g_i_CoverageRepeatPass += 1
	$g_i_CoverageIndex = 0
	$g_b_CoverageHoldSkipPassed = True
	Coverage_SaveProgress()
EndFunc

Func Coverage_PassLogSuffix()
	If Not $g_b_CoverageIsVanquishRoute Or $g_i_CoverageRepeatPass < 1 Then Return ""
	Return " (vanquish repeat " & $g_i_CoverageRepeatPass & "/" & $GC_I_VANQUISH_ROUTE_REPEATS & ")"
EndFunc
