#include-once

; Caravan vanquish route for GriffonsMouth — starts at Scoundrels-side portal entry.

Global $aCaravanAscalon_GriffonsMouthPath = [ _
	[4371, 4294], _
	[6586, 5423], _
	[3032, 8331], _
	[597, 6595], _
	[-1159, 8115], _
	[-3406, 6831], _
	[-961, 8115], _
	[-367, 6241], _
	[-1156, 3651], _
	[1349, 2834], _
	[-2345, 4080], _
	[-3518, 5166], _
	[-6410, 3478], _
	[-7529, 905], _
	[-5098, -977], _
	[-2464, -1537], _
	[-1849, -4314], _
	[-2270, -1127], _
	[762, -1374], _
	[1692, -3331], _
	[3041, -6006], _
	[6002, -3706], _
	[5162, -7264], _
	[5998, -3834], _
	[6196, -356], _
	[5547, -3291], _
	[3009, -6002], _
	[1535, -4368], _
	[-570, -6574], _
	[-2913, -7105] _
]

Global Const $GC_I_ROUTE_GriffonsMouth_COUNT = 30

Func MapRoute_GetGriffonsMouth(ByRef $a_a_X, ByRef $a_a_Y)
	Return MapRoute_CopyPath1D($aCaravanAscalon_GriffonsMouthPath, $a_a_X, $a_a_Y)
EndFunc
