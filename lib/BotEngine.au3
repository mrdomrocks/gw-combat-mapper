#include-once

; Shared bot run loop for Combat Mapper and Vanquish Bot.
; Launchers must define GUI control handles and $GC_S_CONFIG before including this file.

Global $g_b_CombatLoggingEnabled = False
Global $g_b_HeroTeamEnabled = False

; Optional launcher hook. Sets @error = 1 if the function is not defined.
Func BotEngine_CallIfExists($a_s_Name, $a_v1 = Default)
	Local $l_v_Ret
	If $a_v1 = Default Then
		$l_v_Ret = Call($a_s_Name)
	Else
		$l_v_Ret = Call($a_s_Name, $a_v1)
	EndIf
	If @error = 0xDEAD And @extended = 0xBEEF Then Return SetError(1, 0, "")
	Return $l_v_Ret
EndFunc

Func BotEngine_Start()
	Local $l_s_MainCharName = GUICtrlRead($g_h_NameCombo)
	If $l_s_MainCharName = "" Then
		If Core_Initialize(ProcessExists("gw.exe"), True) = 0 Then
			MsgBox(0, "Error", "Guild Wars is not running.")
			Return
		EndIf
	ElseIf $g_i_ProcessID Then
		If Core_Initialize(Number($g_i_ProcessID, 2), True) = 0 Then
			MsgBox(0, "Error", "Could not find ProcessID")
			Return
		EndIf
	Else
		If Core_Initialize($l_s_MainCharName, True) = 0 Then
			MsgBox(0, "Error", "Could not find Guild Wars client for '" & $l_s_MainCharName & "'")
			Return
		EndIf
	EndIf

	$g_b_BotCoreInitialized = True
	$g_b_BotRunning = True
	$g_b_StopRequested = False
	$g_b_PauseRequested = False
	$g_b_ResumeRequested = BitAND(GUICtrlRead($g_h_ResumeCheckbox), $GUI_CHECKED) = $GUI_CHECKED
	$g_b_HardMode = BitAND(GUICtrlRead($g_h_HardModeCheckbox), $GUI_CHECKED) = $GUI_CHECKED
	$g_s_SelectedTarget = GUICtrlRead($g_h_TargetCombo)
	$g_b_CaravanSkipVanquished = GetChecked($g_h_SkipVanquishedCheckbox)
	MapTravel_LoadConfig($GC_S_CONFIG)
	Combat_LoadConfig($GC_S_CONFIG)
	If $g_b_CombatLoggingEnabled Then CombatLogger_LoadConfig($GC_S_CONFIG)
	LootPickup_LoadConfig($GC_S_CONFIG)

	If $g_b_HeroTeamEnabled Then
		Local $l_s_HeroErr = BotEngine_CallIfExists("HeroTeam_ValidateBeforeRun", $g_s_SelectedTarget)
		Local $l_i_HeroCallErr = @error
		If $l_i_HeroCallErr = 0 And $l_s_HeroErr <> "" Then
			Out($l_s_HeroErr)
			MsgBox(0, "Hero Team", $l_s_HeroErr)
			$g_b_BotRunning = False
			Return
		EndIf
		BotEngine_CallIfExists("HeroTeam_SaveConfig")
	EndIf

	BotEngine_CallIfExists("_BotHook_OnBeforeRun")
	CaravanGui_SaveSelection()
	If $g_b_HardMode Then
		IniWrite($GC_S_CONFIG, "Travel", "HardMode", "1")
	Else
		IniWrite($GC_S_CONFIG, "Travel", "HardMode", "0")
	EndIf
	If $g_b_CaravanSkipVanquished Then
		IniWrite($GC_S_CONFIG, "Travel", "SkipVanquished", "1")
	Else
		IniWrite($GC_S_CONFIG, "Travel", "SkipVanquished", "0")
	EndIf
	IniWrite($GC_S_CONFIG, "Travel", "LastTarget", $g_s_SelectedTarget)

	BotEngine_SetRunningUi(True)
	$g_b_PauseRequested = False

	WinSetTitle($g_h_MainGui, "", Player_GetCharName() & " - " & $GC_S_BOT_TITLE)
	Out("Initialized: " & Player_GetCharName() & " | MapID=" & Map_GetMapID() & _
		" | Target=" & $g_s_SelectedTarget & " | HM=" & $g_b_HardMode)
	BotEngine_CallIfExists("_BotHook_PrintInitControls")
	If @error Then Out("Controls: F8 pause/resume | F9 stop")

	If MapCatalog_IsSequenceSelection($g_s_SelectedTarget) Then
		RunCaravanSequence()
	ElseIf MapCatalog_IsRegionSelection($g_s_SelectedTarget) Then
		RunRegionMapList()
	ElseIf MapCatalog_IsCurrentMapSelection($g_s_SelectedTarget) Then
		If $g_b_HardMode Then MapTravel_EnsureHardMode()
		RunCoverageSweep()
	Else
		RunSingleMap($g_s_SelectedTarget)
	EndIf
EndFunc

Func BotEngine_SetRunningUi($a_b_Running)
	If $a_b_Running Then
		GUICtrlSetState($g_h_StartButton, $GUI_DISABLE)
		GUICtrlSetState($g_h_PauseCheckbox, $GUI_ENABLE)
		GUICtrlSetState($g_h_StopButton, $GUI_ENABLE)
		GUICtrlSetState($g_h_NameCombo, $GUI_DISABLE)
		GUICtrlSetState($g_h_RefreshButton, $GUI_DISABLE)
		GUICtrlSetState($g_h_TargetCombo, $GUI_DISABLE)
		GUICtrlSetState($g_h_CaravanMapList, $GUI_DISABLE)
		GUICtrlSetState($g_h_CaravanAllButton, $GUI_DISABLE)
		GUICtrlSetState($g_h_CaravanNoneButton, $GUI_DISABLE)
		GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_DISABLE)
		GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
		BotEngine_CallIfExists("_BotHook_OnSetRunningUi", True)
	Else
		BotEngine_SetIdleUiState()
	EndIf
EndFunc

Func StopBot()
	$g_b_StopRequested = True
	$g_b_PauseRequested = False
	$g_b_BotRunning = False
	Agent_CancelAction()
	Out("Stop requested — will halt after the current segment when possible.")
	BotEngine_SetIdleUiState()
	UpdateStatusLabel("stopped")
EndFunc

Func BotEngine_PollGuiHooks()
	BotEngine_CallIfExists("_BotHook_PollDuringTick")
	If @error Then BotEngine_PollPause()
EndFunc

Func BotEngine_PollPause()
	If Not $g_b_BotRunning Then Return
	Local $bWant = GetChecked($g_h_PauseCheckbox)
	If $bWant = $g_b_PauseRequested Then Return
	$g_b_PauseRequested = $bWant
	If $bWant Then
		Agent_CancelAction()
		BotEngine_CallIfExists("_BotHook_OnPauseChanged", True)
		If @error Then
			Out("Paused — F8 to resume.")
			UpdateStatusLabel("PAUSED")
		EndIf
	Else
		BotEngine_CallIfExists("_BotHook_OnPauseChanged", False)
		If @error Then
			Out("Resumed.")
			UpdateStatusLabel("running")
		EndIf
	EndIf
EndFunc

Func BotEngine_OnPauseCheckbox()
	BotEngine_PollPause()
EndFunc

Func HotKey_TogglePause()
	If Not $g_b_BotRunning Then Return
	If GetChecked($g_h_PauseCheckbox) Then
		GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
	Else
		GUICtrlSetState($g_h_PauseCheckbox, $GUI_CHECKED)
	EndIf
	BotEngine_PollPause()
EndFunc

Func HotKey_Stop()
	If Not $g_b_BotRunning Then Return
	$g_b_StopRequested = True
	$g_b_BotRunning = False
	$g_b_PauseRequested = False
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
	Agent_CancelAction()
	Out("Stop (F9).")
EndFunc

Func BotEngine_WaitIfPaused()
	BotEngine_PollGuiHooks()
	If Not $g_b_PauseRequested Then Return
	Agent_CancelAction()
	While $g_b_PauseRequested And Not $g_b_StopRequested
		Sleep(100)
		BotEngine_PollGuiHooks()
	WEnd
EndFunc

Func BotEngine_SetIdleUiState()
	$g_b_StartRequested = False
	$g_b_PauseRequested = False
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
	GUICtrlSetState($g_h_StartButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_DISABLE)
	GUICtrlSetState($g_h_StopButton, $GUI_DISABLE)
	GUICtrlSetState($g_h_NameCombo, $GUI_ENABLE)
	GUICtrlSetState($g_h_RefreshButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_TargetCombo, $GUI_ENABLE)
	GUICtrlSetState($g_h_CaravanMapList, $GUI_ENABLE)
	GUICtrlSetState($g_h_CaravanAllButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_CaravanNoneButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_ENABLE)
	BotEngine_CallIfExists("_BotHook_OnSetIdleUiState")
EndFunc

Func BotEngine_OnBeforeMapFarm($a_s_Title)
	If Not $g_b_HeroTeamEnabled Then Return
	BotEngine_CallIfExists("HeroTeam_SetupForTitle", $a_s_Title)
EndFunc

; TOA spine maps in farm order (Talmark -> Stingray -> Tears).
Func BotEngine_GetTOAKrytaSpinePipe($a_s_Pipe)
	Local Const $l_as_Spine[3] = ["TalmarkWilderness", "StingrayStrand", "TearsoftheFallen"]
	Local $l_s = ""
	Local $i
	For $i = 0 To 2
		If StringInStr("|" & $a_s_Pipe & "|", "|" & $l_as_Spine[$i] & "|") Then
			If $l_s <> "" Then $l_s &= "|"
			$l_s &= $l_as_Spine[$i]
		EndIf
	Next
	Return $l_s
EndFunc

; Southern Shiverpeaks spine in farm order (Talus from Ice Caves, then Camp Rankor -> Snake -> Dreadnought -> Lornar).
Func BotEngine_GetSouthernShiverpeaksSpinePipe($a_s_Pipe)
	Local Const $l_as_Spine[4] = ["TalusChute", "SnakeDance", "DreadnoughtsDrift", "LornarsPass"]
	Local $l_s = ""
	Local $i
	For $i = 0 To 3
		If StringInStr("|" & $a_s_Pipe & "|", "|" & $l_as_Spine[$i] & "|") Then
			If $l_s <> "" Then $l_s &= "|"
			$l_s &= $l_as_Spine[$i]
		EndIf
	Next
	Return $l_s
EndFunc

; Ice Caves spine maps in farm order (Ice Dome -> Frozen Forest -> Ice Floe).
Func BotEngine_GetIceCavesSpinePipe($a_s_Pipe)
	Local Const $l_as_Spine[3] = ["IceDome", "FrozenForest", "IceFloe"]
	Local $l_s = ""
	Local $i
	For $i = 0 To 2
		If StringInStr("|" & $a_s_Pipe & "|", "|" & $l_as_Spine[$i] & "|") Then
			If $l_s <> "" Then $l_s &= "|"
			$l_s &= $l_as_Spine[$i]
		EndIf
	Next
	Return $l_s
EndFunc

Func BotEngine_CountPipeTitles($a_s_Pipe)
	If $a_s_Pipe = "" Then Return 0
	Local $l_a = StringSplit($a_s_Pipe, "|")
	If Not IsArray($l_a) Then Return 0
	Return $l_a[0]
EndFunc

Func BotEngine_RemovePipeTitles($a_s_Pipe, $a_s_RemovePipe)
	If $a_s_Pipe = "" Then Return ""
	If $a_s_RemovePipe = "" Then Return $a_s_Pipe
	Local $l_a_Remove = StringSplit($a_s_RemovePipe, "|")
	Local $l_a_All = StringSplit($a_s_Pipe, "|")
	If Not IsArray($l_a_All) Then Return ""
	Local $l_s = ""
	Local $i, $j, $l_b_Skip
	For $i = 1 To $l_a_All[0]
		$l_b_Skip = False
		If IsArray($l_a_Remove) Then
			For $j = 1 To $l_a_Remove[0]
				If $l_a_All[$i] = $l_a_Remove[$j] Then
					$l_b_Skip = True
					ExitLoop
				EndIf
			Next
		EndIf
		If Not $l_b_Skip Then
			If $l_s <> "" Then $l_s &= "|"
			$l_s &= $l_a_All[$i]
		EndIf
	Next
	Return $l_s
EndFunc

; Vanquish a spine map crossed in transit (e.g. Stingray before Tears, or Tears before Stingray).
Func BotEngine_VanquishTOASpineTransit($a_s_TargetTitle)
	Local $l_i_Map = Map_GetMapID()
	Local $l_s_TransitTitle = ""
	If $a_s_TargetTitle = "TearsoftheFallen" And $l_i_Map = $StingrayStrand_Map Then
		$l_s_TransitTitle = "StingrayStrand"
	ElseIf $a_s_TargetTitle = "StingrayStrand" And $l_i_Map = $TearsoftheFallen_Map Then
		$l_s_TransitTitle = "TearsoftheFallen"
	EndIf
	If $l_s_TransitTitle = "" Then Return True

	Local $l_i_TransitMap = MapCatalog_GetMapID($l_s_TransitTitle)
	If $l_i_TransitMap > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_TransitMap) Then Return True

	VanquishCheck_OnMapLoaded(False)
	If VanquishCheck_IsAreaVanquished() Then Return True

	Out("TOA spine transit: vanquishing " & $l_s_TransitTitle & " before continuing to " & $a_s_TargetTitle)
	BotEngine_OnBeforeMapFarm($l_s_TransitTitle)
	$g_s_CoverageMapTitle = $l_s_TransitTitle
	RunCoverageSweep()
	$g_s_CoverageMapTitle = ""
	Return True
EndFunc

Func BotEngine_VanquishSouthernShiverpeaksSpineTransit($a_s_TargetTitle)
	Local $l_s_TransitTitle = MapTravel_GetSouthernShiverpeaksSpineTitleForMap(Map_GetMapID())
	If $l_s_TransitTitle = "" Then Return True

	Local $l_i_CurrentStage = MapTravel_GetSouthernShiverpeaksSpineStage($l_s_TransitTitle)
	Local $l_i_TargetStage = MapTravel_GetSouthernShiverpeaksSpineStage($a_s_TargetTitle)
	If $l_i_CurrentStage < 0 Or $l_i_TargetStage < 0 Then Return True
	If $l_i_CurrentStage >= $l_i_TargetStage Then Return True

	Local $l_i_TransitMap = MapCatalog_GetMapID($l_s_TransitTitle)
	If $l_i_TransitMap > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_TransitMap) Then Return True

	VanquishCheck_OnMapLoaded(False)
	If VanquishCheck_IsAreaVanquished() Then Return True

	Out("Southern Shiverpeaks spine transit: vanquishing " & $l_s_TransitTitle & " before continuing to " & $a_s_TargetTitle)
	BotEngine_OnBeforeMapFarm($l_s_TransitTitle)
	$g_s_CoverageMapTitle = $l_s_TransitTitle
	RunCoverageSweep()
	$g_s_CoverageMapTitle = ""
	Return True
EndFunc

Func BotEngine_VanquishIceCavesSpineTransit($a_s_TargetTitle)
	Local $l_s_TransitTitle = MapTravel_GetIceCavesSpineTitleForMap(Map_GetMapID())
	If $l_s_TransitTitle = "" Then Return True

	Local $l_i_CurrentStage = MapTravel_GetIceCavesSpineStage($l_s_TransitTitle)
	Local $l_i_TargetStage = MapTravel_GetIceCavesSpineStage($a_s_TargetTitle)
	If $l_i_CurrentStage < 0 Or $l_i_TargetStage < 0 Then Return True
	If $l_i_CurrentStage >= $l_i_TargetStage Then Return True

	Local $l_i_TransitMap = MapCatalog_GetMapID($l_s_TransitTitle)
	If $l_i_TransitMap > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_TransitMap) Then Return True

	VanquishCheck_OnMapLoaded(False)
	If VanquishCheck_IsAreaVanquished() Then Return True

	Out("Ice Caves spine transit: vanquishing " & $l_s_TransitTitle & " before continuing to " & $a_s_TargetTitle)
	BotEngine_OnBeforeMapFarm($l_s_TransitTitle)
	$g_s_CoverageMapTitle = $l_s_TransitTitle
	RunCoverageSweep()
	$g_s_CoverageMapTitle = ""
	Return True
EndFunc

Func BotEngine_RunCoverageForTitle($a_s_Title)
	BotEngine_OnBeforeMapFarm($a_s_Title)
	$g_s_CoverageMapTitle = $a_s_Title
	RunCoverageSweep()
	$g_s_CoverageMapTitle = ""
EndFunc

; Enter TOA once, vanquish each selected spine map in order, portal between them.
Func RunTOAKrytaSpineChain($a_s_SpinePipe, $a_b_KeepRunning = False)
	Local $l_a = StringSplit($a_s_SpinePipe, "|")
	If Not IsArray($l_a) Or $l_a[0] < 1 Then Return False

	Out("=== TOA Kryta spine: " & $a_s_SpinePipe & " ===")
	Local $i, $l_b_First = True
	For $i = 1 To $l_a[0]
		If $g_b_StopRequested Or Not $g_b_BotRunning Then Return False
		Local $l_s_Title = StringStripWS($l_a[$i], 3)
		If $l_s_Title = "" Then ContinueLoop
		If $g_b_CaravanSkipVanquished Then
			Local $l_i_Map = MapCatalog_GetMapID($l_s_Title)
			If $l_i_Map > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_Map) Then
				Out("Skip " & $l_s_Title & " — already completed.")
				ContinueLoop
			EndIf
		EndIf

		If $l_b_First Then
			If Not MapTravel_EnterTitle($l_s_Title) Then
				Out("Could not enter " & $l_s_Title)
				If Not $a_b_KeepRunning Then
					$g_b_BotRunning = False
					BotEngine_SetIdleUiState()
				EndIf
				Return False
			EndIf
			$l_b_First = False
		Else
			If Not MapTravel_EnterTitle($l_s_Title, 8, True) Then
				Out("Could not reach " & $l_s_Title & " from map " & Map_GetMapID())
				If Not $a_b_KeepRunning Then
					$g_b_BotRunning = False
					BotEngine_SetIdleUiState()
				EndIf
				Return False
			EndIf
		EndIf
		BotEngine_RunCoverageForTitle($l_s_Title)
	Next
	Return True
EndFunc

; Talus from Ice Caves of Sorrow (ends at Camp Rankor); after that vanquish, TravelTo Camp Rankor and portal Snake -> Dreadnought -> Lornar.
Func RunSouthernShiverpeaksSpineChain($a_s_SpinePipe, $a_b_KeepRunning = False)
	Local $l_a = StringSplit($a_s_SpinePipe, "|")
	If Not IsArray($l_a) Or $l_a[0] < 1 Then Return False

	Out("=== Southern Shiverpeaks spine: " & $a_s_SpinePipe & " ===")
	Local $i, $l_b_First = True
	For $i = 1 To $l_a[0]
		If $g_b_StopRequested Or Not $g_b_BotRunning Then Return False
		Local $l_s_Title = StringStripWS($l_a[$i], 3)
		If $l_s_Title = "" Then ContinueLoop
		If $g_b_CaravanSkipVanquished Then
			Local $l_i_Map = MapCatalog_GetMapID($l_s_Title)
			If $l_i_Map > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_Map) Then
				Out("Skip " & $l_s_Title & " — already completed.")
				ContinueLoop
			EndIf
		EndIf

		If $l_b_First Or MapTravel_ShouldTravelToCampRankor($l_s_Title) Then
			If Not MapTravel_EnterTitle($l_s_Title) Then
				Out("Could not enter " & $l_s_Title)
				If Not $a_b_KeepRunning Then
					$g_b_BotRunning = False
					BotEngine_SetIdleUiState()
				EndIf
				Return False
			EndIf
			$l_b_First = False
		Else
			If Not MapTravel_EnterTitle($l_s_Title, 8, True) Then
				Out("Could not reach " & $l_s_Title & " from map " & Map_GetMapID())
				If Not $a_b_KeepRunning Then
					$g_b_BotRunning = False
					BotEngine_SetIdleUiState()
				EndIf
				Return False
			EndIf
		EndIf
		BotEngine_RunCoverageForTitle($l_s_Title)
	Next
	Return True
EndFunc

; IceDome / Frozen Forest / Ice Floe each TravelTo their own outpost, then vanquish.
; After Ice Dome, Frozen Forest portals from the Ice Dome door instead of Iron Mines.
Func RunIceCavesSpineChain($a_s_SpinePipe, $a_b_KeepRunning = False)
	Local $l_a = StringSplit($a_s_SpinePipe, "|")
	If Not IsArray($l_a) Or $l_a[0] < 1 Then Return False

	Out("=== Southern ice maps: " & $a_s_SpinePipe & " ===")

	Local $i
	For $i = 1 To $l_a[0]
		If $g_b_StopRequested Or Not $g_b_BotRunning Then Return False
		Local $l_s_Title = StringStripWS($l_a[$i], 3)
		If $l_s_Title = "" Then ContinueLoop
		If $g_b_CaravanSkipVanquished Then
			Local $l_i_Map = MapCatalog_GetMapID($l_s_Title)
			If $l_i_Map > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_Map) Then
				Out("Skip " & $l_s_Title & " — already completed.")
				ContinueLoop
			EndIf
		EndIf

		Local $l_b_PortalFromIceDome = MapTravel_CanContinueIceCavesSpineFromCurrent($l_s_Title)
		If Not MapTravel_EnterTitle($l_s_Title, 8, $l_b_PortalFromIceDome) Then
			Out("Could not enter " & $l_s_Title)
			If Not $a_b_KeepRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return False
		EndIf
		BotEngine_RunCoverageForTitle($l_s_Title)
	Next
	Return True
EndFunc

Func RunSingleMap($a_s_Title, $a_b_KeepRunning = False)
	Out("=== Single map: " & $a_s_Title & " ===")
	BotEngine_OnBeforeMapFarm($a_s_Title)
	If Not MapTravel_EnterTitle($a_s_Title) Then
		Out("Could not enter " & $a_s_Title)
		If Not $a_b_KeepRunning Then
			$g_b_BotRunning = False
			BotEngine_SetIdleUiState()
		EndIf
		Return False
	EndIf
	$g_s_CoverageMapTitle = $a_s_Title
	RunCoverageSweep()
	$g_s_CoverageMapTitle = ""
	Return True
EndFunc

Func RunRegionMapList()
	Local $l_s_SelectedMaps = CaravanGui_GetSelectedTitles()
	If $l_s_SelectedMaps = "" Then
		Out("No maps selected. Click All or Ctrl+click maps in the list.")
		$g_b_BotRunning = False
		BotEngine_SetIdleUiState()
		Return
	EndIf
	If $l_s_SelectedMaps = "*" Then $l_s_SelectedMaps = MapCatalog_GetRegionTitles($g_s_SelectedTarget)
	Local $l_a_Parts = StringSplit($l_s_SelectedMaps, "|")
	If Not IsArray($l_a_Parts) Or $l_a_Parts[0] < 1 Then
		Out("No maps selected. Click All or Ctrl+click maps in the list.")
		$g_b_BotRunning = False
		BotEngine_SetIdleUiState()
		Return
	EndIf

	Out("=== " & $g_s_SelectedTarget & " (" & $l_a_Parts[0] & " maps) ===")

	Local $l_s_SpinePipe = BotEngine_GetTOAKrytaSpinePipe($l_s_SelectedMaps)
	If BotEngine_CountPipeTitles($l_s_SpinePipe) >= 2 Then
		RunTOAKrytaSpineChain($l_s_SpinePipe, True)
		$l_s_SelectedMaps = BotEngine_RemovePipeTitles($l_s_SelectedMaps, $l_s_SpinePipe)
		If $l_s_SelectedMaps = "" Then
			If $g_b_BotRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return
		EndIf
		$l_a_Parts = StringSplit($l_s_SelectedMaps, "|")
		If Not IsArray($l_a_Parts) Or $l_a_Parts[0] < 1 Then
			If $g_b_BotRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return
		EndIf
	EndIf

	$l_s_SpinePipe = BotEngine_GetSouthernShiverpeaksSpinePipe($l_s_SelectedMaps)
	If BotEngine_CountPipeTitles($l_s_SpinePipe) >= 2 Then
		RunSouthernShiverpeaksSpineChain($l_s_SpinePipe, True)
		$l_s_SelectedMaps = BotEngine_RemovePipeTitles($l_s_SelectedMaps, $l_s_SpinePipe)
		If $l_s_SelectedMaps = "" Then
			If $g_b_BotRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return
		EndIf
		$l_a_Parts = StringSplit($l_s_SelectedMaps, "|")
		If Not IsArray($l_a_Parts) Or $l_a_Parts[0] < 1 Then
			If $g_b_BotRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return
		EndIf
	EndIf

	$l_s_SpinePipe = BotEngine_GetIceCavesSpinePipe($l_s_SelectedMaps)
	If BotEngine_CountPipeTitles($l_s_SpinePipe) >= 2 Then
		RunIceCavesSpineChain($l_s_SpinePipe, True)
		$l_s_SelectedMaps = BotEngine_RemovePipeTitles($l_s_SelectedMaps, $l_s_SpinePipe)
		If $l_s_SelectedMaps = "" Then
			If $g_b_BotRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return
		EndIf
		$l_a_Parts = StringSplit($l_s_SelectedMaps, "|")
		If Not IsArray($l_a_Parts) Or $l_a_Parts[0] < 1 Then
			If $g_b_BotRunning Then
				$g_b_BotRunning = False
				BotEngine_SetIdleUiState()
			EndIf
			Return
		EndIf
	EndIf

	Local $i, $l_i_Ran = 0
	For $i = 1 To $l_a_Parts[0]
		If $g_b_StopRequested Or Not $g_b_BotRunning Then ExitLoop
		Local $l_s_Title = StringStripWS($l_a_Parts[$i], 3)
		If $l_s_Title = "" Then ContinueLoop
		If $g_b_CaravanSkipVanquished Then
			Local $l_i_Map = MapCatalog_GetMapID($l_s_Title)
			If $l_i_Map > 0 And VanquishCheck_IsMapHistoricallyVanquished($l_i_Map) Then
				Out("Skip " & $l_s_Title & " — already completed.")
				ContinueLoop
			EndIf
		EndIf
		$l_i_Ran += 1
		RunSingleMap($l_s_Title, True)
	Next

	If $l_i_Ran < 1 And Not $g_b_StopRequested Then
		Out("Nothing to vanquish — selected maps are already completed.")
	EndIf
	If $g_b_BotRunning Then
		$g_b_BotRunning = False
		BotEngine_SetIdleUiState()
	EndIf
EndFunc

Func RunCaravanSequence()
	CaravanPlan_SetKind(MapCatalog_GetSequenceKind($g_s_SelectedTarget))
	Combat_LoadConfig()
	If $g_b_CombatLoggingEnabled Then CombatLogger_LoadConfig()
	SmartCast_LoadConfig()
	LootPickup_LoadConfig()

	Local $l_s_SelectedMaps = CaravanGui_GetSelectedTitles()
	If $l_s_SelectedMaps = "" Then
		Out("No caravan maps selected. Click All or Ctrl+click maps in the list.")
		$g_b_BotRunning = False
		BotEngine_SetIdleUiState()
		Return
	EndIf
	CaravanPlan_SetFarmFromTitles($l_s_SelectedMaps)
	CaravanPlan_DropVanquishedFarms()

	Local $l_i_VisitCount = CaravanPlan_VisitCount()
	If $l_i_VisitCount < 1 Then
		Out("Nothing to vanquish — selected maps are already completed.")
		If $g_b_BotRunning And Not $g_b_StopRequested Then
			Local $l_i_Return = CaravanPlan_ReturnOutpost()
			If $l_i_Return > 0 Then MapTravel_TravelToOutpost($l_i_Return)
		EndIf
		$g_b_BotRunning = False
		BotEngine_SetIdleUiState()
		Return
	EndIf

	Local $l_i_EntryOutpost = CaravanPlan_EntryOutpost()
	Local $l_s_Sequence = CaravanPlan_SequenceLabel()
	$g_b_CaravanPreferPortalRoute = True
	Out("=== " & $l_s_Sequence & " (" & CaravanPlan_FarmCount() & " vanquish / " & _
		$l_i_VisitCount & " maps on path) ===")
	Out("Vanquish: " & CaravanPlan_FarmTitlesPipe())
	Out("Entry outpost: " & $l_i_EntryOutpost & ", Hard Mode=" & $g_b_HardMode)
	Out("Unselected maps: portal transit only. On completion: travel to " & CaravanPlan_ReturnLabel() & ".")
	Out("F8 pause: stop bot walk, F8 resume.")

	Local $l_i_StartK = 0
	Local $l_b_OnPath = False
	Local $l_b_Complete = True

	If Map_GetInstanceInfo("IsExplorable") Then
		Local $l_i_CurrentStage = CaravanPlan_StageForCurrentMap()
		If $l_i_CurrentStage >= 0 And CaravanPlan_IsEntryMap(Map_GetMapID(), $l_i_CurrentStage) Then
			Local $l_i_K = -1
			Local $j
			For $j = 0 To $l_i_VisitCount - 1
				If CaravanPlan_VisitStage($j) >= $l_i_CurrentStage Then
					$l_i_K = $j
					ExitLoop
				EndIf
			Next
			If $l_i_K < 0 Then
				Out("Already past selected maps on the spine.")
				$l_i_StartK = $l_i_VisitCount
				$l_b_OnPath = True
			Else
				$l_b_OnPath = True
				SmartCast_EnsureReady(True)
				VanquishCheck_WaitUntilReady()
				Local $l_i_TargetStage = CaravanPlan_VisitStage($l_i_K)
				If $l_i_TargetStage = $l_i_CurrentStage Then
					Out("Resume on caravan path: " & CaravanPlan_Title($l_i_CurrentStage) & _
						" (" & ($l_i_K + 1) & "/" & $l_i_VisitCount & ")")
					If Not _CaravanArriveVisit($l_i_K) Then
						$g_b_BotRunning = False
						BotEngine_SetIdleUiState()
						Return
					EndIf
					$l_i_StartK = $l_i_K
				Else
					Local $l_s_Here = CaravanPlan_Title($l_i_CurrentStage)
					Local $l_s_Next = CaravanPlan_Title($l_i_TargetStage)
					Out("Resume: leave " & $l_s_Here & " toward " & $l_s_Next)
					If Not CaravanPlan_AdvanceToNext($l_s_Here, $l_s_Next) Then
						Out("Could not reach " & $l_s_Next & " — stopping caravan.")
						$g_b_BotRunning = False
						BotEngine_SetIdleUiState()
						Return
					EndIf
					If Not _CaravanArriveVisit($l_i_K) Then
						$g_b_BotRunning = False
						BotEngine_SetIdleUiState()
						Return
					EndIf
					$l_i_StartK = $l_i_K
				EndIf
			EndIf
		EndIf
	EndIf

	If Not $l_b_OnPath Then
		If $l_i_EntryOutpost < 1 Then
			Out("No entry outpost for " & $l_s_Sequence & ".")
			$g_b_BotRunning = False
			BotEngine_SetIdleUiState()
			Return
		EndIf
		If Not MapTravel_TravelToOutpost($l_i_EntryOutpost) Then
			Out("Failed to travel to entry outpost (" & $l_i_EntryOutpost & ").")
			$g_b_BotRunning = False
			BotEngine_SetIdleUiState()
			Return
		EndIf
		MapTravel_EnsureHardMode()

		Local $l_s_First = CaravanPlan_Title(CaravanPlan_VisitStage(0))
		BotEngine_OnBeforeMapFarm($l_s_First)
		If Not MapTravel_EnterTitle($l_s_First, 8, True) Then
			Out("Failed to enter " & $l_s_First & " from outpost " & $l_i_EntryOutpost)
			$g_b_BotRunning = False
			BotEngine_SetIdleUiState()
			Return
		EndIf
		SmartCast_EnsureReady(True)
		Out("On " & $l_s_First & " (MapID=" & Map_GetMapID() & "). Following selected caravan path...")
		If Not _CaravanArriveVisit(0) Then
			$g_b_BotRunning = False
			BotEngine_SetIdleUiState()
			Return
		EndIf
		$l_i_StartK = 0
	EndIf

	Local $k
	For $k = $l_i_StartK To $l_i_VisitCount - 2
		BotEngine_WaitIfPaused()
		If Not $g_b_BotRunning Or $g_b_StopRequested Then
			$l_b_Complete = False
			ExitLoop
		EndIf

		Local $l_i_HereStage = CaravanPlan_VisitStage($k)
		Local $l_i_NextStage = CaravanPlan_VisitStage($k + 1)
		Local $l_s_Here = CaravanPlan_Title($l_i_HereStage)
		Local $l_s_Next = CaravanPlan_Title($l_i_NextStage)
		Local $l_i_NextID = CaravanPlan_MapID($l_i_NextStage)

		Out("")
		Out("=== Path " & ($k + 1) & "/" & $l_i_VisitCount & _
			": portal " & $l_s_Here & " -> " & $l_s_Next & " (" & $l_i_NextID & ") ===")
		UpdateStatusLabel("portal " & $l_s_Here & "->" & $l_s_Next)

		If Not CaravanPlan_IsEntryMap(Map_GetMapID(), $l_i_HereStage) And Map_GetMapID() <> $l_i_NextID Then
			Out("Not on expected map (have " & Map_GetMapID() & "). Re-entering " & $l_s_Here & "...")
			If Not MapTravel_EnterTitle($l_s_Here, 8, True) Then
				Out("Re-enter failed; trying direct advance to " & $l_s_Next)
			EndIf
			SmartCast_EnsureReady(True)
		EndIf

		If Not CaravanPlan_AdvanceToNext($l_s_Here, $l_s_Next) Then
			Out("Could not reach " & $l_s_Next & " — stopping caravan.")
			$l_b_Complete = False
			ExitLoop
		EndIf

		If Not _CaravanArriveVisit($k + 1) Then
			$l_b_Complete = False
			ExitLoop
		EndIf
	Next

	If $l_b_Complete And $g_b_BotRunning And Not $g_b_StopRequested Then
		Local $l_i_Return = CaravanPlan_ReturnOutpost()
		Out($l_s_Sequence & " complete — returning to " & CaravanPlan_ReturnLabel() & ".")
		If $l_i_Return > 0 Then MapTravel_TravelToOutpost($l_i_Return)
	EndIf

	If $g_b_CombatLoggingEnabled Then CombatLogger_FlushIfInCombat()
	Out("Caravan sequence finished." & BotEngine_EventCountSuffix())
	If $g_b_CombatLoggingEnabled And CombatLogger_GetLogFile() <> "" Then Out("Log file: " & CombatLogger_GetLogFile())
	UpdateStatusLabel("caravan done" & BotEngine_EventCountSuffix())
	$g_b_BotRunning = False
	BotEngine_SetIdleUiState()
EndFunc

Func BotEngine_EventCountSuffix()
	If Not $g_b_CombatLoggingEnabled Then Return ""
	Return " Events=" & CombatLogger_GetCount()
EndFunc

Func _CaravanArriveVisit($a_i_VisitIdx)
	Local $l_i_Stage = CaravanPlan_VisitStage($a_i_VisitIdx)
	Local $l_s_Title = CaravanPlan_Title($l_i_Stage)
	$g_b_CaravanPreferPortalRoute = True
	SmartCast_Invalidate()
	SmartCast_EnsureReady(True)
	VanquishCheck_WaitUntilReady()
	If CaravanPlan_ShouldFarm($l_i_Stage) Then Return _CaravanProcessMapArrival($l_s_Title)
	Out("Transit " & $l_s_Title & " (not selected for vanquish).")
	Return True
EndFunc

Func _CaravanProcessMapArrival($a_s_Title)
	VanquishCheck_WaitUntilReady(False)
	If VanquishCheck_IsCoverageVanquished() Then
		$g_b_CaravanPreferPortalRoute = True
		Out("Skip sweep on " & $a_s_Title & " — already vanquished; using caravan portal route to leave.")
		Return True
	EndIf
	BotEngine_OnBeforeMapFarm($a_s_Title)
	If Not _CaravanMaybeStartLogging($a_s_Title) Then Return False
	If Not _CaravanSweepCurrentMap($a_s_Title) Then
		Out("Lawnmower failed/stopped on " & $a_s_Title & " — stopping caravan.")
		Return False
	EndIf
	If VanquishCheck_IsCoverageVanquished() Then
		$g_b_CaravanPreferPortalRoute = True
		Out($a_s_Title & " vanquished during sweep — leave via caravan portal route.")
	Else
		$g_b_CaravanPreferPortalRoute = False
		Out($a_s_Title & " still open — leave from farm position (existing portal hop).")
	EndIf
	Return True
EndFunc

Func _CaravanSweepCurrentMap($a_s_Title)
	If Not $g_b_BotRunning Or $g_b_StopRequested Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then
		Out("Skip lawnmower — not explorable on " & $a_s_Title)
		Return False
	EndIf

	VanquishCheck_WaitUntilReady(False)
	If VanquishCheck_IsCoverageVanquished() Then
		Out("Skip lawnmower on " & $a_s_Title & " — HM vanquish complete.")
		Return True
	EndIf

	Out("")
	Out("=== Map sweep: " & $a_s_Title & " (MapID=" & Map_GetMapID() & ") ===")
	UpdateStatusLabel("sweep " & $a_s_Title)
	SmartCast_EnsureReady(True)
	Coverage_ClearProgress()
	$g_b_ResumeRequested = False
	$g_s_CoverageMapTitle = $a_s_Title

	RunCoverageSweep(True, False)

	$g_s_CoverageMapTitle = ""

	If $g_b_StopRequested Or Not $g_b_BotRunning Then Return False
	If Not Coverage_IsComplete() Then
		Out("Map sweep incomplete on " & $a_s_Title)
		Return False
	EndIf
	Out("Map sweep complete on " & $a_s_Title & "." & BotEngine_EventCountSuffix())
	Return True
EndFunc

Func _CaravanMaybeStartLogging($a_s_Title)
	If Not $g_b_CombatLoggingEnabled Then Return True
	If CombatLogger_IsSessionActive() Then Return True
	Out("=== Combat logging ENABLED at " & $a_s_Title & " (MapID=" & Map_GetMapID() & ") ===")
	If Not CombatLogger_StartSession() Then
		Out("Failed to start combat log session.")
		Return False
	EndIf
	Return True
EndFunc

Func RunCoverageSweep($a_b_ReuseLogSession = False, $a_b_AllowResume = True)
	If $g_b_SweepActive Then Return
	$g_b_SweepActive = True

	Combat_LoadConfig()
	If $g_b_CombatLoggingEnabled Then CombatLogger_LoadConfig()
	SmartCast_LoadConfig()
	LootPickup_LoadConfig()

	If $g_b_CombatLoggingEnabled Then
		If $a_b_ReuseLogSession And CombatLogger_IsSessionActive() Then
			; Keep current log file across caravan maps
		Else
			If Not CombatLogger_StartSession() Then
				Out("Failed to start combat log session.")
				$g_b_SweepActive = False
				If Not MapCatalog_IsMapListSelection($g_s_SelectedTarget) Then
					StopBot()
				EndIf
				Return
			EndIf
		EndIf
	EndIf

	SmartCast_EnsureReady(True)
	VanquishCheck_WaitUntilReady(False)
	If VanquishCheck_IsCoverageVanquished() Then
		Out("Skip coverage sweep — area already vanquished; leave via portal route.")
		$g_i_CoverageIndex = $g_i_CoverageCount
		$g_b_SweepActive = False
		If Not MapCatalog_IsMapListSelection($g_s_SelectedTarget) Then
			$g_b_BotRunning = False
			BotEngine_SetIdleUiState()
		EndIf
		Return
	EndIf

	Local $l_b_HaveRoute = False
	If $a_b_AllowResume And $g_b_ResumeRequested Then
		$l_b_HaveRoute = Coverage_TryResume(True)
	EndIf

	If Not $l_b_HaveRoute Then
		Coverage_ClearProgress()
		If Not Coverage_BuildRoute(True) Then
			Out("No reachable coverage points. Check map mesh / tighten or widen bounds.")
			$g_b_SweepActive = False
			If Not MapCatalog_IsMapListSelection($g_s_SelectedTarget) Then
				StopBot()
			EndIf
			Return
		EndIf
	EndIf

	Out("Starting coverage sweep: " & $g_i_CoverageCount & " waypoints, aggro=" & $g_f_AggroRange & _
		" | MapID=" & Map_GetMapID() & " | SmartCast=" & $g_b_SmartCastEnabled & _
		" | Loot=" & Int($g_b_LootPickupEnabled) & Coverage_PassLogSuffix())

	Local Const $GC_I_WAYPOINT_TIMEOUT_MS = 120000
	Local Const $GC_I_WAYPOINT_MAX_RETRIES = 3
	Local $l_b_VanquishedAbort = False
	Local $l_b_MoveInterrupted = False
	Local $l_b_ReenterForRepeat = False
	Local $l_i_SweepMap = Map_GetMapID()

	Coverage_ConfigurePathfinder(False)
	PathRoute_LoadConfig()
	PathRoute_BeginSession($GC_S_PATHROUTE_PROFILE_COVERAGE, False)

	While $g_b_BotRunning And Not $g_b_StopRequested
		Local $l_i_WaypointRetries = 0
		If $g_i_CoverageRepeatPass > 0 Then
			Out("Vanquish leftover check " & $g_i_CoverageRepeatPass & "/" & $GC_I_VANQUISH_ROUTE_REPEATS & _
				" — walking all " & $g_i_CoverageCount & " waypoints again.")
		EndIf

		While $g_b_BotRunning And Not $g_b_StopRequested And Not Coverage_IsComplete()
			BotEngine_WaitIfPaused()
			If $g_b_StopRequested Then ExitLoop
			If VanquishCheck_IsCoverageVanquished() And $g_i_CoverageRepeatPass > 0 Then
				Out("Coverage abort — leftover pass found area vanquished; switching to portal route.")
				$g_i_CoverageIndex = $g_i_CoverageCount
				$l_b_VanquishedAbort = True
				ExitLoop
			EndIf
			Coverage_TrySkipPassedWaypoints($GC_F_COVERAGE_WAYPOINT_REACHED)

			; Finish the current fight before starting the next coordinate set.
			If Combat_ShouldHoldMovement($g_f_AggroRange, $g_f_FightRangeOut) Then
				Out("Coverage chain: waiting for combat to end before next set.")
				If Not Combat_WaitUntilClear($g_f_AggroRange, $g_f_FightRangeOut, $g_i_FinisherMode, "BotEngine_Tick") Then
					$l_b_MoveInterrupted = True
					ExitLoop
				EndIf
				ContinueLoop
			EndIf

			Local $l_f_X = 0, $l_f_Y = 0
			If Not Coverage_GetCurrentPoint($l_f_X, $l_f_Y) Then ExitLoop

			Local $l_f_Reach = Coverage_GetReachedDistance()
			Local $l_f_DistBefore = Agent_GetDistanceToXY($l_f_X, $l_f_Y)
			If $l_f_DistBefore <= $l_f_Reach Then
				Out("Skip near waypoint " & ($g_i_CoverageIndex + 1) & " dist=" & Round($l_f_DistBefore))
				Coverage_Advance()
				Coverage_MarkWaypointReached()
				ContinueLoop
			EndIf
			If Coverage_IsVanquishExitIndex($g_i_CoverageIndex) Then
				Out("Skip vanquish exit waypoint " & ($g_i_CoverageIndex + 1) & _
					" @ (" & Round($l_f_X) & "," & Round($l_f_Y) & ") — stay on map to repeat path.")
				Coverage_Advance()
				Coverage_MarkWaypointReached()
				ContinueLoop
			EndIf

			Local $l_i_ChainStart = $g_i_CoverageIndex
			Local $l_i_ChainEnd = Coverage_FindChainEndIndex()
			If Not Coverage_GetPointAt($l_f_X, $l_f_Y, $l_i_ChainEnd) Then ExitLoop
			$l_f_DistBefore = Agent_GetDistanceToXY($l_f_X, $l_f_Y)

			Local $l_s_Chain = String($l_i_ChainStart + 1)
			If $l_i_ChainEnd > $l_i_ChainStart Then $l_s_Chain &= "-" & ($l_i_ChainEnd + 1)
			UpdateStatusLabel("moving " & $l_s_Chain & "/" & $g_i_CoverageCount & _
				Coverage_PassLogSuffix() & " -> (" & Round($l_f_X) & "," & Round($l_f_Y) & ")" & _
				BotEngine_EventCountSuffix())
			Out("Coverage chain " & $l_s_Chain & "/" & $g_i_CoverageCount & Coverage_PassLogSuffix() & _
				" -> (" & Round($l_f_X) & "," & Round($l_f_Y) & ") dist=" & Round($l_f_DistBefore))

			SmartCast_EnsureReady(False)
			Local $hMove = TimerInit()
			Local $l_i_MapBeforeMove = Map_GetMapID()
			Local $l_b_Ok = PathRoute_MoveTo($l_f_X, $l_f_Y, $GC_S_PATHROUTE_PROFILE_COVERAGE, $g_f_AggroRange, _
				$g_f_FightRangeOut, $g_i_FinisherMode, "BotEngine_Tick")

			If Not Combat_WaitUntilClear($g_f_AggroRange, $g_f_FightRangeOut, $g_i_FinisherMode, "BotEngine_Tick") Then
				$l_b_MoveInterrupted = True
				ExitLoop
			EndIf

			Local $l_f_DistAfter = Agent_GetDistanceToXY($l_f_X, $l_f_Y)

			If Not $l_b_Ok Then
				If $g_b_StopRequested Then
					Out("Pathfinder_MoveTo stopped by user.")
					$l_b_MoveInterrupted = True
					ExitLoop
				EndIf
				If Party_GetPartyContextInfo("IsDefeated") Then
					Out("Pathfinder_MoveTo interrupted (party defeated). Stopping map sweep.")
					$l_b_MoveInterrupted = True
					ExitLoop
				EndIf
				If Map_GetMapID() <> $l_i_MapBeforeMove Then
					If $g_b_CoverageIsVanquishRoute And $l_i_ChainEnd >= $g_i_CoverageCount - 3 Then
						Out("Vanquish route end crossed a portal — finishing this pass to repeat the path.")
						$g_i_CoverageIndex = $g_i_CoverageCount
						Coverage_SaveProgress()
						$l_b_ReenterForRepeat = True
						ExitLoop
					EndIf
					Out("Pathfinder_MoveTo interrupted (map change). Stopping map sweep.")
					$l_b_MoveInterrupted = True
					ExitLoop
				EndIf
				Out("Pathfinder_MoveTo failed dist=" & Round($l_f_DistAfter) & " @ (" & _
					Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & _
					") — will retry or skip.")
				If IsFunc(Execute("CombatLogger_LogStuck")) Then CombatLogger_LogStuck("move_failed")
			EndIf

			Local $l_b_InCombat = Combat_ShouldHoldMovement($g_f_AggroRange, $g_f_FightRangeOut)

			If $l_f_DistAfter <= Coverage_GetReachedDistance($l_i_ChainEnd) And Not $l_b_InCombat Then
				Out("Coverage chain " & $l_s_Chain & " reached (dist=" & Round($l_f_DistAfter) & ").")
				Coverage_AdvanceThrough($l_i_ChainEnd)
				$l_i_WaypointRetries = 0
			Else
				Coverage_TrySkipPassedWaypoints($GC_F_COVERAGE_WAYPOINT_REACHED)
				If TimerDiff($hMove) > $GC_I_WAYPOINT_TIMEOUT_MS Then
					Out("Skip chain " & $l_s_Chain & " — timeout (dist=" & Round($l_f_DistAfter) & ") @ (" & _
						Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & ").")
					If IsFunc(Execute("CombatLogger_LogStuck")) Then CombatLogger_LogStuck("timeout")
					Coverage_AdvanceThrough($l_i_ChainEnd)
					$l_i_WaypointRetries = 0
				ElseIf $l_i_WaypointRetries >= $GC_I_WAYPOINT_MAX_RETRIES Then
					Out("Skip chain " & $l_s_Chain & " — max retries (dist=" & Round($l_f_DistAfter) & ") @ (" & _
						Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & ").")
					If IsFunc(Execute("CombatLogger_LogStuck")) Then CombatLogger_LogStuck("max_retries")
					Coverage_AdvanceThrough($l_i_ChainEnd)
					$l_i_WaypointRetries = 0
				Else
					$l_i_WaypointRetries += 1
					Out("Retry chain " & $l_s_Chain & " dist=" & Round($l_f_DistAfter) & " @ (" & _
						Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & ") (" & _
						$l_i_WaypointRetries & "/" & $GC_I_WAYPOINT_MAX_RETRIES & ")")
					PathRoute_UnstuckNudge()
				EndIf
			EndIf
		WEnd

		If $l_b_VanquishedAbort Or $g_b_StopRequested Or Not $g_b_BotRunning Then ExitLoop
		If $l_b_MoveInterrupted And Not $l_b_ReenterForRepeat Then ExitLoop
		If Not Coverage_IsComplete() And Not $l_b_ReenterForRepeat Then ExitLoop
		If VanquishCheck_IsCoverageVanquished() And $g_i_CoverageRepeatPass > 0 Then
			$l_b_VanquishedAbort = True
			ExitLoop
		EndIf
		If Not Coverage_CanStartVanquishRepeat() Then ExitLoop

		If $l_b_ReenterForRepeat And Map_GetMapID() <> $l_i_SweepMap Then
			If $g_s_CoverageMapTitle = "" Then
				Out("Left the map at route end and have no title to re-enter — stopping sweep.")
				$l_b_MoveInterrupted = True
				ExitLoop
			EndIf
			Out("Re-entering " & $g_s_CoverageMapTitle & " to repeat the vanquish path.")
			If Not MapTravel_EnterTitle($g_s_CoverageMapTitle) Then
				Out("Could not re-enter " & $g_s_CoverageMapTitle & " to repeat path — stopping sweep.")
				$l_b_MoveInterrupted = True
				ExitLoop
			EndIf
			$l_i_SweepMap = Map_GetMapID()
		EndIf
		$l_b_ReenterForRepeat = False

		Out("Vanquish pass complete — walking coordinates again for missed foes (" & _
			($g_i_CoverageRepeatPass + 1) & "/" & $GC_I_VANQUISH_ROUTE_REPEATS & _
			", until vanquish).")
		Coverage_StartVanquishRepeat()
	WEnd

	If Coverage_IsComplete() And Not $g_b_StopRequested Then
		If $g_b_CombatLoggingEnabled Then CombatLogger_FlushIfInCombat()
		Out("Coverage complete on MapID=" & Map_GetMapID() & "." & BotEngine_EventCountSuffix())
		If $g_b_CombatLoggingEnabled Then Out("Log file: " & CombatLogger_GetLogFile())
		If IsFunc(Execute("CombatLogger_GetStuckCount")) And CombatLogger_GetStuckCount() > 0 Then
			Out("Stuck log (" & CombatLogger_GetStuckCount() & "): " & CombatLogger_GetStuckLogFile())
		EndIf
		Coverage_ClearProgress()
		UpdateStatusLabel("complete" & BotEngine_EventCountSuffix())
	Else
		If $g_b_CombatLoggingEnabled Then CombatLogger_FlushIfInCombat()
		Out("Sweep ended at " & $g_i_CoverageIndex & "/" & $g_i_CoverageCount & BotEngine_EventCountSuffix())
		If IsFunc(Execute("CombatLogger_GetStuckCount")) And CombatLogger_GetStuckCount() > 0 Then
			Out("Stuck log (" & CombatLogger_GetStuckCount() & "): " & CombatLogger_GetStuckLogFile())
		EndIf
		Coverage_SaveProgress()
		UpdateStatusLabel("paused " & $g_i_CoverageIndex & "/" & $g_i_CoverageCount & BotEngine_EventCountSuffix())
	EndIf

	PathRoute_EndSession()

	$g_b_SweepActive = False
	If Not MapCatalog_IsMapListSelection($g_s_SelectedTarget) Then
		$g_b_BotRunning = False
		BotEngine_SetIdleUiState()
	EndIf
EndFunc

Func BotEngine_Tick()
	BotEngine_PollGuiHooks()
	BotEngine_WaitIfPaused()
	If $g_b_StopRequested Then Return
	SmartCast_EnsureReady(False)
	If $g_b_CombatLoggingEnabled Then CombatLogger_Tick()
	LootPickup_Tick()
	UpdateStatusLabel("XY=(" & Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & ")" & _
		BotEngine_EventCountSuffix() & " | sc=" & Int($g_b_SmartCastReady))
EndFunc

Func BotEngine_GetObstacles($a_f_Radius = 85, $a_f_DetectionRange = 4000, $a_s_CustomFilter = "")
	If $a_s_CustomFilter = "" Then $a_s_CustomFilter = "BotEngine_IsStaticObstacle"
	Return Agent_GetAgentsAsObstacles($a_f_DetectionRange, $a_f_Radius, $a_s_CustomFilter)
EndFunc

Func BotEngine_IsStaticObstacle($a_p_Agent)
	If $a_p_Agent = 0 Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "ID") = Agent_GetMyID() Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "Allegiance") = 3 Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "HP") <= 0 Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "IsDead") Then Return False
	Return True
EndFunc

Func UpdateStatusLabel($a_s_Text)
	GUICtrlSetData($g_h_StatusLabel, "Status: " & $a_s_Text)
EndFunc

Func GetChecked($a_h_Ctrl)
	Return BitAND(GUICtrlRead($a_h_Ctrl), $GUI_CHECKED) = $GUI_CHECKED
EndFunc

Func Out($a_s_Text)
	Local $l_i_TextLen = StringLen($a_s_Text)
	Local $l_i_ConsoleLen = _GUICtrlEdit_GetTextLen($g_h_EditText)
	If $l_i_TextLen + $l_i_ConsoleLen > 30000 Then
		_GUICtrlRichEdit_SetText($g_h_EditText, "")
	EndIf
	_GUICtrlRichEdit_SetCharColor($g_h_EditText, $COLOR_BLACK)
	_GUICtrlEdit_AppendText($g_h_EditText, @CRLF & $a_s_Text)
	_GUICtrlEdit_Scroll($g_h_EditText, $SB_BOTTOM)
EndFunc
