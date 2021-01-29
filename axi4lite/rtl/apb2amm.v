//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : APB to Avalon MM bus bridge, supports only 32-bit access
//-----------------------------------------------------------------------------

module apb2amm #(
		parameter DW = 32,
		parameter AW = 32
)(
	input				APBS_PSEL 		,
	input				APBS_PENABLE	,
	input	[AW-1:0]	APBS_PADDR		,
	input	[DW-1:0]	APBS_PWDATA		,
	input				APBS_PWRITE		,
	output	[DW-1:0]	APBS_PRDATA		,
	output				APBS_PREADY		,
	output				APBS_PSLVERR	,
	
	output	[AW-1:0]	AMM_ADDRESS		,
	output	[DW-1:0]	AMM_WRITEDATA	,
	output	[DW/8-1:0]	AMM_BYTEENABLE	,
	output				AMM_WRITE		,
	output				AMM_READ		,
	input	[DW-1:0]	AMM_READDATA	,
	input				AMM_WAITREQUEST	
);

	assign AMM_ADDRESS   = APBS_PADDR;
	assign AMM_WRITEDATA = APBS_PWDATA;
	assign AMM_WRITE     = (APBS_PSEL & APBS_PENABLE)?  APBS_PWRITE : 1'b0;
	assign AMM_READ      = (APBS_PSEL & APBS_PENABLE)? ~APBS_PWRITE : 1'b0;
	assign APBS_PREADY   = ~AMM_WAITREQUEST;
	assign APBS_PRDATA   = AMM_READDATA;
	assign APBS_PSLVERR  = 1'b0;
	assign AMM_BYTEENABLE= {(DW/8){1'b1}};

endmodule