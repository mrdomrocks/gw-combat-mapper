#RequireAdmin
#NoTrayIcon

#include "vendor\GwAu3\API\_GwAu3.au3"
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

$DLL_PATH = @ScriptDir & "\vendor\GwAu3\API\Plugins\Pathfinder\GWPathfinder.dll"

Global Const $GC_B_LOAD_LOGGED_CHARS = True
Global Const $GC_S_BOT_TITLE = "GwAu3 Combat Mapper"
Global Const $GC_S_CONFIG = @ScriptDir & "\config.ini"

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
#EndRegion Globals

MapCatalog_Init()

For $i = 1 To $CmdLine[0]
	If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
		$g_s_MainCharName = $CmdLine[$i + 1]
		$g_bAutoStart = True
		ExitLoop
	EndIf
Next

#Region GUI
$g_h_MainGui = GUICreate($GC_S_BOT_TITLE, 680, 660, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
GUISetBkColor(0xEAEAEA, $g_h_MainGui)
GUICtrlCreateGroup("Combat Mapper", 8, 8, 664, 640)

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

Global $g_h_CaravanMapsLabel = GUICtrlCreateLabel("Map List (Ctrl+click):", 24, 116, 200, 16)
$g_h_CaravanMapList = GUICtrlCreateList("", 24, 132, 500, 88, BitOR($LBS_EXTENDEDSEL, $WS_VSCROLL, $WS_BORDER))
$g_h_CaravanAllButton = GUICtrlCreateButton("All", 532, 132, 58, 22)
GUICtrlSetOnEvent($g_h_CaravanAllButton, "GuiButtonHandler")
$g_h_CaravanNoneButton = GUICtrlCreateButton("None", 598, 132, 58, 22)
GUICtrlSetOnEvent($g_h_CaravanNoneButton, "GuiButtonHandler")
$g_h_SkipVanquishedCheckbox = GUICtrlCreateCheckbox("Skip completed", 532, 160, 120, 22)
If Number(IniRead($GC_S_CONFIG, "Travel", "SkipVanquished", "1")) <> 0 Then
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_CHECKED)
Else
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_UNCHECKED)
EndIf
Global $g_h_CaravanHintLabel = GUICtrlCreateLabel("Selected maps are farmed; unselected maps are skipped.", 24, 222, 640, 16)

$g_h_StatusLabel = GUICtrlCreateLabel("Status: idle", 24, 240, 640, 22)

$g_h_EditText = _GUICtrlRichEdit_Create($g_h_MainGui, "", 16, 264, 648, 368, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
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
Out("Log XY: append player position to logs/map_waypoints_<MapID>.csv (button or F7; works while paused)." & @CRLF)

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
EndFunc

Func _BotHook_PrintInitControls()
	Out("Controls: F8 pause/resume | F9 stop | F7 log XY (work during pathfinder)")
EndFunc

Func CombatMapper_PollGui()
	CombatMapper_PollLogCoordFromGui()
	BotEngine_PollPause()
EndFunc

Func _BotHook_PollDuringTick()
	CombatMapper_PollGui()
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
