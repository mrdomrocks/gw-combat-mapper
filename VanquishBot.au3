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
#include "lib\Combat.au3"
#include "lib\VanquishCheck.au3"
#include "lib\LootPickup.au3"
#include "lib\CaravanGui.au3"
#include "lib\HeroTeam.au3"
#include "lib\BotEngine.au3"

$DLL_PATH = @ScriptDir & "\..\..\API\Plugins\Pathfinder\GWPathfinder.dll"

Global Const $GC_B_LOAD_LOGGED_CHARS = True
Global Const $GC_S_BOT_TITLE = "Guild Wars Vanquish Bot"
Global Const $GC_S_CONFIG = @ScriptDir & "\config.ini"

EnsureConfig_CopyIfMissing()

Global $g_b_CombatLoggingEnabled = False
Global $g_b_HeroTeamEnabled = True

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
Global $g_i_GuiListWidth = 220
Global $g_i_CampaignComboWidth = 280
Global $g_i_CampaignComboLeft = 94
Global $g_h_CampaignLabel = 0
Global $g_i_GuiContentWidth = 0
Global $g_h_OuterGroup = 0
Global $g_h_StatusLabel = 0
Global $g_h_EditText = 0
#EndRegion Globals

MapCatalog_Init()
HeroTeam_Init()
$g_i_GuiListWidth = CaravanGui_EstimateListWidthFromCatalog()
$g_i_CampaignComboWidth = CaravanGui_EstimateComboWidth(MapCatalog_GetLongestComboName())

For $i = 1 To $CmdLine[0]
	If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
		$g_s_MainCharName = $CmdLine[$i + 1]
		$g_bAutoStart = True
		ExitLoop
	EndIf
Next

#Region GUI
Global Const $GC_I_GUI_MARGIN = 16
Global Const $GC_I_GUI_INNER = 24
Global Const $GC_I_GUI_ROW1 = 28
Global Const $GC_I_GUI_ROW2 = 56
Global Const $GC_I_GUI_ROW3 = 84
Global Const $GC_I_GUI_CAMPAIGN_LABEL_WIDTH = 68
$g_i_CampaignComboLeft = $GC_I_GUI_INNER + $GC_I_GUI_CAMPAIGN_LABEL_WIDTH + 6
Global Const $GC_I_GUI_LIST_LABEL_TOP = 118
Global Const $GC_I_GUI_LIST_TOP = 138
Global Const $GC_I_GUI_LIST_HEIGHT = $GC_I_HERO_TOP_ROW_HEIGHT
Global Const $GC_I_GUI_LIST_BTN_TOP = $GC_I_GUI_LIST_TOP + $GC_I_GUI_LIST_HEIGHT + 4
Global Const $GC_I_GUI_HINT_TOP = $GC_I_GUI_LIST_BTN_TOP + 48
Global Const $GC_I_GUI_HINT_HEIGHT = 64
Global Const $GC_I_GUI_TEAM8_TOP = $GC_I_GUI_LIST_TOP + $GC_I_HERO_TOP_ROW_HEIGHT + $GC_I_HERO_TEAM_GAP
Global Const $GC_I_GUI_STATUS_TOP = $GC_I_GUI_HINT_TOP + $GC_I_GUI_HINT_HEIGHT + 16
Global Const $GC_I_GUI_CONSOLE_TOP = $GC_I_GUI_STATUS_TOP + 24
Global Const $GC_I_GUI_CONSOLE_HEIGHT = 220
Global Const $GC_I_GUI_HEIGHT = $GC_I_GUI_CONSOLE_TOP + $GC_I_GUI_CONSOLE_HEIGHT + 16
$g_i_GuiContentWidth = VanquishBot_ContentRight() - $GC_I_GUI_MARGIN

$g_h_MainGui = GUICreate($GC_S_BOT_TITLE, $g_i_GuiContentWidth + ($GC_I_GUI_MARGIN * 2), $GC_I_GUI_HEIGHT, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
GUISetBkColor(0xEAEAEA, $g_h_MainGui)
$g_h_OuterGroup = GUICtrlCreateGroup("Vanquish Bot", 8, 8, VanquishBot_ContentRight(), $GC_I_GUI_HEIGHT - 20)

Global $g_h_NameCombo
If $GC_B_LOAD_LOGGED_CHARS Then
	$g_h_NameCombo = GUICtrlCreateCombo($g_s_MainCharName, $GC_I_GUI_INNER, $GC_I_GUI_ROW1, $g_i_HeroDropdownWidth, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
	GUICtrlSetData(-1, Scanner_GetLoggedCharNames())
Else
	$g_h_NameCombo = GUICtrlCreateInput($g_s_MainCharName, $GC_I_GUI_INNER, $GC_I_GUI_ROW1, $g_i_HeroDropdownWidth, 25)
EndIf
HeroTeam_ApplyMeasuredDropdownWidth($g_h_NameCombo)
$g_i_CampaignComboWidth = CaravanGui_ComboWidthForText($g_h_NameCombo, MapCatalog_GetLongestComboName())
$g_i_GuiListWidth = CaravanGui_MeasureStableListWidth($g_h_NameCombo)
GUICtrlSetPos($g_h_NameCombo, $GC_I_GUI_INNER, $GC_I_GUI_ROW1, $g_i_HeroDropdownWidth, 25)
If $GC_B_LOAD_LOGGED_CHARS Then GUICtrlSendMsg($g_h_NameCombo, $CB_SETDROPPEDWIDTH, $g_i_HeroDropdownWidth, 0)

Local $l_i_AfterName = $GC_I_GUI_INNER + $g_i_HeroDropdownWidth + 12
Local $l_i_OnTopW = 72
Local $l_i_DebugW = 64
Local $l_i_HardW = 92
Local $l_i_BoxGap = 12
$g_h_OnTopCheckbox = GUICtrlCreateCheckbox("On Top", $l_i_AfterName, 27, $l_i_OnTopW, 24)
GUICtrlSetState($g_h_OnTopCheckbox, $GUI_CHECKED)
GUICtrlSetOnEvent($g_h_OnTopCheckbox, "GuiButtonHandler")

$g_h_DebugCheckbox = GUICtrlCreateCheckbox("Debug", $l_i_AfterName + $l_i_OnTopW + $l_i_BoxGap, 27, $l_i_DebugW, 24)
GUICtrlSetOnEvent($g_h_DebugCheckbox, "GuiButtonHandler")
Log_SetDebugMode(False)

$g_h_HardModeCheckbox = GUICtrlCreateCheckbox("Hard Mode", $l_i_AfterName + $l_i_OnTopW + $l_i_BoxGap + $l_i_DebugW + $l_i_BoxGap, 27, $l_i_HardW, 24)
If Number(IniRead($GC_S_CONFIG, "Travel", "HardMode", "1")) <> 0 Then
	GUICtrlSetState($g_h_HardModeCheckbox, $GUI_CHECKED)
Else
	GUICtrlSetState($g_h_HardModeCheckbox, $GUI_UNCHECKED)
EndIf

$g_h_CampaignLabel = GUICtrlCreateLabel("Campaign:", $GC_I_GUI_INNER, 60, $GC_I_GUI_CAMPAIGN_LABEL_WIDTH, 18)
$g_h_TargetCombo = GUICtrlCreateCombo("", $g_i_CampaignComboLeft, $GC_I_GUI_ROW2, $g_i_CampaignComboWidth, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL, $WS_VSCROLL))
GUICtrlSetData($g_h_TargetCombo, MapCatalog_GetComboString(), IniRead($GC_S_CONFIG, "Travel", "LastTarget", "Current Map"))
GUICtrlSendMsg($g_h_TargetCombo, $CB_SETDROPPEDWIDTH, $g_i_CampaignComboWidth, 0)
GUICtrlSetOnEvent($g_h_TargetCombo, "VanquishBot_OnTargetChanged")

Local $l_i_BtnLeft = VanquishBot_ContentRight() - 166
$g_h_StartButton = GUICtrlCreateButton("Start", $l_i_BtnLeft, 55, 58, 25)
GUICtrlSetOnEvent($g_h_StartButton, "GuiButtonHandler")

Global $g_h_PauseCheckbox
$g_h_PauseCheckbox = GUICtrlCreateCheckbox("Paused (F8)", $l_i_BtnLeft + 64, 55, 102, 24)
GUICtrlSetOnEvent($g_h_PauseCheckbox, "BotEngine_OnPauseCheckbox")
GUICtrlSetState($g_h_PauseCheckbox, $GUI_DISABLE)

$g_h_StopButton = GUICtrlCreateButton("Stop", $l_i_BtnLeft, $GC_I_GUI_ROW3, 58, 25)
GUICtrlSetOnEvent($g_h_StopButton, "GuiButtonHandler")
GUICtrlSetState($g_h_StopButton, $GUI_DISABLE)

$g_h_RefreshButton = GUICtrlCreateButton("Refresh", $l_i_BtnLeft + 64, $GC_I_GUI_ROW3, 58, 25)
GUICtrlSetOnEvent($g_h_RefreshButton, "GuiButtonHandler")

$g_h_ResumeCheckbox = GUICtrlCreateCheckbox("Resume coverage", $GC_I_GUI_INNER, $GC_I_GUI_ROW3, 118, 24)
GUICtrlSetOnEvent($g_h_ResumeCheckbox, "GuiButtonHandler")

Global $g_h_CaravanMapsLabel = GUICtrlCreateLabel("Map List (Ctrl+click):", $GC_I_GUI_INNER, $GC_I_GUI_LIST_LABEL_TOP, $g_i_GuiListWidth, 18)
$g_h_CaravanMapList = GUICtrlCreateList("", $GC_I_GUI_INNER, $GC_I_GUI_LIST_TOP, $g_i_GuiListWidth, $GC_I_GUI_LIST_HEIGHT, BitOR($LBS_EXTENDEDSEL, $WS_VSCROLL, $WS_BORDER))

$g_h_CaravanAllButton = GUICtrlCreateButton("All", $GC_I_GUI_INNER, $GC_I_GUI_LIST_BTN_TOP, 48, 22)
GUICtrlSetOnEvent($g_h_CaravanAllButton, "GuiButtonHandler")
$g_h_CaravanNoneButton = GUICtrlCreateButton("None", $GC_I_GUI_INNER + 52, $GC_I_GUI_LIST_BTN_TOP, 48, 22)
GUICtrlSetOnEvent($g_h_CaravanNoneButton, "GuiButtonHandler")
$g_h_SkipVanquishedCheckbox = GUICtrlCreateCheckbox("Skip completed", $GC_I_GUI_INNER, $GC_I_GUI_LIST_BTN_TOP + 24, $g_i_GuiListWidth, 22)
If Number(IniRead($GC_S_CONFIG, "Travel", "SkipVanquished", "1")) <> 0 Then
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_CHECKED)
Else
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $GUI_UNCHECKED)
EndIf

Global $g_h_CaravanHintLabel = GUICtrlCreateLabel("Selected maps are farmed; unselected maps are portal transit only.", $GC_I_GUI_INNER, $GC_I_GUI_HINT_TOP, $g_i_GuiListWidth, $GC_I_GUI_HINT_HEIGHT)

AdLibRegister("VanquishBot_PollGui", 50)
CaravanGui_Refresh()
HeroTeam_CreateGuiControls($GC_I_GUI_INNER, $GC_I_GUI_LIST_TOP, $g_i_GuiListWidth, $GC_I_GUI_INNER, VanquishBot_ContentRight() - $GC_I_GUI_INNER)

$g_h_StatusLabel = GUICtrlCreateLabel("Status: idle", $GC_I_GUI_INNER, $GC_I_GUI_STATUS_TOP, VanquishBot_ContentRight() - $GC_I_GUI_INNER, 22)

$g_h_EditText = _GUICtrlRichEdit_Create($g_h_MainGui, "", $GC_I_GUI_MARGIN, $GC_I_GUI_CONSOLE_TOP, $g_i_GuiContentWidth, $GC_I_GUI_CONSOLE_HEIGHT, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
_GUICtrlRichEdit_SetBkColor($g_h_EditText, $COLOR_WHITE)

GUICtrlCreateGroup("", -99, -99, 1, 1)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUISetState(@SW_SHOW)
VanquishBot_ApplyColumnLayout()
HeroTeam_LoadConfig()
HeroTeam_RefreshSelectionState(0)
#EndRegion GUI

Out("Guild Wars Vanquish Bot")
Out("Campaign: Current Map, Ascalon/Maguuma caravan, or a region (Nightfall Kourna, Factions The Jade Sea, ...).")
Out("Map List: Ctrl+click maps to vanquish. Caravans still use unselected maps as portal transit.")
Out("Configure Team 4 / 6 / 8 heroes for the maps you plan to run." & @CRLF)

Core_AutoStart()

HotKeySet("{F8}", "HotKey_TogglePause")
HotKeySet("{F9}", "HotKey_Stop")

While 1
	Sleep(100)
	VanquishBot_PollGui()
	If $g_b_StartRequested And Not $g_b_BotRunning Then
		$g_b_StartRequested = False
		StartBot()
	EndIf
WEnd

Func StartBot()
	BotEngine_Start()
EndFunc

Func VanquishBot_PollGui()
	BotEngine_PollPause()
EndFunc

Func VanquishBot_OnTargetChanged()
	CaravanGui_SaveSelection()
	CaravanGui_Refresh()
EndFunc

Func VanquishBot_ApplyColumnLayout()
	Local $l_i_Width = $g_i_GuiListWidth
	If $g_h_CaravanMapsLabel Then GUICtrlSetPos($g_h_CaravanMapsLabel, $GC_I_GUI_INNER, $GC_I_GUI_LIST_LABEL_TOP, $l_i_Width, 18)
	If $g_h_CaravanMapList Then GUICtrlSetPos($g_h_CaravanMapList, $GC_I_GUI_INNER, $GC_I_GUI_LIST_TOP, $l_i_Width, $GC_I_GUI_LIST_HEIGHT)
	If $g_h_CaravanAllButton Then GUICtrlSetPos($g_h_CaravanAllButton, $GC_I_GUI_INNER, $GC_I_GUI_LIST_BTN_TOP, 48, 22)
	If $g_h_CaravanNoneButton Then GUICtrlSetPos($g_h_CaravanNoneButton, $GC_I_GUI_INNER + 52, $GC_I_GUI_LIST_BTN_TOP, 48, 22)
	If $g_h_SkipVanquishedCheckbox Then GUICtrlSetPos($g_h_SkipVanquishedCheckbox, $GC_I_GUI_INNER, $GC_I_GUI_LIST_BTN_TOP + 24, $l_i_Width, 22)
	If $g_h_CaravanHintLabel Then GUICtrlSetPos($g_h_CaravanHintLabel, $GC_I_GUI_INNER, $GC_I_GUI_HINT_TOP, $l_i_Width, $GC_I_GUI_HINT_HEIGHT)
	HeroTeam_RepositionLayout($GC_I_GUI_INNER, $GC_I_GUI_LIST_TOP, $l_i_Width)
	VanquishBot_LayoutChrome()
EndFunc

Func VanquishBot_ContentRight($a_i_ListWidth = 0)
	If $a_i_ListWidth < 1 Then $a_i_ListWidth = $g_i_GuiListWidth
	Local $iTeams = $GC_I_GUI_INNER + $a_i_ListWidth + 8 + HeroTeam_PanelWidth()
	Local $iCampaign = $g_i_CampaignComboLeft + $g_i_CampaignComboWidth + 8 + 166
	Local $iNameRow = $GC_I_GUI_INNER + $g_i_HeroDropdownWidth + 12 + 72 + 12 + 64 + 12 + 92
	If $iCampaign > $iTeams Then $iTeams = $iCampaign
	If $iNameRow > $iTeams Then $iTeams = $iNameRow
	Return $iTeams
EndFunc

Func VanquishBot_LayoutChrome()
	If $g_h_MainGui = 0 Then Return
	Local $iRight = VanquishBot_ContentRight()
	$g_i_GuiContentWidth = $iRight - $GC_I_GUI_MARGIN
	Local $iWindowClient = $g_i_GuiContentWidth + ($GC_I_GUI_MARGIN * 2)
	Local $iCampaignRight = $g_i_CampaignComboLeft + $g_i_CampaignComboWidth
	Local $iBtnLeft = $iRight - 166
	If $iBtnLeft < $iCampaignRight + 8 Then $iBtnLeft = $iCampaignRight + 8
	Local $iInnerWidth = $iRight - $GC_I_GUI_INNER

	Local $aPos = WinGetPos($g_h_MainGui)
	Local $aClient = WinGetClientSize($g_h_MainGui)
	If IsArray($aPos) And IsArray($aClient) Then
		Local $iFrameW = $aPos[2] - $aClient[0]
		Local $iFrameH = $aPos[3] - $aClient[1]
		WinMove($g_h_MainGui, "", $aPos[0], $aPos[1], $iWindowClient + $iFrameW, $GC_I_GUI_HEIGHT + $iFrameH)
	EndIf

	If $g_h_OuterGroup Then GUICtrlSetPos($g_h_OuterGroup, 8, 8, $iRight, $GC_I_GUI_HEIGHT - 20)
	If $g_h_StartButton Then GUICtrlSetPos($g_h_StartButton, $iBtnLeft, 55, 58, 25)
	If $g_h_PauseCheckbox Then GUICtrlSetPos($g_h_PauseCheckbox, $iBtnLeft + 64, 55, 102, 24)
	If $g_h_StopButton Then GUICtrlSetPos($g_h_StopButton, $iBtnLeft, $GC_I_GUI_ROW3, 58, 25)
	If $g_h_RefreshButton Then GUICtrlSetPos($g_h_RefreshButton, $iBtnLeft + 64, $GC_I_GUI_ROW3, 58, 25)
	If $g_h_CampaignLabel Then GUICtrlSetPos($g_h_CampaignLabel, $GC_I_GUI_INNER, 60, $GC_I_GUI_CAMPAIGN_LABEL_WIDTH, 18)
	If $g_h_TargetCombo Then GUICtrlSetPos($g_h_TargetCombo, $g_i_CampaignComboLeft, $GC_I_GUI_ROW2, $g_i_CampaignComboWidth, 25)
	If $g_h_StatusLabel Then GUICtrlSetPos($g_h_StatusLabel, $GC_I_GUI_INNER, $GC_I_GUI_STATUS_TOP, $iInnerWidth, 22)
	If $g_h_EditText Then _WinAPI_MoveWindow($g_h_EditText, $GC_I_GUI_MARGIN, $GC_I_GUI_CONSOLE_TOP, $g_i_GuiContentWidth, $GC_I_GUI_CONSOLE_HEIGHT, True)
EndFunc

Func _BotHook_OnSetRunningUi($a_b_Running)
	If $a_b_Running Then HeroTeam_OnSetRunningUi()
EndFunc

Func _BotHook_OnSetIdleUiState()
	HeroTeam_OnSetIdleUiState()
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
			GUICtrlSendMsg($g_h_NameCombo, $CB_SETDROPPEDWIDTH, $g_i_HeroDropdownWidth, 0)
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

Func _Exit()
	$g_b_StopRequested = True
	$g_b_BotRunning = False
	Exit
EndFunc
