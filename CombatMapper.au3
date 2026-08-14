#RequireAdmin
#NoTrayIcon

#include "vendor\GwAu3\API\_GwAu3.au3"
#include "lib\maps\LocationsIDS.au3"
#include "lib\maps\Caravan_AscalonPlan.au3"
#include "lib\maps\GoOutRoutes.au3"
#include "lib\MapCatalog.au3"
#include "lib\MapTravel.au3"
#include "lib\Coverage.au3"
#include "lib\CombatLogger.au3"
#include "lib\SmartCast.au3"
#include "lib\VanquishCheck.au3"
#include "lib\LootPickup.au3"

; Pathfinder DLL (also pulled in via Plugins, but path must be set before Initialize)
$DLL_PATH = @ScriptDir & "\vendor\GwAu3\API\Plugins\Pathfinder\GWPathfinder.dll"

Global Const $GC_B_LOAD_LOGGED_CHARS = True
Global Const $GC_S_BOT_TITLE = "GwAu3 Combat Mapper"
Global Const $GC_S_CONFIG = @ScriptDir & "\config.ini"

Opt("GUIOnEventMode", True)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)

#Region Globals
Global $g_i_ProcessID = ""
Global $g_b_BotRunning = False
Global $g_b_BotCoreInitialized = False
Global $g_b_StopRequested = False
Global $g_b_PauseRequested = False
Global $g_b_SweepActive = False
Global $g_b_ResumeRequested = False
Global $g_bAutoStart = False
Global $g_s_MainCharName = ""
Global $g_s_SelectedTarget = "Current Map"
#EndRegion Globals

MapCatalog_Init()

; CLI: -character "Name"
For $i = 1 To $CmdLine[0]
	If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
		$g_s_MainCharName = $CmdLine[$i + 1]
		$g_bAutoStart = True
		ExitLoop
	EndIf
Next

#Region GUI
$g_h_MainGui = GUICreate($GC_S_BOT_TITLE, 680, 560, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
GUISetBkColor(0xEAEAEA, $g_h_MainGui)
GUICtrlCreateGroup("Combat Mapper", 8, 8, 664, 540)

Global $g_h_NameCombo
If $GC_B_LOAD_LOGGED_CHARS Then
	$g_h_NameCombo = GUICtrlCreateCombo($g_s_MainCharName, 24, 28, 160, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
	GUICtrlSetData(-1, Scanner_GetLoggedCharNames())
Else
	$g_h_NameCombo = GUICtrlCreateInput($g_s_MainCharName, 24, 28, 160, 25)
EndIf

$g_h_OnTopCheckbox = GUICtrlCreateCheckbox("On Top", 200, 27, 60, 24)
GUICtrlSetState($g_h_OnTopCheckbox, $GUI_CHECKED)
GUICtrlSetOnEvent($g_h_OnTopCheckbox, "GuiButtonHandler")

$g_h_DebugCheckbox = GUICtrlCreateCheckbox("Debug", 270, 27, 55, 24)
GUICtrlSetState($g_h_DebugCheckbox, $GUI_CHECKED)
GUICtrlSetOnEvent($g_h_DebugCheckbox, "GuiButtonHandler")

$g_h_HardModeCheckbox = GUICtrlCreateCheckbox("Hard Mode", 340, 27, 85, 24)
If Number(IniRead($GC_S_CONFIG, "Travel", "HardMode", "1")) <> 0 Then
	GUICtrlSetState($g_h_HardModeCheckbox, $GUI_CHECKED)
Else
	GUICtrlSetState($g_h_HardModeCheckbox, $GUI_UNCHECKED)
EndIf

$g_h_ResumeCheckbox = GUICtrlCreateCheckbox("Resume coverage", 440, 27, 120, 24)
GUICtrlSetOnEvent($g_h_ResumeCheckbox, "GuiButtonHandler")

GUICtrlCreateLabel("Target:", 24, 60, 45, 18)
$g_h_TargetCombo = GUICtrlCreateCombo("", 70, 56, 320, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
GUICtrlSetData($g_h_TargetCombo, MapCatalog_GetComboString(), IniRead($GC_S_CONFIG, "Travel", "LastTarget", "Current Map"))

$g_h_StartButton = GUICtrlCreateButton("Start", 400, 55, 58, 25)
GUICtrlSetOnEvent($g_h_StartButton, "GuiButtonHandler")

Global $g_h_PauseCheckbox
$g_h_PauseCheckbox = GUICtrlCreateCheckbox("Paused (F8)", 463, 55, 110, 24)
GUICtrlSetOnEvent($g_h_PauseCheckbox, "CombatMapper_OnPauseCheckbox")
GUICtrlSetState($g_h_PauseCheckbox, $GUI_DISABLE)

$g_h_StopButton = GUICtrlCreateButton("Stop", 526, 55, 58, 25)
GUICtrlSetOnEvent($g_h_StopButton, "GuiButtonHandler")
GUICtrlSetState($g_h_StopButton, $GUI_DISABLE)

Global $g_h_LogCoordButton
$g_h_LogCoordButton = GUICtrlCreateButton("Log XY", 589, 55, 58, 25)
GUICtrlSetOnEvent($g_h_LogCoordButton, "GuiButtonHandler")

$g_h_RefreshButton = GUICtrlCreateButton("Refresh", 520, 90, 58, 20)
GUICtrlSetOnEvent($g_h_RefreshButton, "GuiButtonHandler")

GUICtrlCreateLabel("MinX", 24, 92, 30, 18)
$g_h_MinX = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MinX", "0"), 54, 90, 55, 20)
GUICtrlCreateLabel("MaxX", 120, 92, 35, 18)
$g_h_MaxX = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MaxX", "0"), 155, 90, 55, 20)
GUICtrlCreateLabel("MinY", 220, 92, 30, 18)
$g_h_MinY = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MinY", "0"), 250, 90, 55, 20)
GUICtrlCreateLabel("MaxY", 315, 92, 30, 18)
$g_h_MaxY = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MaxY", "0"), 345, 90, 55, 20)
GUICtrlCreateLabel("Step", 410, 92, 30, 18)
$g_h_GridStep = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "GridStep", "2000"), 440, 90, 55, 20)

$g_h_StatusLabel = GUICtrlCreateLabel("Status: idle", 24, 114, 640, 30)

$g_h_EditText = _GUICtrlRichEdit_Create($g_h_MainGui, "", 16, 150, 648, 385, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
_GUICtrlRichEdit_SetBkColor($g_h_EditText, $COLOR_WHITE)

GUICtrlCreateGroup("", -99, -99, 1, 1)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUISetState(@SW_SHOW)
#EndRegion GUI

Out("GwAu3 Map Coverage Combat Logger")
Out("Target: Current Map | single LocationsIDS title | or TOA Ascalon Caravan sequence.")
Out("Caravan: transit to North Kryta, then lawnmower+log each map (SmartCast).")
Out("Tip: smoke-test one map with a tight AABB first.")
Out("Log XY: append player position to logs/map_waypoints_<MapID>.csv (works while paused)." & @CRLF)

Core_AutoStart()

HotKeySet("{F7}", "HotKey_LogCoord")
HotKeySet("{F8}", "HotKey_TogglePause")
HotKeySet("{F9}", "HotKey_Stop")

While 1
	Sleep(100)
WEnd

#Region Bot
Func StartBot()
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
	MapTravel_LoadConfig($GC_S_CONFIG)
	CombatLogger_LoadConfig($GC_S_CONFIG)
	LootPickup_LoadConfig($GC_S_CONFIG)

	_SaveGuiBoundsToConfig()
	If $g_b_HardMode Then
		IniWrite($GC_S_CONFIG, "Travel", "HardMode", "1")
	Else
		IniWrite($GC_S_CONFIG, "Travel", "HardMode", "0")
	EndIf
	IniWrite($GC_S_CONFIG, "Travel", "LastTarget", $g_s_SelectedTarget)

	GUICtrlSetState($g_h_StartButton, $GUI_DISABLE)
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_ENABLE)
	GUICtrlSetState($g_h_StopButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_NameCombo, $GUI_DISABLE)
	GUICtrlSetState($g_h_RefreshButton, $GUI_DISABLE)
	GUICtrlSetState($g_h_TargetCombo, $GUI_DISABLE)
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
	$g_b_PauseRequested = False
	AdLibRegister("CombatMapper_SyncPauseFromGui", 50)

	WinSetTitle($g_h_MainGui, "", Player_GetCharName() & " - " & $GC_S_BOT_TITLE)
	Out("Initialized: " & Player_GetCharName() & " | MapID=" & Map_GetMapID() & _
		" | Target=" & $g_s_SelectedTarget & " | HM=" & $g_b_HardMode)
	Out("Controls: F8 pause/resume | F9 stop | F7 log XY (work during pathfinder)")

	If MapCatalog_IsSequenceSelection($g_s_SelectedTarget) Then
		RunCaravanSequence()
	ElseIf MapCatalog_IsCurrentMapSelection($g_s_SelectedTarget) Then
		If $g_b_HardMode Then MapTravel_EnsureHardMode()
		RunCoverageSweep()
	Else
		RunSingleMap($g_s_SelectedTarget)
	EndIf
EndFunc

Func StopBot()
	$g_b_StopRequested = True
	$g_b_PauseRequested = False
	$g_b_BotRunning = False
	Agent_CancelAction()
	Out("Stop requested — will halt after the current segment when possible.")
	_SetIdleUiState()
	UpdateStatusLabel("stopped")
EndFunc

; Pause checkbox is polled (GUIOnEvent handlers do not run during Pathfinder_MoveTo).
Func CombatMapper_SyncPauseFromGui()
	If Not $g_b_BotRunning Then Return
	Local $bWant = GetChecked($g_h_PauseCheckbox)
	If $bWant = $g_b_PauseRequested Then Return
	$g_b_PauseRequested = $bWant
	If $bWant Then
		Agent_CancelAction()
		Out("Paused — manual movement OK, F7 to log XY, F8 to resume.")
		UpdateStatusLabel("PAUSED | F7 log XY")
	Else
		Out("Resumed.")
		UpdateStatusLabel("running")
	EndIf
EndFunc

Func CombatMapper_OnPauseCheckbox()
	CombatMapper_SyncPauseFromGui()
EndFunc

Func HotKey_TogglePause()
	If Not $g_b_BotRunning Then Return
	If GetChecked($g_h_PauseCheckbox) Then
		GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
	Else
		GUICtrlSetState($g_h_PauseCheckbox, $GUI_CHECKED)
	EndIf
	CombatMapper_SyncPauseFromGui()
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

Func HotKey_LogCoord()
	LogMapCoordButton()
EndFunc

; Block while paused (Pathfinder tick + sweep loops). Stop breaks out.
; Do not call Agent_CancelAction in the wait loop — that blocks manual movement for coordinate logging.
Func CombatMapper_WaitIfPaused()
	CombatMapper_SyncPauseFromGui()
	If Not $g_b_PauseRequested Then Return
	While $g_b_PauseRequested And Not $g_b_StopRequested
		Sleep(100)
		CombatMapper_SyncPauseFromGui()
	WEnd
EndFunc

Func _EnsureGameAttachedForLogging()
	If $g_b_BotCoreInitialized Then Return True
	Local $l_s_MainCharName = GUICtrlRead($g_h_NameCombo)
	If $l_s_MainCharName <> "" Then
		If Core_Initialize($l_s_MainCharName, True) <> 0 Then
			$g_b_BotCoreInitialized = True
			Return True
		EndIf
	EndIf
	Local $l_i_Pid = ProcessExists("gw.exe")
	If $l_i_Pid Then
		If Core_Initialize($l_i_Pid, True) <> 0 Then
			$g_b_BotCoreInitialized = True
			Return True
		EndIf
	EndIf
	Return False
EndFunc

Func LogMapCoordButton()
	If Not _EnsureGameAttachedForLogging() Then
		MsgBox(0, "Log XY", "Attach to Guild Wars first (enter character name or Start once).")
		Return
	EndIf
	CombatLogger_LoadConfig()
	If Not CombatLogger_LogMapCoord("manual") Then
		Out("ERROR: Could not log map coordinate.")
		Return
	EndIf
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	Out("Logged XY map " & Map_GetMapID() & " @ (" & Round($l_f_X, 2) & ", " & Round($l_f_Y, 2) & ")")
	Out("  array: [" & Round($l_f_X, 2) & ", " & Round($l_f_Y, 2) & "], _")
	Out("  file: " & CombatLogger_GetMapCoordLogFile() & " (#" & CombatLogger_GetMapCoordCount() & ")")
	UpdateStatusLabel("logged XY | map=" & Map_GetMapID())
EndFunc

Func _SetIdleUiState()
	AdLibUnRegister("CombatMapper_SyncPauseFromGui")
	$g_b_PauseRequested = False
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_UNCHECKED)
	GUICtrlSetState($g_h_StartButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_PauseCheckbox, $GUI_DISABLE)
	GUICtrlSetState($g_h_StopButton, $GUI_DISABLE)
	GUICtrlSetState($g_h_NameCombo, $GUI_ENABLE)
	GUICtrlSetState($g_h_RefreshButton, $GUI_ENABLE)
	GUICtrlSetState($g_h_TargetCombo, $GUI_ENABLE)
EndFunc

Func _SaveGuiBoundsToConfig()
	IniWrite($GC_S_CONFIG, "Coverage", "MinX", GUICtrlRead($g_h_MinX))
	IniWrite($GC_S_CONFIG, "Coverage", "MaxX", GUICtrlRead($g_h_MaxX))
	IniWrite($GC_S_CONFIG, "Coverage", "MinY", GUICtrlRead($g_h_MinY))
	IniWrite($GC_S_CONFIG, "Coverage", "MaxY", GUICtrlRead($g_h_MaxY))
	IniWrite($GC_S_CONFIG, "Coverage", "GridStep", GUICtrlRead($g_h_GridStep))
EndFunc

Func RunSingleMap($a_s_Title)
	Out("=== Single map: " & $a_s_Title & " ===")
	If Not MapTravel_EnterTitle($a_s_Title) Then
		Out("Could not enter " & $a_s_Title)
		$g_b_BotRunning = False
		_SetIdleUiState()
		Return
	EndIf
	$g_s_CoverageMapTitle = $a_s_Title
	RunCoverageSweep()
	$g_s_CoverageMapTitle = ""
EndFunc

Func RunCaravanSequence()
	_Vanquisher_InitAscalonCaravanPlan()
	CombatLogger_LoadConfig()
	SmartCast_LoadConfig()
	LootPickup_LoadConfig()

	Local $l_s_LogStart = $g_s_CaravanLogStartMap
	Local $l_i_LogStartStage = _CaravanStageIndexByTitle($l_s_LogStart)
	If $l_i_LogStartStage < 0 Then
		Out("WARNING: CaravanLogStartMap '" & $l_s_LogStart & "' not on spine — logging/lawnmower from first map.")
		$l_i_LogStartStage = 0
		$l_s_LogStart = $g_a_AscalonCaravanPlan[0][8]
	EndIf

	Out("=== TOA Ascalon Caravan sequence (" & $GC_I_ASCALON_CARAVAN_MAP_COUNT & " maps) ===")
	Out("Entry: Temple of the Ages (" & $TheBlackCurtain_Outpost & "), Hard Mode=" & $g_b_HardMode)
	Out("Transit (no lawnmower) until: " & $l_s_LogStart)
	Out("From " & $l_s_LogStart & " onward: lawnmower each map + combat coord logging (skip if HM vanquished), then portal to next.")

	Local $l_i_LoopStart = 0
	Local $l_b_ResumeOnSpine = False

	If Map_GetInstanceInfo("IsExplorable") Then
		Local $l_i_CurrentStage = _Vanquisher_AscalonCaravanStageForCurrentMap()
		If $l_i_CurrentStage >= 0 And Number($g_a_AscalonCaravanPlan[$l_i_CurrentStage][0]) = Map_GetMapID() Then
			$l_b_ResumeOnSpine = True
			$l_i_LoopStart = $l_i_CurrentStage
			Out("Resume on caravan spine: " & $g_a_AscalonCaravanPlan[$l_i_CurrentStage][8] & _
				" (stage " & ($l_i_CurrentStage + 1) & "/" & $GC_I_ASCALON_CARAVAN_MAP_COUNT & ")")
			SmartCast_EnsureReady(True)
			VanquishCheck_OnMapLoaded()
			If $l_i_CurrentStage >= $l_i_LogStartStage Then
				If Not _CaravanProcessMapArrival($g_a_AscalonCaravanPlan[$l_i_CurrentStage][8], $l_i_LogStartStage, $l_s_LogStart) Then
					$g_b_BotRunning = False
					_SetIdleUiState()
					Return
				EndIf
			EndIf
		EndIf
	EndIf

	If Not $l_b_ResumeOnSpine Then
	If Not MapTravel_TravelToOutpost($TheBlackCurtain_Outpost) Then
		Out("Failed to travel to Temple of the Ages.")
		$g_b_BotRunning = False
		_SetIdleUiState()
		Return
	EndIf
	MapTravel_EnsureHardMode()

	; Leave TOA into first map (portal-only until LogStart)
	Local $l_s_First = $g_a_AscalonCaravanPlan[0][8]
	If Not MapTravel_EnterTitle($l_s_First, 8, True) Then
		Out("Failed to leave TOA into " & $l_s_First)
		$g_b_BotRunning = False
		_SetIdleUiState()
		Return
	EndIf
	SmartCast_EnsureReady(True)
	Out("On " & $l_s_First & " (MapID=" & Map_GetMapID() & "). Traversing caravan spine...")

	; If LogStart is the first map, sweep before leaving
	If 0 >= $l_i_LogStartStage Then
		VanquishCheck_OnMapLoaded()
		If Not _CaravanProcessMapArrival($l_s_First, $l_i_LogStartStage, $l_s_LogStart) Then
			$g_b_BotRunning = False
			_SetIdleUiState()
			Return
		EndIf
	EndIf
	EndIf

	Local $i
	For $i = $l_i_LoopStart To $GC_I_ASCALON_CARAVAN_MAP_COUNT - 2
		CombatMapper_WaitIfPaused()
		If Not $g_b_BotRunning Or $g_b_StopRequested Then ExitLoop

		Local $l_s_Here = $g_a_AscalonCaravanPlan[$i][8]
		Local $l_s_Next = $g_a_AscalonCaravanPlan[$i + 1][8]
		Local $l_i_NextID = Number($g_a_AscalonCaravanPlan[$i + 1][0])
		Local $l_i_HereID = Number($g_a_AscalonCaravanPlan[$i][0])

		Out("")
		Out("=== Stage " & ($i + 1) & "/" & $GC_I_ASCALON_CARAVAN_MAP_COUNT & _
			": portal " & $l_s_Here & " -> " & $l_s_Next & " (" & $l_i_NextID & ") ===")
		UpdateStatusLabel("portal " & ($i + 1) & "->" & ($i + 2) & " " & $l_s_Next)

		If Map_GetMapID() <> $l_i_HereID And Map_GetMapID() <> $l_i_NextID Then
			Out("Not on expected map (have " & Map_GetMapID() & "). Re-entering " & $l_s_Here & "...")
			If Not MapTravel_EnterTitle($l_s_Here, 8, True) Then
				Out("Re-enter failed; trying direct advance to " & $l_s_Next)
			EndIf
			SmartCast_EnsureReady(True)
		EndIf

		If Not MapTravel_AdvanceToTitle($l_s_Next) Then
			Out("Could not reach " & $l_s_Next & " — stopping caravan.")
			ExitLoop
		EndIf

		SmartCast_Invalidate()
		SmartCast_EnsureReady(True)
		VanquishCheck_OnMapLoaded()

		; Arrived on Next: from LogStart onward, log + sweep unless HM vanquished
		If ($i + 1) >= $l_i_LogStartStage Then
			If Not _CaravanProcessMapArrival($l_s_Next, $l_i_LogStartStage, $l_s_LogStart) Then ExitLoop
		Else
			Out("Reached " & $l_s_Next & " (transit only until " & $l_s_LogStart & ").")
		EndIf
	Next

	CombatLogger_FlushIfInCombat()
	Out("Caravan sequence finished. Events=" & CombatLogger_GetCount())
	If CombatLogger_GetLogFile() <> "" Then Out("Log file: " & CombatLogger_GetLogFile())
	UpdateStatusLabel("caravan done | events=" & CombatLogger_GetCount())
	$g_b_BotRunning = False
	_SetIdleUiState()
EndFunc

; On explorable arrival: enable logging if needed, sweep route unless HM vanquished.
Func _CaravanProcessMapArrival($a_s_Title, $a_i_LogStartStage, $a_s_LogStartTitle)
	If VanquishCheck_IsAreaVanquished() Then
		Out("Skip sweep on " & $a_s_Title & " — already vanquished in Hard Mode.")
		Return True
	EndIf
	If Not _CaravanMaybeStartLogging($a_i_LogStartStage, $a_s_LogStartTitle) Then Return False
	If Not _CaravanSweepCurrentMap($a_s_Title) Then
		Out("Lawnmower failed/stopped on " & $a_s_Title & " — stopping caravan.")
		Return False
	EndIf
	Return True
EndFunc

; Fresh lawnmower on the current explorable (reuses combat log session).
Func _CaravanSweepCurrentMap($a_s_Title)
	If Not $g_b_BotRunning Or $g_b_StopRequested Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then
		Out("Skip lawnmower — not explorable on " & $a_s_Title)
		Return False
	EndIf

	VanquishCheck_OnMapLoaded(False)
	If VanquishCheck_IsAreaVanquished() Then
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
	Out("Map sweep complete on " & $a_s_Title & ". Events=" & CombatLogger_GetCount())
	Return True
EndFunc

; Enable CSV combat logging once current map is at/after the configured start stage.
Func _CaravanMaybeStartLogging($a_i_LogStartStage, $a_s_LogStartTitle)
	If CombatLogger_IsSessionActive() Then Return True
	If $a_i_LogStartStage < 0 Then Return False

	Local $l_i_Now = Map_GetMapID()
	Local $l_i_Stage = _Vanquisher_AscalonCaravanStageForCurrentMap()
	Local $l_i_StartMapID = Number($g_a_AscalonCaravanPlan[$a_i_LogStartStage][0])

	If $l_i_Now = $l_i_StartMapID Or $l_i_Stage >= $a_i_LogStartStage Then
		Out("=== Combat logging ENABLED at " & $a_s_LogStartTitle & " (MapID=" & $l_i_Now & ") ===")
		If Not CombatLogger_StartSession() Then
			Out("Failed to start combat log session.")
			Return False
		EndIf
		Return True
	EndIf
	Return False
EndFunc

Func _CaravanStageIndexByTitle($a_s_Title)
	_Vanquisher_InitAscalonCaravanPlan()
	Local $i
	For $i = 0 To $GC_I_ASCALON_CARAVAN_MAP_COUNT - 1
		If $g_a_AscalonCaravanPlan[$i][8] = $a_s_Title Then Return $i
	Next
	Return -1
EndFunc

; $a_b_ReuseLogSession: keep existing CSV when already logging (caravan multi-map).
; $a_b_AllowResume: resume coverage_progress.ini (single-map only; caravan uses False).
Func RunCoverageSweep($a_b_ReuseLogSession = False, $a_b_AllowResume = True)
	If $g_b_SweepActive Then Return
	$g_b_SweepActive = True

	CombatLogger_LoadConfig()
	SmartCast_LoadConfig()
	LootPickup_LoadConfig()

	If $a_b_ReuseLogSession And CombatLogger_IsSessionActive() Then
		; Keep current log file across caravan maps
	Else
		If Not CombatLogger_StartSession() Then
			Out("Failed to start combat log session.")
			$g_b_SweepActive = False
			If Not MapCatalog_IsSequenceSelection($g_s_SelectedTarget) Then
				StopBot()
			EndIf
			Return
		EndIf
	EndIf

	SmartCast_EnsureReady(True)

	Local $l_b_HaveRoute = False
	If $a_b_AllowResume And $g_b_ResumeRequested Then
		$l_b_HaveRoute = Coverage_TryResume(True)
	EndIf

	If Not $l_b_HaveRoute Then
		Coverage_ClearProgress()
		If Not Coverage_BuildRoute(True) Then
			Out("No reachable coverage points. Check map mesh / tighten or widen bounds.")
			$g_b_SweepActive = False
			If Not MapCatalog_IsSequenceSelection($g_s_SelectedTarget) Then
				StopBot()
			EndIf
			Return
		EndIf
	EndIf

	Out("Starting coverage sweep: " & $g_i_CoverageCount & " waypoints, aggro=" & $g_f_AggroRange & _
		" | MapID=" & Map_GetMapID() & " | SmartCast=" & $g_b_SmartCastEnabled & _
		" | Loot=" & Int($g_b_LootPickupEnabled))

	Local Const $GC_I_WAYPOINT_TIMEOUT_MS = 120000
	Local Const $GC_I_WAYPOINT_MAX_RETRIES = 3
	Local $l_i_WaypointRetries = 0

	Coverage_ConfigurePathfinder(False)

	While $g_b_BotRunning And Not $g_b_StopRequested And Not Coverage_IsComplete()
		CombatMapper_WaitIfPaused()
		If $g_b_StopRequested Then ExitLoop
		Coverage_TrySkipPassedWaypoints($GC_F_COVERAGE_WAYPOINT_REACHED)

		Local $l_f_X = 0, $l_f_Y = 0
		If Not Coverage_GetCurrentPoint($l_f_X, $l_f_Y) Then ExitLoop

		Local $l_f_DistBefore = Agent_GetDistanceToXY($l_f_X, $l_f_Y)

		UpdateStatusLabel("moving " & ($g_i_CoverageIndex + 1) & "/" & $g_i_CoverageCount & _
			" -> (" & Round($l_f_X) & "," & Round($l_f_Y) & ") | events=" & CombatLogger_GetCount())
		Out("Coverage " & ($g_i_CoverageIndex + 1) & "/" & $g_i_CoverageCount & _
			" -> (" & Round($l_f_X) & "," & Round($l_f_Y) & ") dist=" & Round($l_f_DistBefore))

		SmartCast_EnsureReady(False)
		Local $hMove = TimerInit()
		Local $l_b_Ok = Pathfinder_MoveTo($l_f_X, $l_f_Y, -1, "UAI_GetObstacles", _
			$g_f_AggroRange, $g_f_FightRangeOut, $g_i_FinisherMode, "CombatMapper_Tick")
		LootPickup_Sweep()

		Local $l_f_DistAfter = Agent_GetDistanceToXY($l_f_X, $l_f_Y)

		If Not $l_b_Ok Then
			If $g_b_StopRequested Then
				Out("Pathfinder_MoveTo stopped by user.")
			Else
				Out("Pathfinder_MoveTo interrupted (map change / party defeated). Stopping map sweep.")
			EndIf
			ExitLoop
		EndIf

		If $l_f_DistAfter <= $GC_F_COVERAGE_WAYPOINT_REACHED Then
			Out("Waypoint " & ($g_i_CoverageIndex + 1) & " reached (dist=" & Round($l_f_DistAfter) & ").")
			Coverage_Advance()
			$l_i_WaypointRetries = 0
		ElseIf TimerDiff($hMove) > $GC_I_WAYPOINT_TIMEOUT_MS Then
			Out("Skip waypoint " & ($g_i_CoverageIndex + 1) & " — timeout (dist=" & Round($l_f_DistAfter) & ").")
			Coverage_Advance()
			$l_i_WaypointRetries = 0
		ElseIf $l_i_WaypointRetries >= $GC_I_WAYPOINT_MAX_RETRIES Then
			Out("Skip waypoint " & ($g_i_CoverageIndex + 1) & " — max retries (dist=" & Round($l_f_DistAfter) & ").")
			Coverage_Advance()
			$l_i_WaypointRetries = 0
		Else
			$l_i_WaypointRetries += 1
			Out("Retry waypoint " & ($g_i_CoverageIndex + 1) & " dist=" & Round($l_f_DistAfter) & _
				" (" & $l_i_WaypointRetries & "/" & $GC_I_WAYPOINT_MAX_RETRIES & ")")
		EndIf
	WEnd

	If Coverage_IsComplete() And Not $g_b_StopRequested Then
		CombatLogger_FlushIfInCombat()
		Out("Coverage complete on MapID=" & Map_GetMapID() & ". Combat events logged: " & CombatLogger_GetCount())
		Out("Log file: " & CombatLogger_GetLogFile())
		Coverage_ClearProgress()
		UpdateStatusLabel("complete | events=" & CombatLogger_GetCount())
	Else
		CombatLogger_FlushIfInCombat()
		Out("Sweep ended at " & $g_i_CoverageIndex & "/" & $g_i_CoverageCount & _
			" | events=" & CombatLogger_GetCount())
		Coverage_SaveProgress()
		UpdateStatusLabel("paused " & $g_i_CoverageIndex & "/" & $g_i_CoverageCount & _
			" | events=" & CombatLogger_GetCount())
	EndIf

	$g_b_SweepActive = False
	If Not MapCatalog_IsSequenceSelection($g_s_SelectedTarget) Then
		$g_b_BotRunning = False
		_SetIdleUiState()
	EndIf
EndFunc

; Combined CallFunc for Pathfinder_MoveTo
Func CombatMapper_Tick()
	CombatMapper_SyncPauseFromGui()
	CombatMapper_WaitIfPaused()
	If $g_b_StopRequested Then Return
	SmartCast_EnsureReady(False)
	CombatLogger_Tick()
	LootPickup_Tick()
	UpdateStatusLabel("XY=(" & Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & ")" & _
		" | events=" & CombatLogger_GetCount() & " | sc=" & Int($g_b_SmartCastReady))
EndFunc

; Compatibility wrapper expected by Pathfinder examples / README.
Func UAI_GetObstacles($a_f_Radius = 85, $a_f_DetectionRange = 4000, $a_s_CustomFilter = "")
	If $a_s_CustomFilter = "" Then $a_s_CustomFilter = "CombatMapper_IsStaticObstacle"
	Return Agent_GetAgentsAsObstacles($a_f_DetectionRange, $a_f_Radius, $a_s_CustomFilter)
EndFunc

Func CombatMapper_IsStaticObstacle($a_p_Agent)
	If $a_p_Agent = 0 Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "ID") = Agent_GetMyID() Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "Allegiance") = 3 Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "HP") <= 0 Then Return False
	If Agent_GetAgentInfo($a_p_Agent, "IsDead") Then Return False
	Return True
EndFunc
#EndRegion Bot

#Region Helpers
Func GuiButtonHandler()
	Switch @GUI_CtrlId
		Case $g_h_StartButton
			StartBot()
		Case $g_h_StopButton
			StopBot()
		Case $g_h_LogCoordButton
			LogMapCoordButton()
		Case $g_h_RefreshButton
			GUICtrlSetData($g_h_NameCombo, "")
			GUICtrlSetData($g_h_NameCombo, Scanner_GetLoggedCharNames())
		Case $g_h_OnTopCheckbox
			If GetChecked($g_h_OnTopCheckbox) Then
				WinSetOnTop($g_h_MainGui, "", 1)
			Else
				WinSetOnTop($g_h_MainGui, "", 0)
			EndIf
		Case $g_h_DebugCheckbox
			Log_SetDebugMode(GetChecked($g_h_DebugCheckbox))
		Case $GUI_EVENT_CLOSE
			_Exit()
	EndSwitch
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

Func _Exit()
	$g_b_StopRequested = True
	$g_b_BotRunning = False
	Exit
EndFunc
#EndRegion Helpers
