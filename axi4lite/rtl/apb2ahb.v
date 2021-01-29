//-----------------------------------------------------------------------------
// Copyright (c) 2018 AsicVault OU
//
// Author      : Rain Adelbert
// Description : APB to AHB bridge
//-----------------------------------------------------------------------------

module apb2ahb (
	input				hclk			,
	input				hresetn			,
	input				APBS_PSEL 		,
	input				APBS_PENABLE	,
	input	[32-1:0]	APBS_PADDR		,
	input	[32-1:0]	APBS_PWDATA		,
	input				APBS_PWRITE		,
	output	[32-1:0]	APBS_PRDATA		,
	output				APBS_PREADY		,
	output				APBS_PSLVERR	,
	
	input	[31:0]		APB_ADDR_MASK	, // APB input address is masked with this word
	input	[31:0]		AHB_ADDR_BASE	, // this address is OR'ed to the output AHB address
	
	//AHB Lite interface (master)
	output		[31:0]	ahb_haddr		,
	output	reg	[ 1:0]	ahb_hsize		,
	output		[ 1:0]	ahb_htrans		,
	output		[31:0]	ahb_hwdata		,
	output				ahb_hwrite		,
	output		[ 2:0]	ahb_hburst		,
	input		[31:0]	ahb_hrdata		,
	input				ahb_hresp		,
	input 				ahb_hready		
);

	wire	[31:0]	amm_address			, amm_address1;
	wire	[31:0]	amm_writedata		;
	wire	[ 3:0]	amm_byteenable		;
	wire			amm_write			;
	wire			amm_read			;
	wire	[31:0]	amm_readdata		;
	wire			amm_waitrequest		;

	apb2amm #(
		.DW	(	32	),
		.AW	(	32	)
	) i_apb2amm (
		.APBS_PSEL 		(	APBS_PSEL 		),
		.APBS_PENABLE	(	APBS_PENABLE	),
		.APBS_PADDR		(	APBS_PADDR		),
		.APBS_PWDATA	(	APBS_PWDATA		),
		.APBS_PWRITE	(	APBS_PWRITE		),
		.APBS_PRDATA	(	APBS_PRDATA		),
		.APBS_PREADY	(	APBS_PREADY		),
		.APBS_PSLVERR	(	APBS_PSLVERR	),
		.AMM_ADDRESS	(	amm_address		),
		.AMM_WRITEDATA	(	amm_writedata	),
		.AMM_BYTEENABLE	(	amm_byteenable	),
		.AMM_WRITE		(	amm_write		),
		.AMM_READ		(	amm_read		),
		.AMM_READDATA	(	amm_readdata	),
		.AMM_WAITREQUEST(	amm_waitrequest	)
	);

	assign amm_address1 = (amm_address & APB_ADDR_MASK) | AHB_ADDR_BASE;
	
	amm2ahb i_amm2ahb (
		//Avalon MM interface (slave)
		.aclk			(	hclk			),
		.aresetn		(	hresetn			), //synchronous active low reset
		.amm_address	(	amm_address1	),
		.amm_writedata	(	amm_writedata	),
		.amm_byteenable	(	amm_byteenable	),
		.amm_write		(	amm_write		),
		.amm_read		(	amm_read		),
		.amm_readdata	(	amm_readdata	),
		.amm_waitrequest(	amm_waitrequest	),
		//AHB Lite interface (master)
		.ahb_haddr		(	ahb_haddr		),
		.ahb_hsize		(	ahb_hsize		),
		.ahb_htrans		(	ahb_htrans		),
		.ahb_hwdata		(	ahb_hwdata		),
		.ahb_hwrite		(	ahb_hwrite		),
		.ahb_hburst		(	ahb_hburst		),
		.ahb_hrdata		(	ahb_hrdata		),
		.ahb_hresp		(	ahb_hresp		),
		.ahb_hready		(	ahb_hready		)
	);

endmodule
