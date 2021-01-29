//-----------------------------------------------------------------------------
// Copyright (c) 2018 AsicVault OU
//
// Author      : Rain Adelbert
// Description : a simple feed-through module to convert e.g. APB slave to 
//             : mirrored master
//-----------------------------------------------------------------------------

module apb2apb (
	input				S_PSELx 	,
	input				S_PENABLE	,
	input	[32-1:0]	S_PADDR		,
	input	[32-1:0]	S_PWDATA	,
	input				S_PWRITE	,
	output	[32-1:0]	S_PRDATA	,
	output				S_PREADY	,
	output				S_PSLVERR	,
	
	output				M_PSELx 	,
	output				M_PENABLE	,
	output	[32-1:0]	M_PADDR		,
	output	[32-1:0]	M_PWDATA	,
	output				M_PWRITE	,
	input	[32-1:0]	M_PRDATA	,
	input				M_PREADY	,
	input				M_PSLVERR	
);

	assign	M_PSELx 	= S_PSELx 	;
	assign	M_PENABLE	= S_PENABLE	;
	assign	M_PADDR		= S_PADDR	;
	assign	M_PWDATA	= S_PWDATA	;
	assign	M_PWRITE	= S_PWRITE	;

	assign	S_PRDATA	= M_PRDATA	;
	assign	S_PREADY	= M_PREADY	;
	assign	S_PSLVERR	= M_PSLVERR	;

endmodule
