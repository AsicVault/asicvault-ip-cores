//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : A wrapper to AMM to AXI4 Lite module with SV Interface 
//----------------------------------------------------------------------------

module amm2axi_if #(
	parameter P_ASIZE  = 32, //width of the address bus (byte aligned addresses)
	parameter P_DBYTES = 4   //width of the data bus in bytes
) (
	//AMM interface (slave)
	input						clk,
	input						reset,
	input	[   P_ASIZE-1:0]	amm_address,
	input	[P_DBYTES*8-1:0]	amm_writedata,
	input	[  P_DBYTES-1:0]	amm_byteenable,
	input						amm_write,
	input						amm_read,
	output	[P_DBYTES*8-1:0]	amm_readdata,
	output						amm_waitrequest,
	//AXI4Lite interface (master)
	axi_if.master				axi
);

	amm2axi #(
		.P_ASIZE(	P_ASIZE),
		.P_DBYTES(	P_DBYTES)
	) inst_amm2axi (
		.clk(				clk),
		.reset(				reset),
		.amm_address(		amm_address),
		.amm_writedata(		amm_writedata),
		.amm_byteenable(	amm_byteenable),
		.amm_write(			amm_write),
		.amm_read(			amm_read),
		.amm_readdata(		amm_readdata),
		.amm_waitrequest(	amm_waitrequest),
		.axi_awaddr(		axi.awaddr),
		.axi_awvalid(		axi.awvalid),
		.axi_awready(		axi.awready),
		.axi_wdata(			axi.wdata),
		.axi_wstrb(			axi.wstrb),
		.axi_wvalid(		axi.wvalid),
		.axi_wready(		axi.wready),
		.axi_bresp(			axi.bresp), 
		.axi_bvalid(		axi.bvalid),
		.axi_bready(		axi.bready),
		.axi_araddr(		axi.araddr),
		.axi_arsize(		axi.arsize),
		.axi_arvalid(		axi.arvalid),
		.axi_arready(		axi.arready),
		.axi_rdata(			axi.rdata),
		.axi_rresp(			axi.rresp), 
		.axi_rvalid(		axi.rvalid),
		.axi_rready(		axi.rready)
	);

endmodule
