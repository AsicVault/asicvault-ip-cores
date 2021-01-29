//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : AXI4 Interface definition
//----------------------------------------------------------------------------

interface axi_if #(
	parameter P_ASIZE  = 32, //width of the address bus (byte aligned addresses)
	parameter P_DBYTES = 4   //width of the data bus in bytes
) ();
	logic	[   P_ASIZE-1:0]	awaddr;
	logic						awvalid;
	logic						awready;
	logic	[P_DBYTES*8-1:0]	wdata;
	logic	[  P_DBYTES-1:0]	wstrb;
	logic						wvalid;
	logic						wready;
	logic	[           1:0]	bresp; 
	logic						bvalid;
	logic						bready;
	logic	[   P_ASIZE-1:0]	araddr;
	logic	[           2:0]	arsize;
	logic						arvalid;
	logic						arready;
	logic	[P_DBYTES*8-1:0]	rdata;
	logic	[           1:0]	rresp; 
	logic						rvalid;
	logic						rready;
	modport slave	(input awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arsize, arvalid, rready, 
					output awready, wready, bvalid, bresp, arready, rdata, rresp, rvalid);
	modport master	(output awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arsize, arvalid, rready, 
					input awready, wready, bvalid, bresp, arready, rdata, rresp, rvalid);
endinterface

// tdest and tid not part of interface 
interface axis_if #(
	parameter P_DBYTES = 4,   //width of the data bus in bytes
	parameter P_USR = 1	  //width of user area, transferred with data but not modified by block   
) ();
	logic				tvalid;
	logic				tready;
	logic	[P_DBYTES*8-1:0]	tdata;
	logic	[  P_DBYTES-1:0]	tstrb;
  	logic	[  P_DBYTES-1:0]	tkeep;
 	logic				tlast;
        logic   [ P_USR-1:0] 		tuser;
        modport slave	( input tvalid, tdata, tstrb, tkeep, tlast, tuser, output tready);
        modport master	( output tvalid, tdata, tstrb, tkeep, tlast, tuser, input tready);   
endinterface

