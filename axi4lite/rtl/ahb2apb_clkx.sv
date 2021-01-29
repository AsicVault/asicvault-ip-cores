//-----------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple AHB Lite to APB bridge with clock domain crossing
//-----------------------------------------------

module ahb2apb_clkx (
	//Avalon MM interface (master)
	input				hclk			,
	input				hresetn			, //aynchronous active low reset
	//AHB Lite interface (slave interface)
	input		[31:0]	apb_addr_mask	,
	input		[31:0]	ahb_haddr		,
	input		[ 2:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hreadyout	,
	// APB bus - master
	input				PCLK			,
	input				PRESETN			, //asynchronous active low reset
	output				APB_PSELx		,
	output				APB_PENABLE		,
	output		[31:0]	APB_PADDR		,
	output		[31:0]	APB_PWDATA		,
	output				APB_PWRITE		,
	input		[31:0]	APB_PRDATA		,
	input				APB_PREADY		,
	input				APB_PSLVERR		
);
	
	amm_if am1(), am2();
	
	ahb2amm #(
		.P_2X_CLOCK	(0) // set this to 1 when AHB bus has 2x slower (synchronous) clock compared to AMM interface
	) i_ahb2amm (
		.aclk				(	hclk				),
		.aresetn			(	hresetn				), //synchronous active low reset
		.amm_address		(	am1.address			),
		.amm_writedata		(	am1.writedata		),
		.amm_byteenable		(	am1.byteenable		),
		.amm_write			(	am1.write			),
		.amm_read			(	am1.read			),
		.amm_readdata		(	am1.readdata		),
		.amm_waitrequest	(	am1.waitrequest		),
		.ahb_haddr			(	ahb_haddr			),
		.ahb_hsize			(	ahb_hsize			),
		.ahb_htrans			(	ahb_htrans			),
		.ahb_hwdata			(	ahb_hwdata			),
		.ahb_hwrite			(	ahb_hwrite			),
		.ahb_hready			(	ahb_hready			),
		.ahb_hselx			(	ahb_hselx			),
		.ahb_hrdata			(	ahb_hrdata			),
		.ahb_hresp			(	ahb_hresp			),
		.ahb_hreadyout		(	ahb_hreadyout		)
	);
	
	
	amm_dsync #(
		.P_DELAYED_CMD (0) // set to one to give address, writedata, byteenable 1 cycle ahead of read/write (enables multicycle path)
	) i_amm_dsync (
		.i_clk		(	hclk		),
		.i_reset	(	~hresetn	),
		.i			(	am1			),
		.o_clk		(	PCLK		),
		.o_reset	(	~PRESETN	),
		.o			(	am2			)
	);	
	
	
	amm2apb i_amm2apb (
		.clk				(	PCLK				),
		.reset				(	~PRESETN			),
		.amm_address		(	am2.address & apb_addr_mask),
		.amm_writedata		(	am2.writedata		),
		.amm_write			(	am2.write			),
		.amm_read			(	am2.read			),
		.amm_readdata		(	am2.readdata		),
		.amm_waitrequest	(	am2.waitrequest		),
		.APB_PSEL 			(	APB_PSELx			),
		.APB_PENABLE		(	APB_PENABLE			),
		.APB_PADDR			(	APB_PADDR			),
		.APB_PWDATA			(	APB_PWDATA			),
		.APB_PWRITE			(	APB_PWRITE			),
		.APB_PRDATA			(	APB_PRDATA			),
		.APB_PREADY			(	APB_PREADY			),
		.APB_PSLVERR		(	APB_PSLVERR			)
	);
	
endmodule

