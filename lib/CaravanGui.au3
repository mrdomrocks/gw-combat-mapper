#include-once

; Shared map list GUI helpers (Combat Mapper + Vanquish Bot).
; Ascalon/Maguuma sequences fill from the caravan spine; region targets fill
; from the matching lib/maps/Vanquish folder.

Global $g_s_CaravanListKind = ""

Func CaravanGui_IniKey($a_s_Kind = "")
	If $a_s_Kind = "" Then $a_s_Kind = $g_s_CaravanListKind
	Switch $a_s_Kind
		Case "Maguuma"
			Return "CaravanMapsMaguuma"
		Case "Ascalon"
			Return "CaravanMapsAscalon"
	EndSwitch
	If $a_s_Kind = "" Then Return "CaravanMapsAscalon"
	Return "MapList_" & $a_s_Kind
EndFunc

Func CaravanGui_Refresh()
	Local $l_s_Target = GUICtrlRead($g_h_TargetCombo)
	Local $l_s_Kind = MapCatalog_GetSequenceKind($l_s_Target)
	Local $l_s_Region = MapCatalog_GetRegionKey($l_s_Target)
	Local $l_i_Show = $GUI_HIDE
	If $l_s_Kind <> "" Or $l_s_Region <> "" Then $l_i_Show = $GUI_SHOW
	GUICtrlSetState($g_h_CaravanMapList, $l_i_Show)
	GUICtrlSetState($g_h_CaravanAllButton, $l_i_Show)
	GUICtrlSetState($g_h_CaravanNoneButton, $l_i_Show)
	GUICtrlSetState($g_h_SkipVanquishedCheckbox, $l_i_Show)
	GUICtrlSetState($g_h_CaravanMapsLabel, $l_i_Show)
	GUICtrlSetState($g_h_CaravanHintLabel, $l_i_Show)

	If $l_s_Kind <> "" Then
		$g_s_CaravanListKind = $l_s_Kind
		GUICtrlSetData($g_h_CaravanMapsLabel, "Map List (Ctrl+click):")
		GUICtrlSetData($g_h_CaravanHintLabel, "Selected maps are farmed; unselected maps are portal transit only.")
	ElseIf $l_s_Region <> "" Then
		$g_s_CaravanListKind = $l_s_Region
		GUICtrlSetData($g_h_CaravanMapsLabel, "Map List (Ctrl+click):")
		GUICtrlSetData($g_h_CaravanHintLabel, "Selected maps are farmed; unselected maps are skipped.")
	Else
		$g_s_CaravanListKind = ""
		Return
	EndIf

	_GUICtrlListBox_BeginUpdate($g_h_CaravanMapList)
	_GUICtrlListBox_ResetContent($g_h_CaravanMapList)
	If $l_s_Kind <> "" Then
		CaravanPlan_SetKind($l_s_Kind)
		Local $i
		Local $l_i_Count = CaravanPlan_Count()
		For $i = 0 To $l_i_Count - 1
			_GUICtrlListBox_AddString($g_h_CaravanMapList, CaravanPlan_Title($i))
		Next
	Else
		Local $l_s_Pipe = MapCatalog_GetRegionTitles($l_s_Target)
		Local $l_a_Parts = StringSplit($l_s_Pipe, "|")
		Local $j
		If IsArray($l_a_Parts) Then
			For $j = 1 To $l_a_Parts[0]
				Local $l_s_Title = StringStripWS($l_a_Parts[$j], 3)
				If $l_s_Title <> "" Then _GUICtrlListBox_AddString($g_h_CaravanMapList, $l_s_Title)
			Next
		EndIf
	EndIf
	_GUICtrlListBox_EndUpdate($g_h_CaravanMapList)

	Local $l_s_Saved = IniRead($GC_S_CONFIG, "Travel", CaravanGui_IniKey(), "*")
	CaravanGui_ApplySavedSelection($l_s_Saved)
EndFunc

Func CaravanGui_ApplySavedSelection($a_s_Saved)
	Local $l_i_Count = _GUICtrlListBox_GetCount($g_h_CaravanMapList)
	If $l_i_Count < 1 Then Return
	Local $l_s = StringStripWS(String($a_s_Saved), 3)
	If $l_s = "" Or $l_s = "*" Then
		CaravanGui_SelectAll(True)
		Return
	EndIf
	_GUICtrlListBox_SetSel($g_h_CaravanMapList, -1, False)
	Local $l_a_Parts = StringSplit($l_s, "|")
	Local $i, $j, $l_i_Set = 0
	For $i = 1 To $l_a_Parts[0]
		Local $l_s_Title = StringStripWS($l_a_Parts[$i], 3)
		For $j = 0 To $l_i_Count - 1
			If _GUICtrlListBox_GetText($g_h_CaravanMapList, $j) = $l_s_Title Then
				_GUICtrlListBox_SetSel($g_h_CaravanMapList, $j, True)
				$l_i_Set += 1
				ExitLoop
			EndIf
		Next
	Next
	If $l_i_Set < 1 Then CaravanGui_SelectAll(True)
EndFunc

Func CaravanGui_SelectAll($a_b_Select)
	Local $i
	Local $l_i_Count = _GUICtrlListBox_GetCount($g_h_CaravanMapList)
	_GUICtrlListBox_BeginUpdate($g_h_CaravanMapList)
	For $i = 0 To $l_i_Count - 1
		_GUICtrlListBox_SetSel($g_h_CaravanMapList, $i, $a_b_Select)
	Next
	_GUICtrlListBox_EndUpdate($g_h_CaravanMapList)
	CaravanGui_SaveSelection()
EndFunc

Func CaravanGui_GetSelectedTitles()
	Local $l_i_Count = _GUICtrlListBox_GetCount($g_h_CaravanMapList)
	Local $l_a_Sel = _GUICtrlListBox_GetSelItems($g_h_CaravanMapList)
	If $l_i_Count < 1 Then Return "*"
	If Not IsArray($l_a_Sel) Or $l_a_Sel[0] < 1 Then Return ""
	If $l_a_Sel[0] = $l_i_Count Then Return "*"
	Local $i, $l_s = ""
	For $i = 1 To $l_a_Sel[0]
		Local $l_s_Title = _GUICtrlListBox_GetText($g_h_CaravanMapList, $l_a_Sel[$i])
		If $l_s <> "" Then $l_s &= "|"
		$l_s &= $l_s_Title
	Next
	Return $l_s
EndFunc

Func CaravanGui_SaveSelection()
	If $g_s_CaravanListKind = "" Then Return
	IniWrite($GC_S_CONFIG, "Travel", CaravanGui_IniKey($g_s_CaravanListKind), CaravanGui_GetSelectedTitles())
EndFunc

Func CaravanGui_TextWidth($a_h_Ctrl, $a_s_Text)
	Local $hWnd = GUICtrlGetHandle($a_h_Ctrl)
	If $hWnd = 0 Then Return StringLen($a_s_Text) * 7
	Local $hDC = _WinAPI_GetDC($hWnd)
	Local $hFont = _SendMessage($hWnd, $WM_GETFONT)
	Local $hOldFont = 0
	If $hFont Then $hOldFont = _WinAPI_SelectObject($hDC, $hFont)
	Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, $a_s_Text)
	If $hFont Then _WinAPI_SelectObject($hDC, $hOldFont)
	_WinAPI_ReleaseDC($hWnd, $hDC)
	Return DllStructGetData($tSize, "X")
EndFunc

Func CaravanGui_EstimateComboWidth($a_s_Text)
	Return StringLen($a_s_Text) * 8 + 28
EndFunc

Func CaravanGui_ComboWidthForText($a_h_Ctrl, $a_s_Text)
	Local $l_i_Est = CaravanGui_EstimateComboWidth($a_s_Text)
	If $a_h_Ctrl = 0 Then Return $l_i_Est
	Local $l_i_W = CaravanGui_TextWidth($a_h_Ctrl, $a_s_Text) + 28
	If $l_i_W < 80 Then Return $l_i_Est
	Return $l_i_W
EndFunc

Func CaravanGui_EstimateListWidthFromCatalog()
	Local $l_i_W = StringLen(MapCatalog_GetLongestMapTitle()) * 7 + 28
	If $l_i_W < 160 Then $l_i_W = 160
	Return $l_i_W
EndFunc

Func CaravanGui_MeasureStableListWidth($a_h_Ctrl)
	Local $l_i_W = CaravanGui_TextWidth($a_h_Ctrl, MapCatalog_GetLongestMapTitle()) + 28
	If $l_i_W < 160 Then $l_i_W = 160
	Return $l_i_W
EndFunc

Func CaravanGui_MeasureListWidth($a_i_Padding = 24)
	Local $l_i_Max = 80
	Local $i
	Local $l_i_Count = _GUICtrlListBox_GetCount($g_h_CaravanMapList)
	For $i = 0 To $l_i_Count - 1
		Local $l_s_Title = _GUICtrlListBox_GetText($g_h_CaravanMapList, $i)
		Local $l_i_W = CaravanGui_TextWidth($g_h_CaravanMapList, $l_s_Title)
		If $l_i_W > $l_i_Max Then $l_i_Max = $l_i_W
	Next
	Return $l_i_Max + $a_i_Padding
EndFunc
