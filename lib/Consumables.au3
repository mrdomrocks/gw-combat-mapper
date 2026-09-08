#include-once
#include "LootPickup.au3"

; Optional run-start consumables and Bird's Eye Compass support.
; Compass/Rations model IDs come from LootPickup.au3 ($GC_I_MODELID_*).

Global $g_b_ConsumablesEnabled = False
Global $g_b_UseCompass = False
Global $g_b_UseConset = False
Global $g_b_UseHoneycombs = False
Global $g_b_UseStones = False

Func Consumables_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_ConsumablesEnabled = Number(IniRead($a_s_ConfigPath, "Consumables", "Enabled", "0")) <> 0
	$g_b_UseCompass = Number(IniRead($a_s_ConfigPath, "Consumables", "BirdsEyeCompass", "0")) <> 0
	$g_b_UseConset = Number(IniRead($a_s_ConfigPath, "Consumables", "Conset", "0")) <> 0
	$g_b_UseHoneycombs = Number(IniRead($a_s_ConfigPath, "Consumables", "Honeycombs", "0")) <> 0
	$g_b_UseStones = Number(IniRead($a_s_ConfigPath, "Consumables", "SummoningStones", "0")) <> 0
EndFunc

Func Consumables_FindInInventory($a_i_ModelID)
	Local $l_a_Bags = Item_GetBagsArray()
	If Not IsArray($l_a_Bags) Then Return 0
	Local $i, $j
	For $i = 1 To $l_a_Bags[0]
		Local $l_i_Bag = $l_a_Bags[$i]
		Local $l_a_Items = Item_GetItemsInBag($l_i_Bag)
		If Not IsArray($l_a_Items) Then ContinueLoop
		For $j = 1 To $l_a_Items[0]
			Local $l_p_Item = $l_a_Items[$j]
			If $l_p_Item = 0 Then ContinueLoop
			If Item_GetItemInfoByPtr($l_p_Item, "ModelID") = $a_i_ModelID Then
				Return Item_GetItemInfoByPtr($l_p_Item, "AgentID")
			EndIf
		Next
	Next
	Return 0
EndFunc

Func Consumables_UseItemByModel($a_i_ModelID, $a_s_Label)
	Local $l_i_Agent = Consumables_FindInInventory($a_i_ModelID)
	If $l_i_Agent <= 0 Then Return False
	Item_UseItem($l_i_Agent)
	Out("Consumable: used " & $a_s_Label)
	Sleep(750)
	Return True
EndFunc

Func Consumables_ApplyAtRunStart()
	If Not $g_b_ConsumablesEnabled Then Return
	Consumables_LoadConfig()

	If $g_b_UseCompass Then
		If Consumables_UseItemByModel($GC_I_MODELID_COMPASS, "Bird's Eye Compass") Then Sleep(500)
	EndIf
	If $g_b_UseConset Then
		; Conset model varies; attempt common IDs used in MVR
		If Not Consumables_UseItemByModel(5589, "Conset") Then Consumables_UseItemByModel(10296, "Conset")
	EndIf
	If $g_b_UseHoneycombs Then
		Consumables_UseItemByModel(24892, "Honeycomb")
		Consumables_UseItemByModel(24892, "Honeycomb")
	EndIf
	If $g_b_UseStones Then
		Consumables_UseItemByModel(30847, "Summoning Stone")
	EndIf
EndFunc
