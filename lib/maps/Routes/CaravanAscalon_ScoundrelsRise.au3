#include-once

; Caravan vanquish route for ScoundrelsRise (forward pass from vanquish bot).

Global $aCaravanAscalon_ScoundrelsRisePath = [ _
	[-2529, -5002], _
	[-470, -2966], _
	[2763, -2033], _
	[4006, -1526], _
	[4030, -1364], _
	[4333, -1079], _
	[5013, -591], _
	[4648, -167], _
	[3978, 494], _
	[2655, 1441], _
	[2199, 2371], _
	[2159, 2464], _
	[2892, 2837], _
	[3772, 3968], _
	[3751, 4621], _
	[5106, 4888], _
	[6761, 4999], _
	[7683, 6114], _
	[6914, 7092], _
	[6540, 7500], _
	[4766, 8885], _
	[4359, 8553], _
	[3501, 7961], _
	[2428, 5685], _
	[2327, 5658], _
	[791, 5064], _
	[-37, 6023], _
	[-672, 7194], _
	[-2283, 7737], _
	[-4571, 8588], _
	[-5158, 8757], _
	[-5737, 9153], _
	[-3183, 8086], _
	[-2535, 6465], _
	[-2394, 5688], _
	[-3686, 4096], _
	[-4695, 2122], _
	[-5057, 416], _
	[-3522, 4099], _
	[-2551, 5576], _
	[-668, 4943], _
	[1202, 3009], _
	[5940, 1835] _
]

Global Const $GC_I_ROUTE_ScoundrelsRise_COUNT = 43


Func MapRoute_GetScoundrelsRise(ByRef $a_a_X, ByRef $a_a_Y)
	Return MapRoute_CopyPath1D($aCaravanAscalon_ScoundrelsRisePath, $a_a_X, $a_a_Y)
EndFunc
