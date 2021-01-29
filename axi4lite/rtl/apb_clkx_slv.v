//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Another instance of APB bus clock domain crossing module
//             : to enable different set of bus interface types in same block design
//-----------------------------------------------------------------------------

module apb_clkx_slv #(
		parameter DW = 16,
		parameter AW = 16
)(
	// slave port - ingress
	input				APBS_CLK		,
	input				APBS_RESETN		,
	input				APBS_PSEL 		,
	input				APBS_PENABLE	,
	input  [AW-1:0]		APBS_PADDR		,
	input  [DW-1:0]		APBS_PWDATA		,
	input				APBS_PWRITE		,
	output [DW-1:0]		APBS_PRDATA		,
	output				APBS_PREADY		,
	output				APBS_PSLVERR	,

	// master port - egress
	input				APBM_CLK		,
	input				APBM_RESETN		,
	output reg			APBM_PSEL 		,
	output reg			APBM_PENABLE	,
	output [AW-1:0]		APBM_PADDR		,
	output [DW-1:0]		APBM_PWDATA		,
	output 				APBM_PWRITE		,
	input  [DW-1:0]		APBM_PRDATA		,
	input				APBM_PREADY		,
	input				APBM_PSLVERR	
);


	apb_clkx #(
		.DW	(	DW	),
		.AW	(	AW	)
	) i_apb_clkx (
		// slave port - ingress
		.APBS_CLK		(	APBS_CLK		),
		.APBS_RESETN	(	APBS_RESETN		),
		.APBS_PSEL 		(	APBS_PSEL 		),
		.APBS_PENABLE	(	APBS_PENABLE	),
		.APBS_PADDR		(	APBS_PADDR		),
		.APBS_PWDATA	(	APBS_PWDATA		),
		.APBS_PWRITE	(	APBS_PWRITE		),
		.APBS_PRDATA	(	APBS_PRDATA		),
		.APBS_PREADY	(	APBS_PREADY		),
		.APBS_PSLVERR	(	APBS_PSLVERR	),

		// master port - egress
		.APBM_CLK		(	APBM_CLK		),
		.APBM_RESETN	(	APBM_RESETN		),
		.APBM_PSEL 		(	APBM_PSEL 		),
		.APBM_PENABLE	(	APBM_PENABLE	),
		.APBM_PADDR		(	APBM_PADDR		),
		.APBM_PWDATA	(	APBM_PWDATA		),
		.APBM_PWRITE	(	APBM_PWRITE		),
		.APBM_PRDATA	(	APBM_PRDATA		),
		.APBM_PREADY	(	APBM_PREADY		),
		.APBM_PSLVERR	(	APBM_PSLVERR	)
	);

endmodule