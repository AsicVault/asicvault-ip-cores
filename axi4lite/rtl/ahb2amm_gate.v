//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AHB Lite to Avalon MM module
//----------------------------------------------------------------------------

module ahb2amm_gate #(
	parameter P_2X_CLOCK = 0 // set this to 1 when AHB bus has 2x slower (synchronous) clock compared to AMM interface
)(
	//Avalon MM interface (master)
	input				aclk			,
	input				aresetn			, //synchronous active low reset
	output		[31:0]	amm_address		,
	output		[31:0]	amm_writedata	,
	output		[ 3:0]	amm_byteenable	,
	output				amm_write		,
	output				amm_read		,
	input		[31:0]	amm_readdata	,
	input				amm_waitrequest	,
	//AHB Lite interface (slave)
	input				enable			, // clear this input to disable access to amm bus
	input		[31:0]	ahb_haddr		,
	input		[ 2:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output 				ahb_hreadyout	
);

	ahb2amm #(P_2X_CLOCK) i_ahb2amm (
		//Avalon MM interface (master)
		.aclk			(	aclk			),
		.aresetn		(	aresetn			), //synchronous active low reset
		.amm_address	(	amm_address		),
		.amm_writedata	(	amm_writedata	),
		.amm_byteenable	(	amm_byteenable	),
		.amm_write		(	amm_write		),
		.amm_read		(	amm_read		),
		.amm_readdata	(	amm_readdata	),
		.amm_waitrequest(	amm_waitrequest	),
		//AHB Lite interface (slave)
		.ahb_haddr		(	ahb_haddr		),
		.ahb_hsize		(	ahb_hsize		),
		.ahb_htrans		(	ahb_htrans & {enable,enable}	), // enable gates the htrans input to ignore transactions when disabled
		.ahb_hwdata		(	ahb_hwdata		),
		.ahb_hwrite		(	ahb_hwrite		),
		.ahb_hready		(	ahb_hready		),
		.ahb_hselx		(	ahb_hselx		),
		.ahb_hrdata		(	ahb_hrdata		),
		.ahb_hresp		(	ahb_hresp		),
		.ahb_hreadyout	(	ahb_hreadyout	)
	);

endmodule


module ahb2amm_gate_d1 (
	//Avalon MM interface (master)
	input				aclk			,
	input				aresetn			, //synchronous active low reset
	output		[31:0]	amm_address		,
	output		[31:0]	amm_writedata	,
	output		[ 3:0]	amm_byteenable	,
	output				amm_write		,
	output				amm_read		,
	input		[31:0]	amm_readdata	,
	input				amm_waitrequest	,
	//AHB Lite interface (slave)
	input				enable			, // clear this input to disable access to amm bus
	input		[31:0]	ahb_haddr		,
	input		[ 2:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output 				ahb_hreadyout	
);

	ahb2amm_d1 i_ahb2amm (
		//Avalon MM interface (master)
		.aclk			(	aclk			),
		.aresetn		(	aresetn			), //synchronous active low reset
		.amm_address	(	amm_address		),
		.amm_writedata	(	amm_writedata	),
		.amm_byteenable	(	amm_byteenable	),
		.amm_write		(	amm_write		),
		.amm_read		(	amm_read		),
		.amm_readdata	(	amm_readdata	),
		.amm_waitrequest(	amm_waitrequest	),
		//AHB Lite interface (slave)
		.ahb_haddr		(	ahb_haddr		),
		.ahb_hsize		(	ahb_hsize		),
		.ahb_htrans		(	ahb_htrans & {enable,enable}	), // enable gates the htrans input to ignore transactions when disabled
		.ahb_hwdata		(	ahb_hwdata		),
		.ahb_hwrite		(	ahb_hwrite		),
		.ahb_hready		(	ahb_hready		),
		.ahb_hselx		(	ahb_hselx		),
		.ahb_hrdata		(	ahb_hrdata		),
		.ahb_hresp		(	ahb_hresp		),
		.ahb_hreadyout	(	ahb_hreadyout	)
	);

endmodule
