#include-once

; Per-MapID coverage AABB presets saved from sweeps or manual Log XY.

Global Const $GC_S_MAPBOUNDS_INI = @ScriptDir & "\map_bounds.ini"

Func MapBounds_LoadForMap($a_i_MapID)
	If $a_i_MapID <= 0 Then Return False
	Local $l_s_Section = "Map_" & $a_i_MapID
	If IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinX", "") = "" Then Return False

	$g_f_CovMinX = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinX", "0"))
	$g_f_CovMaxX = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MaxX", "0"))
	$g_f_CovMinY = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinY", "0"))
	$g_f_CovMaxY = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MaxY", "0"))
	Local $l_f_Step = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "GridStep", "0"))
	If $l_f_Step > 0 Then $g_f_GridStep = $l_f_Step
	Return True
EndFunc

Func MapBounds_SaveForMap($a_i_MapID, $a_f_MinX, $a_f_MaxX, $a_f_MinY, $a_f_MaxY, $a_f_Step = 0)
	If $a_i_MapID <= 0 Then Return False
	Local $l_s_Section = "Map_" & $a_i_MapID
	IniWrite($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinX", Round($a_f_MinX))
	IniWrite($GC_S_MAPBOUNDS_INI, $l_s_Section, "MaxX", Round($a_f_MaxX))
	IniWrite($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinY", Round($a_f_MinY))
	IniWrite($GC_S_MAPBOUNDS_INI, $l_s_Section, "MaxY", Round($a_f_MaxY))
	If $a_f_Step > 0 Then IniWrite($GC_S_MAPBOUNDS_INI, $l_s_Section, "GridStep", Round($a_f_Step))
	Return True
EndFunc

Func MapBounds_UpdateFromPoint($a_i_MapID, $a_f_X, $a_f_Y, $a_f_Pad = 0)
	If $a_i_MapID <= 0 Then Return
	Local $l_s_Section = "Map_" & $a_i_MapID
	Local $l_b_Had = IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinX", "") <> ""

	Local $l_f_MinX, $l_f_MaxX, $l_f_MinY, $l_f_MaxY
	If $l_b_Had Then
		$l_f_MinX = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinX", String($a_f_X - $a_f_Pad)))
		$l_f_MaxX = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MaxX", String($a_f_X + $a_f_Pad)))
		$l_f_MinY = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MinY", String($a_f_Y - $a_f_Pad)))
		$l_f_MaxY = Number(IniRead($GC_S_MAPBOUNDS_INI, $l_s_Section, "MaxY", String($a_f_Y + $a_f_Pad)))
	Else
		$l_f_MinX = $a_f_X - $a_f_Pad
		$l_f_MaxX = $a_f_X + $a_f_Pad
		$l_f_MinY = $a_f_Y - $a_f_Pad
		$l_f_MaxY = $a_f_Y + $a_f_Pad
	EndIf

	If $a_f_X < $l_f_MinX Then $l_f_MinX = $a_f_X
	If $a_f_X > $l_f_MaxX Then $l_f_MaxX = $a_f_X
	If $a_f_Y < $l_f_MinY Then $l_f_MinY = $a_f_Y
	If $a_f_Y > $l_f_MaxY Then $l_f_MaxY = $a_f_Y

	MapBounds_SaveForMap($a_i_MapID, $l_f_MinX, $l_f_MaxX, $l_f_MinY, $l_f_MaxY)
EndFunc

Func MapBounds_ApplyToGui()
	If Not IsDeclared("g_h_MinX") Then Return False
	GUICtrlSetData($g_h_MinX, Round($g_f_CovMinX))
	GUICtrlSetData($g_h_MaxX, Round($g_f_CovMaxX))
	GUICtrlSetData($g_h_MinY, Round($g_f_CovMinY))
	GUICtrlSetData($g_h_MaxY, Round($g_f_CovMaxY))
	If IsDeclared("g_h_GridStep") Then GUICtrlSetData($g_h_GridStep, Round($g_f_GridStep))
	Return True
EndFunc

Func MapBounds_TryAutoLoadCurrent()
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <= 0 Then Return False
	If Not MapBounds_LoadForMap($l_i_Map) Then Return False
	MapBounds_ApplyToGui()
	Out("Loaded saved bounds for MapID=" & $l_i_Map & " (" & Round($g_f_CovMinX) & "," & Round($g_f_CovMinY) & _
		") -> (" & Round($g_f_CovMaxX) & "," & Round($g_f_CovMaxY) & ")")
	Return True
EndFunc

Func MapBounds_SaveCurrentFromGlobals()
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <= 0 Then Return False
	MapBounds_SaveForMap($l_i_Map, $g_f_CovMinX, $g_f_CovMaxX, $g_f_CovMinY, $g_f_CovMaxY, $g_f_GridStep)
	Out("Saved bounds preset for MapID=" & $l_i_Map)
	Return True
EndFunc
