#include-once

; Hero team configuration and automatic party setup for Vanquish Bot.

Global Const $GC_S_HERO_CONFIG = @ScriptDir & "\vanquish_config.ini"

Global Enum $HERO_Norgu = 1, $HERO_Goren, $HERO_Tahlkora, $HERO_MasterOfWhispers, $HERO_AcolyteJin, $HERO_Koss, $HERO_Dunkoro, $HERO_AcolyteSousuke, $HERO_Melonni, _
		$HERO_ZhedShadowhoof, $HERO_GeneralMorgahn, $HERO_MargridTheSly, $HERO_Olias = 14, $HERO_Razah, $HERO_MOX, $HERO_Jora = 18, $HERO_PyreFierceshot, _
		$HERO_Livia = 21, $HERO_Hayda, $HERO_Kahmu, $HERO_Gwen, $HERO_Xandra, $HERO_Vekk, $HERO_Ogden
Global Enum $HERO_MercenaryHero1 = 28, $HERO_MercenaryHero2 = 29, $HERO_MercenaryHero3 = 30, $HERO_MercenaryHero4 = 31, $HERO_MercenaryHero5 = 32, $HERO_MercenaryHero6 = 33, $HERO_MercenaryHero7 = 34, $HERO_MercenaryHero8 = 35

Global Const $GC_A_HERO_NAMES[] = [ _
	"Norgu", "Goren", "Tahlkora", "Master of Whispers", "Acolyte Jin", "Koss", "Dunkoro", "Acolyte Sousuke", "Melonni", _
	"Zhed Shadowhoof", "General Morgahn", "Margrid The Sly", "Olias", "Razah", "MOX", "Jora", "Pyre Fierceshot", _
	"Livia", "Hayda", "Kahmu", "Gwen", "Xandra", "Vekk", "Ogden", _
	"Mercenary Hero 1", "Mercenary Hero 2", "Mercenary Hero 3", "Mercenary Hero 4", "Mercenary Hero 5", "Mercenary Hero 6", "Mercenary Hero 7", "Mercenary Hero 8"]

Global Const $GC_A_HERO_IDS[] = [ _
	$HERO_Norgu, $HERO_Goren, $HERO_Tahlkora, $HERO_MasterOfWhispers, $HERO_AcolyteJin, $HERO_Koss, $HERO_Dunkoro, $HERO_AcolyteSousuke, $HERO_Melonni, _
	$HERO_ZhedShadowhoof, $HERO_GeneralMorgahn, $HERO_MargridTheSly, $HERO_Olias, $HERO_Razah, $HERO_MOX, $HERO_Jora, $HERO_PyreFierceshot, _
	$HERO_Livia, $HERO_Hayda, $HERO_Kahmu, $HERO_Gwen, $HERO_Xandra, $HERO_Vekk, $HERO_Ogden, _
	$HERO_MercenaryHero1, $HERO_MercenaryHero2, $HERO_MercenaryHero3, $HERO_MercenaryHero4, $HERO_MercenaryHero5, $HERO_MercenaryHero6, $HERO_MercenaryHero7, $HERO_MercenaryHero8]

Global $g_s_HeroList = ""
Global $g_i_HeroDropdownWidth = 160
Global Const $GC_S_WIDEST_CHAR_NAME = "Masters of Whispers"
Global Const $GC_I_HERO_COMBO_EXTRA_CHARS = 2
Global Const $GC_I_HERO_TEAM4_SLOTS = 3
Global Const $GC_I_HERO_TEAM6_SLOTS = 5
Global Const $GC_I_HERO_TEAM8_SLOTS = 7
Global $g_idComboTeam4[3]
Global $g_idComboTeam6[5]
Global $g_idComboTeam8[7]
Global $g_sLastHeroTeamState = ""
Global Const $GC_I_HERO_LABEL_WIDTH = 22
Global Const $GC_I_HERO_GROUP_PAD = 8
Global Const $GC_I_HERO_TOP_ROW_HEIGHT = 132
Global Const $GC_I_HERO_TEAM8_HEIGHT = 108
Global Const $GC_I_HERO_TEAM_GAP = 8
Global Const $GC_I_HERO_ROW_HEIGHT = 22

Global $g_h_Team4Group = 0
Global $g_h_Team6Group = 0
Global $g_h_Team8Group = 0
Global $g_aTeam4LabelIds[3]
Global $g_aTeam6LabelIds[5]
Global $g_aTeam8LabelIds[7]
Global $g_i_HeroListTop = 0
Global $g_b_HeroGuiCreated = False

Func HeroTeam_Init()
	$g_s_HeroList = HeroTeam_BuildList()
	$g_i_HeroDropdownWidth = HeroTeam_EstimateDropdownWidth()
EndFunc

Func HeroTeam_BuildList()
	Local $l_s = ""
	Local $i
	For $i = 0 To UBound($GC_A_HERO_NAMES) - 1
		If $l_s <> "" Then $l_s &= "|"
		$l_s &= $GC_A_HERO_NAMES[$i]
	Next
	Return $l_s
EndFunc

Func HeroTeam_ComboExtraWidth()
	Return $GC_I_HERO_COMBO_EXTRA_CHARS * 8
EndFunc

Func HeroTeam_EstimateDropdownWidth()
	Return CaravanGui_EstimateComboWidth($GC_S_WIDEST_CHAR_NAME) + HeroTeam_ComboExtraWidth()
EndFunc

Func HeroTeam_ApplyMeasuredDropdownWidth($a_h_MeasureCtrl)
	Local $l_i_W = CaravanGui_ComboWidthForText($a_h_MeasureCtrl, $GC_S_WIDEST_CHAR_NAME) + HeroTeam_ComboExtraWidth()
	If $l_i_W > 0 Then $g_i_HeroDropdownWidth = $l_i_W
	Return $g_i_HeroDropdownWidth
EndFunc

Func HeroTeam_GroupWidth()
	Return $GC_I_HERO_GROUP_PAD + $GC_I_HERO_LABEL_WIDTH + $g_i_HeroDropdownWidth + $GC_I_HERO_GROUP_PAD
EndFunc

Func HeroTeam_GetIdByName($a_s_Name)
	Local $s = StringStripWS($a_s_Name, 3)
	If $s = "" Then Return 0
	Local $i
	For $i = 0 To UBound($GC_A_HERO_NAMES) - 1
		If StringCompare($GC_A_HERO_NAMES[$i], $s, 1) = 0 Then Return $GC_A_HERO_IDS[$i]
	Next
	Return 0
EndFunc

Func HeroTeam_PanelLeft($a_i_ListLeft, $a_i_ListWidth)
	Return $a_i_ListLeft + $a_i_ListWidth + 8
EndFunc

Func HeroTeam_PanelWidth()
	Return HeroTeam_GroupWidth() * 2 + $GC_I_HERO_TEAM_GAP
EndFunc

Func HeroTeam_SlotLabelX($a_i_GroupX)
	Return $a_i_GroupX + $GC_I_HERO_GROUP_PAD
EndFunc

Func HeroTeam_SlotComboX($a_i_GroupX)
	Return HeroTeam_SlotLabelX($a_i_GroupX) + $GC_I_HERO_LABEL_WIDTH
EndFunc

Func HeroTeam_SlotComboY($a_i_GroupY, $a_i_Index)
	Return $a_i_GroupY + 16 + ($a_i_Index * $GC_I_HERO_ROW_HEIGHT)
EndFunc

Func HeroTeam_SlotLabelY($a_i_GroupY, $a_i_Index)
	Return HeroTeam_SlotComboY($a_i_GroupY, $a_i_Index) + 3
EndFunc

Func HeroTeam_PlaceSlot($a_id_Label, $a_id_Combo, $a_i_GroupX, $a_i_GroupY, $a_i_Index)
	If $a_id_Label <> 0 Then GUICtrlSetPos($a_id_Label, HeroTeam_SlotLabelX($a_i_GroupX), HeroTeam_SlotLabelY($a_i_GroupY, $a_i_Index), $GC_I_HERO_LABEL_WIDTH, 16)
	If $a_id_Combo <> 0 Then
		GUICtrlSetPos($a_id_Combo, HeroTeam_SlotComboX($a_i_GroupX), HeroTeam_SlotComboY($a_i_GroupY, $a_i_Index), $g_i_HeroDropdownWidth, 22)
		GUICtrlSendMsg($a_id_Combo, $CB_SETDROPPEDWIDTH, $g_i_HeroDropdownWidth, 0)
	EndIf
EndFunc

Func HeroTeam_MarkPartySize(ByRef $a_a_Sizes, $a_i_Size)
	Local $i
	For $i = 0 To UBound($a_a_Sizes) - 1
		If $a_a_Sizes[$i] = $a_i_Size Then Return
	Next
	Local $l_i_Next = UBound($a_a_Sizes)
	ReDim $a_a_Sizes[$l_i_Next + 1]
	$a_a_Sizes[$l_i_Next] = $a_i_Size
EndFunc

Func HeroTeam_ValidateTeamSlots($a_i_PartySize)
	Local $l_i_Slots = 0
	Local $aComboIDs
	Switch $a_i_PartySize
		Case 4
			$l_i_Slots = $GC_I_HERO_TEAM4_SLOTS
			$aComboIDs = $g_idComboTeam4
		Case 6
			$l_i_Slots = $GC_I_HERO_TEAM6_SLOTS
			$aComboIDs = $g_idComboTeam6
		Case 8
			$l_i_Slots = $GC_I_HERO_TEAM8_SLOTS
			$aComboIDs = $g_idComboTeam8
		Case Else
			Return ""
	EndSwitch

	Local $l_s_Seen = "|"
	Local $i
	For $i = 0 To $l_i_Slots - 1
		Local $l_s_Name = StringStripWS(GUICtrlRead($aComboIDs[$i]), 3)
		If $l_s_Name = "" Then Return "Team " & $a_i_PartySize & ": hero slot H" & ($i + 1) & " is empty."
		If HeroTeam_GetIdByName($l_s_Name) <= 0 Then Return "Team " & $a_i_PartySize & ": unknown hero '" & $l_s_Name & "'."
		If StringInStr($l_s_Seen, "|" & $l_s_Name & "|") Then Return "Team " & $a_i_PartySize & ": duplicate hero '" & $l_s_Name & "'."
		$l_s_Seen &= $l_s_Name & "|"
	Next
	Return ""
EndFunc

Func HeroTeam_ValidatePartySizes(ByRef $a_a_Sizes)
	If UBound($a_a_Sizes) < 1 Then Return ""
	Local $i
	For $i = 0 To UBound($a_a_Sizes) - 1
		Local $l_s_Err = HeroTeam_ValidateTeamSlots($a_a_Sizes[$i])
		If $l_s_Err <> "" Then Return $l_s_Err
	Next
	Return ""
EndFunc

Func HeroTeam_ValidateBeforeRun($a_s_Target)
	If Not $g_b_HeroGuiCreated Then Return "Hero team controls are not ready."

	If MapCatalog_IsCurrentMapSelection($a_s_Target) Then
		If Not $g_b_BotCoreInitialized Then Return "Connect to Guild Wars before running on the current map."
		Local $l_i_Size = HeroTeam_ResolvePartySize()
		Return HeroTeam_ValidateTeamSlots($l_i_Size)
	EndIf

	If MapCatalog_IsSequenceSelection($a_s_Target) Then
		CaravanPlan_SetKind(MapCatalog_GetSequenceKind($a_s_Target))
		Local $l_s_SelectedMaps = CaravanGui_GetSelectedTitles()
		If $l_s_SelectedMaps = "" Then Return ""
		CaravanPlan_SetFarmFromTitles($l_s_SelectedMaps)
		Local $l_a_Sizes[0]
		Local $l_i_VisitCount = CaravanPlan_VisitCount()
		Local $j
		For $j = 0 To $l_i_VisitCount - 1
			Local $l_i_Stage = CaravanPlan_VisitStage($j)
			If Not CaravanPlan_ShouldFarm($l_i_Stage) Then ContinueLoop
			Local $l_i_Map = CaravanPlan_MapID($l_i_Stage)
			Local $l_i_Out = CaravanPlan_OutpostID($l_i_Stage)
			HeroTeam_MarkPartySize($l_a_Sizes, HeroTeam_ResolvePartySize($l_i_Map, $l_i_Out))
		Next
		Return HeroTeam_ValidatePartySizes($l_a_Sizes)
	EndIf

	If MapCatalog_IsRegionSelection($a_s_Target) Then
		Local $l_s_RegionMaps = CaravanGui_GetSelectedTitles()
		If $l_s_RegionMaps = "" Then Return "No maps selected in the map list."
		If $l_s_RegionMaps = "*" Then $l_s_RegionMaps = MapCatalog_GetRegionTitles($a_s_Target)
		Local $l_a_RegionParts = StringSplit($l_s_RegionMaps, "|")
		Local $l_a_RegionSizes[0]
		Local $k
		If IsArray($l_a_RegionParts) Then
			For $k = 1 To $l_a_RegionParts[0]
				Local $l_s_RegionTitle = StringStripWS($l_a_RegionParts[$k], 3)
				If $l_s_RegionTitle = "" Then ContinueLoop
				Local $l_i_RegionMap = MapCatalog_GetMapID($l_s_RegionTitle)
				Local $l_i_RegionOut = MapCatalog_GetOutpostID($l_s_RegionTitle)
				HeroTeam_MarkPartySize($l_a_RegionSizes, HeroTeam_ResolvePartySize($l_i_RegionMap, $l_i_RegionOut))
			Next
		EndIf
		Return HeroTeam_ValidatePartySizes($l_a_RegionSizes)
	EndIf

	Local $l_i_Map = MapCatalog_GetMapID($a_s_Target)
	Local $l_i_Out = MapCatalog_GetOutpostID($a_s_Target)
	Return HeroTeam_ValidateTeamSlots(HeroTeam_ResolvePartySize($l_i_Map, $l_i_Out))
EndFunc

Func HeroTeam_SaveConfig()
	Local $i
	For $i = 0 To $GC_I_HERO_TEAM4_SLOTS - 1
		IniWrite($GC_S_HERO_CONFIG, "Team4", "Hero" & ($i + 1), StringStripWS(GUICtrlRead($g_idComboTeam4[$i]), 3))
	Next
	For $i = 0 To $GC_I_HERO_TEAM6_SLOTS - 1
		IniWrite($GC_S_HERO_CONFIG, "Team6", "Hero" & ($i + 1), StringStripWS(GUICtrlRead($g_idComboTeam6[$i]), 3))
	Next
	For $i = 0 To $GC_I_HERO_TEAM8_SLOTS - 1
		IniWrite($GC_S_HERO_CONFIG, "Team8", "Hero" & ($i + 1), StringStripWS(GUICtrlRead($g_idComboTeam8[$i]), 3))
	Next
EndFunc

Func HeroTeam_LoadConfig()
	Local $i
	For $i = 0 To $GC_I_HERO_TEAM4_SLOTS - 1
		Local $l_s_Value = IniRead($GC_S_HERO_CONFIG, "Team4", "Hero" & ($i + 1), "")
		Local $l_s_Name = HeroTeam_ResolveSavedName($l_s_Value)
		If $l_s_Name <> "" Then GUICtrlSetData($g_idComboTeam4[$i], "|" & $g_s_HeroList, $l_s_Name)
	Next
	For $i = 0 To $GC_I_HERO_TEAM6_SLOTS - 1
		Local $l_s_Value = IniRead($GC_S_HERO_CONFIG, "Team6", "Hero" & ($i + 1), "")
		Local $l_s_Name = HeroTeam_ResolveSavedName($l_s_Value)
		If $l_s_Name <> "" Then GUICtrlSetData($g_idComboTeam6[$i], "|" & $g_s_HeroList, $l_s_Name)
	Next
	For $i = 0 To $GC_I_HERO_TEAM8_SLOTS - 1
		Local $l_s_Value = IniRead($GC_S_HERO_CONFIG, "Team8", "Hero" & ($i + 1), "")
		Local $l_s_Name = HeroTeam_ResolveSavedName($l_s_Value)
		If $l_s_Name <> "" Then GUICtrlSetData($g_idComboTeam8[$i], "|" & $g_s_HeroList, $l_s_Name)
	Next
EndFunc

Func HeroTeam_ResolveSavedName($a_s_Value)
	Local $s = StringStripWS($a_s_Value, 3)
	If $s = "" Then Return ""
	If StringIsDigit($s) Then
		Local $iIndex = Number($s)
		Local $iArrayIndex = $iIndex - 1
		If $iIndex >= 1 And $iArrayIndex >= 0 And $iArrayIndex < UBound($GC_A_HERO_NAMES) Then Return $GC_A_HERO_NAMES[$iArrayIndex]
	EndIf
	If HeroTeam_GetIdByName($s) > 0 Then Return $s
	Return ""
EndFunc

Func HeroTeam_GetArrayForPartySize($a_i_MaxPartySize)
	Local $l_i_HeroSlots = 0
	Local $aComboIDs
	Switch $a_i_MaxPartySize
		Case 4
			$l_i_HeroSlots = 3
			$aComboIDs = $g_idComboTeam4
		Case 6
			$l_i_HeroSlots = 5
			$aComboIDs = $g_idComboTeam6
		Case 8
			$l_i_HeroSlots = 7
			$aComboIDs = $g_idComboTeam8
		Case Else
			Local $l_a_Empty[0]
			Return $l_a_Empty
	EndSwitch

	Local $aHeroIDs[7]
	Local $iOut = 0
	Local $i
	For $i = 0 To $l_i_HeroSlots - 1
		Local $l_s_Name = StringStripWS(GUICtrlRead($aComboIDs[$i]), 3)
		If $l_s_Name = "" Then ContinueLoop
		Local $l_i_Id = HeroTeam_GetIdByName($l_s_Name)
		If $l_i_Id <= 0 Then ContinueLoop
		$aHeroIDs[$iOut] = $l_i_Id
		$iOut += 1
	Next
	If $iOut < 1 Then
		Local $l_a_Empty[0]
		Return $l_a_Empty
	EndIf
	ReDim $aHeroIDs[$iOut - 1]
	Return $aHeroIDs
EndFunc

Func HeroTeam_IsActive(ByRef $a_a_HeroIDs)
	If Not IsArray($a_a_HeroIDs) Then Return False
	If Party_GetMyPartyInfo("ArrayPlayerPartyMemberSize") <> 1 Then Return False
	If Party_GetMyPartyInfo("ArrayHenchmanPartyMemberSize") <> 0 Then Return False
	If Party_GetHeroCount() <> UBound($a_a_HeroIDs) Then Return False
	Local $i
	For $i = 0 To UBound($a_a_HeroIDs) - 1
		If Party_GetHeroID($i + 1) <> $a_a_HeroIDs[$i] Then Return False
	Next
	Return True
EndFunc

Func HeroTeam_ResolvePartySize($a_i_MapId = 0, $a_i_OutpostId = 0)
	Local $l_i_PartySize = 0
	If $a_i_MapId > 0 Then
		$l_i_PartySize = Map_GetAreaInfo($a_i_MapId, "MaxPartySize")
		If $l_i_PartySize <= 0 And $a_i_OutpostId > 0 Then
			$l_i_PartySize = Map_GetAreaInfo($a_i_OutpostId, "MaxPartySize")
		EndIf
	Else
		$l_i_PartySize = Map_GetCurrentAreaInfo("MaxPartySize")
	EndIf
	If $l_i_PartySize <= 0 Then Return 8
	If $l_i_PartySize <= 4 Then Return 4
	If $l_i_PartySize <= 6 Then Return 6
	Return 8
EndFunc

Func HeroTeam_SetupForPartySize($a_i_MaxPartySize)
	If Not $g_b_BotCoreInitialized Then
		Out("Cannot set up heroes before connecting to Guild Wars.")
		Return False
	EndIf
	If $a_i_MaxPartySize <> 4 And $a_i_MaxPartySize <> 6 And $a_i_MaxPartySize <> 8 Then
		Out("Unsupported party size for hero setup: " & $a_i_MaxPartySize)
		Return False
	EndIf

	Local $aHeroIDs = HeroTeam_GetArrayForPartySize($a_i_MaxPartySize)
	If UBound($aHeroIDs) < 1 Then
		Out("No heroes configured for Team " & $a_i_MaxPartySize & ".")
		Return False
	EndIf
	If HeroTeam_IsActive($aHeroIDs) Then Return True

	Ui_LeaveGroup()
	Sleep(250)
	Local $i
	For $i = 0 To UBound($aHeroIDs) - 1
		Ui_AddHero($aHeroIDs[$i])
		Sleep(250)
	Next
	Out("Hero team " & $a_i_MaxPartySize & " ready (" & UBound($aHeroIDs) & " heroes).")
	Return True
EndFunc

Func HeroTeam_SetupForTitle($a_s_Title)
	Local $l_i_Map = MapCatalog_GetMapID($a_s_Title)
	Local $l_i_Out = MapCatalog_GetOutpostID($a_s_Title)
	Local $l_i_Size = HeroTeam_ResolvePartySize($l_i_Map, $l_i_Out)
	Return HeroTeam_SetupForPartySize($l_i_Size)
EndFunc

Func HeroTeam_SetComboArrayState(ByRef $a_a_ComboIDs, $a_i_State, $a_i_Count)
	Local $i
	For $i = 0 To $a_i_Count - 1
		GUICtrlSetState($a_a_ComboIDs[$i], $a_i_State)
	Next
EndFunc

Func HeroTeam_RefreshSelectionState($a_i_PartySize = 0)
	Local $l_s_StateKey = "all"
	If $a_i_PartySize = 4 Then
		$l_s_StateKey = "4"
	ElseIf $a_i_PartySize = 6 Then
		$l_s_StateKey = "6"
	ElseIf $a_i_PartySize = 8 Then
		$l_s_StateKey = "8"
	EndIf
	If $l_s_StateKey = $g_sLastHeroTeamState Then Return
	$g_sLastHeroTeamState = $l_s_StateKey

	Switch $l_s_StateKey
		Case "4"
			HeroTeam_SetComboArrayState($g_idComboTeam4, $GUI_ENABLE, $GC_I_HERO_TEAM4_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam6, $GUI_DISABLE, $GC_I_HERO_TEAM6_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam8, $GUI_DISABLE, $GC_I_HERO_TEAM8_SLOTS)
		Case "6"
			HeroTeam_SetComboArrayState($g_idComboTeam4, $GUI_DISABLE, $GC_I_HERO_TEAM4_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam6, $GUI_ENABLE, $GC_I_HERO_TEAM6_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam8, $GUI_DISABLE, $GC_I_HERO_TEAM8_SLOTS)
		Case "8"
			HeroTeam_SetComboArrayState($g_idComboTeam4, $GUI_DISABLE, $GC_I_HERO_TEAM4_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam6, $GUI_DISABLE, $GC_I_HERO_TEAM6_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam8, $GUI_ENABLE, $GC_I_HERO_TEAM8_SLOTS)
		Case Else
			HeroTeam_SetComboArrayState($g_idComboTeam4, $GUI_ENABLE, $GC_I_HERO_TEAM4_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam6, $GUI_ENABLE, $GC_I_HERO_TEAM6_SLOTS)
			HeroTeam_SetComboArrayState($g_idComboTeam8, $GUI_ENABLE, $GC_I_HERO_TEAM8_SLOTS)
	EndSwitch
EndFunc

Func HeroTeam_RepositionLayout($a_i_ListLeft, $a_i_ListTop, $a_i_ListWidth)
	If Not $g_b_HeroGuiCreated Then Return
	Local $iGroupW = HeroTeam_GroupWidth()
	Local $iTeam4X = HeroTeam_PanelLeft($a_i_ListLeft, $a_i_ListWidth)
	Local $iTeam6X = $iTeam4X + $iGroupW + $GC_I_HERO_TEAM_GAP
	Local $iTeam8X = $iTeam4X
	Local $iTeam8Top = $a_i_ListTop + $GC_I_HERO_TOP_ROW_HEIGHT + $GC_I_HERO_TEAM_GAP
	Local $iTeam8Width = HeroTeam_PanelWidth()
	Local $i, $iColX, $iRow

	If $g_h_Team4Group Then GUICtrlSetPos($g_h_Team4Group, $iTeam4X, $a_i_ListTop, $iGroupW, $GC_I_HERO_TOP_ROW_HEIGHT)
	If $g_h_Team6Group Then GUICtrlSetPos($g_h_Team6Group, $iTeam6X, $a_i_ListTop, $iGroupW, $GC_I_HERO_TOP_ROW_HEIGHT)
	If $g_h_Team8Group Then GUICtrlSetPos($g_h_Team8Group, $iTeam8X, $iTeam8Top, $iTeam8Width, $GC_I_HERO_TEAM8_HEIGHT)

	For $i = 0 To $GC_I_HERO_TEAM4_SLOTS - 1
		HeroTeam_PlaceSlot($g_aTeam4LabelIds[$i], $g_idComboTeam4[$i], $iTeam4X, $a_i_ListTop, $i)
	Next
	For $i = 0 To $GC_I_HERO_TEAM6_SLOTS - 1
		HeroTeam_PlaceSlot($g_aTeam6LabelIds[$i], $g_idComboTeam6[$i], $iTeam6X, $a_i_ListTop, $i)
	Next
	For $i = 0 To $GC_I_HERO_TEAM8_SLOTS - 1
		$iColX = $iTeam4X
		$iRow = $i
		If $i >= 4 Then
			$iColX = $iTeam6X
			$iRow = $i - 4
		EndIf
		HeroTeam_PlaceSlot($g_aTeam8LabelIds[$i], $g_idComboTeam8[$i], $iColX, $iTeam8Top, $iRow)
	Next
EndFunc

Func HeroTeam_RepositionTopRow($a_i_ListLeft, $a_i_ListTop, $a_i_ListWidth)
	HeroTeam_RepositionLayout($a_i_ListLeft, $a_i_ListTop, $a_i_ListWidth)
EndFunc

Func HeroTeam_CreateGuiControls($a_i_ListLeft, $a_i_ListTop, $a_i_ListWidth, $a_i_InnerLeft, $a_i_InnerWidth)
	#forceref $a_i_InnerLeft, $a_i_InnerWidth
	Local $i
	$g_i_HeroListTop = $a_i_ListTop

	Local $iGroupW = HeroTeam_GroupWidth()
	$g_h_Team4Group = GUICtrlCreateGroup("Team 4", 0, 0, $iGroupW, $GC_I_HERO_TOP_ROW_HEIGHT)
	For $i = 0 To $GC_I_HERO_TEAM4_SLOTS - 1
		$g_aTeam4LabelIds[$i] = GUICtrlCreateLabel("H" & ($i + 1) & ":", 0, 0, $GC_I_HERO_LABEL_WIDTH, 16)
		$g_idComboTeam4[$i] = GUICtrlCreateCombo("", 0, 0, $g_i_HeroDropdownWidth, 22, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
		GUICtrlSetData($g_idComboTeam4[$i], $g_s_HeroList)
		GUICtrlSendMsg($g_idComboTeam4[$i], $CB_SETDROPPEDWIDTH, $g_i_HeroDropdownWidth, 0)
	Next
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	$g_h_Team6Group = GUICtrlCreateGroup("Team 6", 0, 0, $iGroupW, $GC_I_HERO_TOP_ROW_HEIGHT)
	For $i = 0 To $GC_I_HERO_TEAM6_SLOTS - 1
		$g_aTeam6LabelIds[$i] = GUICtrlCreateLabel("H" & ($i + 1) & ":", 0, 0, $GC_I_HERO_LABEL_WIDTH, 16)
		$g_idComboTeam6[$i] = GUICtrlCreateCombo("", 0, 0, $g_i_HeroDropdownWidth, 22, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
		GUICtrlSetData($g_idComboTeam6[$i], $g_s_HeroList)
		GUICtrlSendMsg($g_idComboTeam6[$i], $CB_SETDROPPEDWIDTH, $g_i_HeroDropdownWidth, 0)
	Next
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	$g_h_Team8Group = GUICtrlCreateGroup("Team 8", 0, 0, HeroTeam_PanelWidth(), $GC_I_HERO_TEAM8_HEIGHT)
	For $i = 0 To $GC_I_HERO_TEAM8_SLOTS - 1
		$g_aTeam8LabelIds[$i] = GUICtrlCreateLabel("H" & ($i + 1) & ":", 0, 0, $GC_I_HERO_LABEL_WIDTH, 16)
		$g_idComboTeam8[$i] = GUICtrlCreateCombo("", 0, 0, $g_i_HeroDropdownWidth, 22, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
		GUICtrlSetData($g_idComboTeam8[$i], $g_s_HeroList)
		GUICtrlSendMsg($g_idComboTeam8[$i], $CB_SETDROPPEDWIDTH, $g_i_HeroDropdownWidth, 0)
	Next
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	$g_b_HeroGuiCreated = True
	HeroTeam_RepositionLayout($a_i_ListLeft, $a_i_ListTop, $a_i_ListWidth)
EndFunc

Func HeroTeam_OnSetIdleUiState()
	If Not $g_b_BotRunning Then HeroTeam_RefreshSelectionState(0)
EndFunc

Func HeroTeam_OnSetRunningUi()
	HeroTeam_RefreshSelectionState(0)
EndFunc
