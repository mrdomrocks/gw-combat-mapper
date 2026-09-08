#RequireAdmin
#NoTrayIcon

#include "..\..\API\_GwAu3.au3"
#include "lib\EnsureConfig.au3"
#include "lib\maps\LocationsIDS.au3"
#include "lib\CaravanPlan.au3"
#include "lib\maps\GoOutRoutes.au3"
#include "lib\MapCatalog.au3"
#include "lib\MapTravel.au3"
#include "lib\Coverage.au3"
#include "lib\CombatLogger.au3"
#include "lib\SmartCast.au3"
#include "lib\VanquishCheck.au3"
#include "lib\LootPickup.au3"
#include "lib\CaravanGui.au3"
#include "lib\BotEngine.au3"
#include "lib\WaypointExport.au3"
#include "lib\DynamicSweep.au3"
#include "lib\MapBounds.au3"
#include "lib\DeathRecovery.au3"
#include "lib\Consumables.au3"
#include "lib\JununduMode.au3"
#include "lib\ChestLogger.au3"
#include "lib\HeroTeam.au3"

$DLL_PATH = @ScriptDir & "\..\..\API\Plugins\Pathfinder\GWPathfinder.dll"

Global Const $GC_B_LOAD_LOGGED_CHARS = True
Global Const $GC_S_BOT_TITLE = "GwAu3 Combat Mapper"
Global Const $GC_S_CONFIG = @ScriptDir & "\config.ini"

EnsureConfig_CopyIfMissing()

Global $g_b_CombatLoggingEnabled = True

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
Global $g_b_StartRequested = False
Global $g_b_LogCoordBusy = False
Global $g_s_SweepMode = "route"
Global $g_h_VanquishLabel = 0
Global $g_h_SweepModeCombo = 0
Global $g_h_ExportButton = 0
Global $g_h_LastStandCheckbox = 0
Global $g_h_ConsumablesCheckbox = 0
Global $g_h_JununduCheckbox = 0
Global $g_h_ChestLogCheckbox = 0
Global $g_h_HeroTeamCheckbox = 0
Global $g_b_HeroTeamEnabled = False
#EndRegion Globals

MapCatalog_Init()
HeroTeam_Init()

For $i = 1 To $CmdLine[0]
	If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
		$g_s_MainCharName = $CmdLine[$i + 1]
		$g_bAutoStart = True
		ExitLoop
	EndIf
Next

#Region GUI
$g_h_MainGui = GUICreate($GC_S_BOT_TITLE, 680, 720, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
GUISetBkColor(0xEAEAEA, $g_h_MainGui)
GUICtrlCreateGroup("Combat Mapper", 8, 8, 664, 700)

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
GUICtrlSetOnEvent($g_h_DebugCheckbox, "GuiButtonHandler")
Log_SetDebugMode(False)

$g_h_HardModeCheckbox = GUICtrlCreateCheckbox("Hard Mode", 340, 27, 85, 24)
If Number(IniRead($GC_S_CONFIG, "Travel", "HardMode", "1")) <> 0 Then
	GUICtrlSetState($g_h_HardModeCheckbox, $GUI_CHECKED)
Else
	GUICtrlSetState($g_h_HardModeCheckbox, $GUI_UNCHECKED)
EndIf

$g_h_ResumeCheckbox = GUICtrlCreateCheckbox("Resume coverage", 440, 27, 120, 24)
GUICtrlSetOnEvent($g_h_ResumeCheckbox, "GuiButtonHandler")

GUICtrlCreateLabel("Target:", 24, 60, 45, 18)
$g_h_TargetCombo = GUICtrlCreateCombo("", 70, 56, 280, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL, $WS_VSCROLL))
GUICtrlSetData($g_h_TargetCombo, MapCatalog_GetComboString(), IniRead($GC_S_CONFIG, "Travel", "LastTarget", "Current Map"))
GUICtrlSendMsg($g_h_TargetCombo, $CB_SETDROPPEDWIDTH, 360, 0)
GUICtrlSetOnEvent($g_h_TargetCombo, "CombatMapper_OnTargetChanged")

$g_h_StartButton = GUICtrlCreateButton("Start", 360, 55, 58, 25)
GUICtrlSetOnEvent($g_h_StartButton, "GuiButtonHandler")

Global $g_h_PauseCheckbox
$g_h_PauseCheckbox = GUICtrlCreateCheckbox("Paused (F8)", 426, 55, 105, 24)
GUICtrlSetOnEvent($g_h_PauseCheckbox, "CombatMapper_OnPauseCheckbox")
GUICtrlSetState($g_h_PauseCheckbox, $GUI_DISABLE)

$g_h_StopButton = GUICtrlCreateButton("Stop", 539, 55, 58, 25)
GUICtrlSetOnEvent($g_h_StopButton, "GuiButtonHandler")
GUICtrlSetState($g_h_StopButton, $GUI_DISABLE)

Global $g_h_LogCoordButton
$g_h_LogCoordButton = GUICtrlCreateCheckbox("Log XY", 603, 55, 58, 25, BitOR($BS_PUSHLIKE, $BS_AUTOCHECKBOX))

$g_h_RefreshButton = GUICtrlCreateButton("Refresh", 520, 90, 58, 20)
GUICtrlSetOnEvent($g_h_RefreshButton, "GuiButtonHandler")

GUICtrlCreateLabel("MinX", 24, 92, 30, 18)
$g_h_MinX = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MinX", "0"), 54, 90, 55, 20)
GUICtrlCreateLabel("MaxX", 120, 92, 35, 18)
$g_h_MaxX = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MaxX", "0"), 155, 90, 55, 20)
GUICtrlCreateLabel("MinY", 220, 92, 30, 18)
$g_h_MinY = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MinY", "0"), 250, 90, 55, 20)
GUICtrlCreateLabel("MaxY", 315, 92, 35, 18)
$g_h_MaxY = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "MaxY", "0"), 345, 90, 55, 20)
GUICtrlCreateLabel("Step", 410, 92, 30, 18)
$g_h_GridStep = GUICtrlCreateInput(IniRead($GC_S_CONFIG, "Coverage", "GridStep", "2000"), 440, 90, 55, 20)

GUICtrlCreateLabel("Sweep:", 505, 92, 40, 18)
$g_h_SweepModeCombo = GUICtrlCreateCombo("", 545, 90, 110, 25, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
GUICtrlSetData($g_h_SweepModeCombo, "Vanquish Route|Grid Coverage|Dynamic Enemy Hunt")
GUICtrlSetData($g_h_SweepModeCombo, IniRead($GC_S_CONFIG, "Coverage", "SweepMode", "Vanquish Route"))

$g_h_LastStandCheckbox = GUICtrlCreateCheckbox("Last Stand (<20)", 24, 114, 115, 22)
If Number(IniRead($GC_S_CONFIG, "Recovery", "LastStand", "0")) <> 0 Then
	GUICtrlSetState($g_h_LastStandCheckbox, $GUI_CHECKED)
EndIf
$g_h_ConsumablesCheckbox = GUICtrlCreateCheckbox("Consumables", 145, 114, 95, 22)
If Number(IniRead($GC_S_CONFIG, "Consumables", "Enabled", "0")) <> 0 Then
	GUICtrlSetState($g_h_ConsumablesCheckbox, $GUI_CHECKED)
EndIf
$g_h_JununduCheckbox = GUICtrlCreateCheckbox("Junundu", 245, 114, 75, 22)
If Number(IniRead($GC_S_CONFIG, "Junundu", "Enabled", "0")) <> 0 Then
	GUICtrlSetState($g_h_JununduCheckbox, $GUI_CHECKED)
EndIf
$g_h_ChestLogCheckbox = GUICtrlCreateCheckbox("Chest log", 325, 114, 75, 22)
If Number(IniRead($GC_S_CONFIG, "Log", "ChestLogging", "0")) <> 0 Then
	GUICtrlSetState($g_h_ChestLogCheckbox, $GUI_CHECKED)
EndIf
$g_h_HeroTeamCheckbox = GUICtrlCreateCheckbox("Hero team", 405, 114, 80, 22)
$g_h_ExportButton = GUICtrlCreateButton("Export MVR", 600, 112, 58, 22)
GUICtrlSetOnEvent($g_h_ExportButton, "GuiButtonHandler")

Global $g_h_CaravanMapsLabel = GUICtrlCreateLabel("Map List (Ctrl+click):", 24, 140, 200, 16)
$g_h_CaravanMapList = GUICtrlCreateList("", 24, 156, 500, 88, BitOR($LBS_EXTENDEDSEL, $WS_VSCROLL, $WS_BORDER))
$g_h_CaravanAllButton = GUICtrlCreateButton("All", 532, 156, 58, 22)
GUICtrlSetOnEvent($g_h_CaravanAllButton, "GuiButtonHandler")
$g_h_CaravanNoneButton = GUICtrlCreateButton("None", 598, 156, 58, 22)
GUICtrlSetOnEvent($g_h_CaravanNoneButton, "GuiButtonHandler")
$g_h_SkipVanquishedCheckbox = GUICtrlCreateCheckbox("Skip completed", 532, 184, 120, 22)
If Number(IniRead($GC_S_CONFIG, "Travel", "SkipVanquished", "1")) <> 0 Then
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_CHECKED)
Else
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_UNCHECKED)
EndIf
Global $g_h_CaravanHintLabel = GUICtrlCreateLabel("Selected maps are farmed; unselected maps are portal transit only.", 24, 246, 640, 16)

$g_h_VanquishLabel = GUICtrlCreateLabel("Vanquish: idle", 24, 264, 640, 18)
$g_h_StatusLabel = GUICtrlCreateLabel("Status: idle", 24, 284, 640, 22)

$g_h_EditText = _GUICtrlRichEdit_Create($g_h_MainGui, "", 16, 308, 648, 384, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
_GUICtrlRichEdit_SetBkColor($g_h_EditText, $COLOR_WHITE)

GUICtrlCreateGroup("", -99, -99, 1, 1)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUISetState(@SW_SHOW)
AdLibRegister("CombatMapper_PollGui", 50)
CaravanGui_Refresh()
#EndRegion GUI

Out("GwAu3 Map Coverage Combat Logger")
Out("Target: Current Map, Ascalon/Maguuma caravan, or a region (Nightfall Kourna, Factions The Jade Sea, ...).")
Out("Map List: Ctrl+click maps to vanquish. Caravans still use unselected maps as portal transit.")
Out("Skip completed: already-vanquished maps are not farmed. Finished sequences travel back to campaign hub.")
Out("Log XY: append player position to logs/map_waypoints_<MapID>.csv (button or F7; works while paused).")
Out("Auto route log: while running, player path appends to the same file (config Log.AutoRouteCoords).")
Out("Export MVR: convert logs to exports/<Title>_MVR.au3 for Master Vanquisher.")
Out("Sweep modes: Vanquish Route (hand-tuned), Grid Coverage (lawnmower), Dynamic Enemy Hunt.")
Out("Pathfinder stuck spots append to logs/pathfinder_stuck_<MapID>.csv (same columns as combat logs)." & @CRLF)

Core_AutoStart()

HotKeySet("{F7}", "HotKey_LogCoord")
HotKeySet("{F8}", "HotKey_TogglePause")
HotKeySet("{F9}", "HotKey_Stop")

While 1
	Sleep(100)
	CombatMapper_PollGui()
	If $g_b_StartRequested And Not $g_b_BotRunning Then
		$g_b_StartRequested = False
		StartBot()
	EndIf
WEnd

Func StartBot()
	BotEngine_Start()
EndFunc

Func _BotHook_OnBeforeRun()
	_SaveGuiBoundsToConfig()
	CombatMapper_SyncFeatureTogglesFromGui()
	DeathRecovery_LoadConfig($GC_S_CONFIG)
	Consumables_LoadConfig($GC_S_CONFIG)
	JununduMode_LoadConfig($GC_S_CONFIG)
	ChestLogger_LoadConfig($GC_S_CONFIG)
	WaypointExport_LoadConfig($GC_S_CONFIG)
	If Map_GetMapID() > 0 Then MapBounds_TryAutoLoadCurrent()
EndFunc

Func CombatMapper_SyncFeatureTogglesFromGui()
	$g_s_SweepMode = GUICtrlRead($g_h_SweepModeCombo)
	IniWrite($GC_S_CONFIG, "Coverage", "SweepMode", $g_s_SweepMode)
	$g_b_LastStandEnabled = GetChecked($g_h_LastStandCheckbox)
	IniWrite($GC_S_CONFIG, "Recovery", "LastStand", Int($g_b_LastStandEnabled))
	$g_b_ConsumablesEnabled = GetChecked($g_h_ConsumablesCheckbox)
	IniWrite($GC_S_CONFIG, "Consumables", "Enabled", Int($g_b_ConsumablesEnabled))
	$g_b_JununduModeEnabled = GetChecked($g_h_JununduCheckbox)
	IniWrite($GC_S_CONFIG, "Junundu", "Enabled", Int($g_b_JununduModeEnabled))
	$g_b_ChestLoggerEnabled = GetChecked($g_h_ChestLogCheckbox)
	IniWrite($GC_S_CONFIG, "Log", "ChestLogging", Int($g_b_ChestLoggerEnabled))
	$g_b_HeroTeamEnabled = GetChecked($g_h_HeroTeamCheckbox)
EndFunc

Func ExportWaypointsButton()
	If Not _EnsureGameAttachedForLogging() Then
		Out("Export: attach to Guild Wars first.")
		Return
	EndIf
	CombatMapper_SyncFeatureTogglesFromGui()
	Local $l_s_Title = $g_s_CoverageMapTitle
	If $l_s_Title = "" And $g_s_SelectedTarget <> "Current Map" Then $l_s_Title = $g_s_SelectedTarget
	WaypointExport_ExportMap(Map_GetMapID(), $l_s_Title, True)
EndFunc

Func _BotHook_PrintInitControls()
	Out("Controls: F8 pause/resume | F9 stop | F7 log XY")
EndFunc

Func _BotHook_PollDuringTick()
	CombatMapper_PollGui()
	VanquishCheck_UpdateGui()
EndFunc

Func CombatMapper_OnPauseCheckbox()
	BotEngine_PollPause()
EndFunc

Func _BotHook_OnPauseChanged($a_b_Paused)
	If $a_b_Paused Then
		Out("Paused — manual movement OK, Log XY or F7, F8 to resume.")
		UpdateStatusLabel("PAUSED | Log XY or F7")
	Else
		Out("Resumed.")
		If $g_b_BotRunning Then UpdateStatusLabel("running")
	EndIf
EndFunc

Func HotKey_LogCoord()
	LogMapCoordButton()
EndFunc

Func CombatMapper_PollLogCoordFromGui()
	If $g_b_LogCoordBusy Then Return
	If Not GetChecked($g_h_LogCoordButton) Then Return
	$g_b_LogCoordBusy = True
	GUICtrlSetState($g_h_LogCoordButton, $GUI_UNCHECKED)
	LogMapCoordButton()
	$g_b_LogCoordBusy = False
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

Func CombatMapper_PollGui()
	CombatMapper_PollLogCoordFromGui()
	BotEngine_PollPause()
EndFunc

Func LogMapCoordButton()
	If Not _EnsureGameAttachedForLogging() Then
		Out("Log XY: attach to Guild Wars first (pick a character or Start once).")
		UpdateStatusLabel("Log XY failed — not attached")
		Return
	EndIf
	CombatLogger_LoadConfig()
	If Not CombatLogger_LogMapCoord("manual") Then
		Out("ERROR: Could not log map coordinate.")
		UpdateStatusLabel("Log XY failed")
		Return
	EndIf
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	Out("Logged XY map " & Map_GetMapID() & " @ (" & Round($l_f_X, 2) & ", " & Round($l_f_Y, 2) & ")")
	Out("  array: [" & Round($l_f_X, 2) & ", " & Round($l_f_Y, 2) & "], _")
	Out("  file: " & CombatLogger_GetMapCoordLogFile() & " (#" & CombatLogger_GetMapCoordCount() & ")")
	UpdateStatusLabel("logged XY | map=" & Map_GetMapID())
	If IsFunc("MapBounds_UpdateFromPoint") Then MapBounds_UpdateFromPoint(Map_GetMapID(), $l_f_X, $l_f_Y, 500)
EndFunc

Func _SaveGuiBoundsToConfig()
	IniWrite($GC_S_CONFIG, "Coverage", "MinX", GUICtrlRead($g_h_MinX))
	IniWrite($GC_S_CONFIG, "Coverage", "MaxX", GUICtrlRead($g_h_MaxX))
	IniWrite($GC_S_CONFIG, "Coverage", "MinY", GUICtrlRead($g_h_MinY))
	IniWrite($GC_S_CONFIG, "Coverage", "MaxY", GUICtrlRead($g_h_MaxY))
	IniWrite($GC_S_CONFIG, "Coverage", "GridStep", GUICtrlRead($g_h_GridStep))
EndFunc

Func CombatMapper_IsStaticObstacle($a_p_Agent)
	Return BotEngine_IsStaticObstacle($a_p_Agent)
EndFunc

Func UAI_GetObstacles($a_f_Radius = 85, $a_f_DetectionRange = 4000, $a_s_CustomFilter = "")
	Return BotEngine_GetObstacles($a_f_Radius, $a_f_DetectionRange, "CombatMapper_IsStaticObstacle")
EndFunc

Func GuiButtonHandler()
	Switch @GUI_CtrlId
		Case $g_h_StartButton
			$g_b_StartRequested = True
		Case $g_h_StopButton
			StopBot()
		Case $g_h_RefreshButton
			GUICtrlSetData($g_h_NameCombo, "")
			GUICtrlSetData($g_h_NameCombo, Scanner_GetLoggedCharNames())
		Case $g_h_CaravanAllButton
			CaravanGui_SelectAll(True)
		Case $g_h_CaravanNoneButton
			CaravanGui_SelectAll(False)
		Case $g_h_ExportButton
			ExportWaypointsButton()
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

Func CombatMapper_OnTargetChanged()
	CaravanGui_SaveSelection()
	CaravanGui_Refresh()
EndFunc

Func _Exit()
	$g_b_StopRequested = True
	$g_b_BotRunning = False
	Exit
EndFunc
