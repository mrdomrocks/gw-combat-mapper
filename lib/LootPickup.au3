#include-once

; Ground loot: gold coins, gold-rarity items, Rations (38613), Compass (38614).
; Runs from Pathfinder CallFunc after combat, and after waypoints / portal fights.

Global Const $GC_I_MODELID_RATIONS = 38613
Global Const $GC_I_MODELID_COMPASS = 38614
Global Const $GC_I_LOOT_GOLD_CAP = 99000

Global $g_b_LootPickupEnabled = True
Global $g_f_LootRange = 1500
Global $g_h_LootLastScan = 0
Global $g_b_StopRequested = False

Func LootPickup_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_LootPickupEnabled = Number(IniRead($a_s_ConfigPath, "Combat", "LootPickup", "1")) <> 0
	$g_f_LootRange = Number(IniRead($a_s_ConfigPath, "Combat", "LootRange", "1500"))
	If $g_f_LootRange <= 0 Then $g_f_LootRange = 1500
EndFunc

Func LootPickup_CanRun()
	If Not $g_b_LootPickupEnabled Then Return False
	If $g_b_StopRequested Then Return False
	If Map_GetInstanceInfo("IsLoading") Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	If Party_GetPartyContextInfo("IsDefeated") Then Return False
	If Agent_GetAgentInfo(-2, "IsDead") Then Return False
	If IsFunc("CombatLogger_IsCombatActive") And CombatLogger_IsCombatActive() Then Return False
	Return True
EndFunc

; Throttled scan for Pathfinder CallFunc (every ~32ms).
Func LootPickup_Tick()
	LootPickup_LoadConfig()
	If Not LootPickup_CanRun() Then Return
	If $g_h_LootLastScan <> 0 And TimerDiff($g_h_LootLastScan) < 250 Then Return
	LootPickup_Sweep()
EndFunc

; Full in-range pickup (after fights / waypoints).
Func LootPickup_Sweep()
	LootPickup_LoadConfig()
	If Not LootPickup_CanRun() Then Return

	$g_h_LootLastScan = TimerInit()

	Local $l_a_Items = Item_GetItemArray()
	If Not IsArray($l_a_Items) Then Return
	Local $l_i_Count = $l_a_Items[0]
	If $l_i_Count < 1 Then Return

	Local $i
	For $i = 1 To $l_i_Count
		If Not LootPickup_CanRun() Then Return

		Local $l_p_Item = $l_a_Items[$i]
		If $l_p_Item = 0 Then ContinueLoop

		Local $l_i_AgentID = Item_GetItemInfoByPtr($l_p_Item, "AgentID")
		If $l_i_AgentID = 0 Then ContinueLoop
		If Agent_GetAgentPtr($l_i_AgentID) = 0 Then ContinueLoop
		If Not Agent_GetAgentInfo($l_i_AgentID, "CanPickUp") Then ContinueLoop

		Local $l_f_X = Agent_GetAgentInfo($l_i_AgentID, "X")
		Local $l_f_Y = Agent_GetAgentInfo($l_i_AgentID, "Y")
		If Agent_GetDistanceToXY($l_f_X, $l_f_Y) > $g_f_LootRange Then ContinueLoop

		If Not LootPickup_ShouldTake($l_p_Item) Then ContinueLoop

		Item_PickUpItem($l_i_AgentID)
		Local $l_h_Wait = TimerInit()
		While Agent_GetAgentPtr($l_i_AgentID) > 0
			Sleep(100)
			If Not LootPickup_CanRun() Then Return
			If TimerDiff($l_h_Wait) > 8000 Then ExitLoop
		WEnd
	Next
EndFunc

Func LootPickup_ShouldTake($a_p_Item)
	Local $l_i_ModelID = Item_GetItemInfoByPtr($a_p_Item, "ModelID")
	Local $l_i_Rarity = Item_GetItemInfoByPtr($a_p_Item, "Rarity")

	If $l_i_ModelID = $GC_I_MODELID_GOLD_COIN Then
		Return Item_GetInventoryInfo("GoldCharacter") < $GC_I_LOOT_GOLD_CAP
	EndIf
	If $l_i_ModelID = $GC_I_MODELID_RATIONS Then Return True
	If $l_i_ModelID = $GC_I_MODELID_COMPASS Then Return True
	If $l_i_Rarity = $GC_I_RARITY_GOLD Then Return True
	Return False
EndFunc
