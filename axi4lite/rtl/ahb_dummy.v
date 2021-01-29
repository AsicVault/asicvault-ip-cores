//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : AHB dummy slave module - just responds with a constant
//----------------------------------------------------------------------------

module ahb_dummy_slave (
	//AHB Slave (slave)
	input				hclk			,
	input				resetn			, //synchronous active low reset
	input		[31:0]	ahb_haddr		,
	input		[ 1:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0] 	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hreadyout	
);
	parameter [31:0] READDATA = 32'h0;

	ahb2amm i_ahb2amm (
		//Avalon MM interface (master)
		.aclk			(	hclk			),
		.aresetn		(	resetn			), //synchronous active low reset
		.amm_address	(					),
		.amm_writedata	(					),
		.amm_byteenable	(					),
		.amm_write		(					),
		.amm_read		(					),
		.amm_readdata	(	READDATA		),
		.amm_waitrequest(	1'b0			),
		//AHB Lite interface (slave)
		.ahb_haddr		(	ahb_haddr		),
		.ahb_hsize		(	ahb_hsize		),
		.ahb_htrans		(	ahb_htrans 		), // enable gates the htrans input to ignore transactions when disabled
		.ahb_hwdata		(	ahb_hwdata		),
		.ahb_hwrite		(	ahb_hwrite		),
		.ahb_hready		(	ahb_hready		),
		.ahb_hselx		(	ahb_hselx		),
		.ahb_hrdata		(	ahb_hrdata		),
		.ahb_hresp		(	ahb_hresp		),
		.ahb_hreadyout	(	ahb_hreadyout	)
	);

endmodule

module ahb_dummy_master (
	output		[31:0]	m_haddr		,
	output		[ 1:0]	m_hsize		,
	output		[ 2:0]	m_hburst	,
	output		[ 3:0]	m_hprot		,
	output		[ 1:0]	m_htrans	,
	output		[31:0]	m_hwdata	,
	output				m_hlock		,
	output				m_hwrite	,
	input		[31:0] 	m_hrdata	,
	input				m_hresp		,
	input				m_hready	
);

	assign m_htrans = 2'b00;
	assign m_hwrite = 1'b0 ;
	assign m_hlock  = 1'b0 ;
	
endmodule
