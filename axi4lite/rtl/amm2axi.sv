//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple Avalon MM to AXI4 Lite module
//----------------------------------------------------------------------------

module amm2axi #(
	parameter P_ASIZE  = 32, //width of the address bus (byte aligned addresses)
	parameter P_DBYTES = 4   //width of the data bus in bytes
) (
	//Avalon MM interface (slave)
	input						clk,
	input						reset,
	input	[   P_ASIZE-1:0]	amm_address,
	input	[P_DBYTES*8-1:0]	amm_writedata,
	input	[  P_DBYTES-1:0]	amm_byteenable,
	input						amm_write,
	input						amm_read,
	output	[P_DBYTES*8-1:0]	amm_readdata,
	output	reg					amm_waitrequest,
	//AXI4Lite interface (master)
	output	[   P_ASIZE-1:0]	axi_awaddr,
	output	reg					axi_awvalid,
	input						axi_awready,
	output	[P_DBYTES*8-1:0]	axi_wdata,
	output	[  P_DBYTES-1:0]	axi_wstrb,
	output	reg					axi_wvalid,
	input						axi_wready,
	output	reg					axi_bready,
	input						axi_bvalid,
	input	[           1:0]	axi_bresp,
	output	[   P_ASIZE-1:0]	axi_araddr,
	output	reg [       2:0]	axi_arsize,
	output	reg					axi_arvalid,
	input						axi_arready,
	input	[P_DBYTES*8-1:0]	axi_rdata,
	input	[           1:0]	axi_rresp, //input ignored - always valid response expected
	input						axi_rvalid,
	output	reg					axi_rready
);

	assign axi_awaddr   = amm_address;
	assign axi_araddr   = amm_address;
	assign axi_wdata    = amm_writedata;
	assign axi_wstrb    = amm_byteenable;
	assign amm_readdata = axi_rdata;
	
	int test;
	
	always @*
		begin
			axi_arsize <= (P_DBYTES == 1)? 3'b000: (P_DBYTES == 2)? 3'b001: (P_DBYTES == 4)? 3'b010: 3'b011;
			test = 0;
			for (int i=0; i<P_DBYTES/2; i++)
				if (amm_byteenable[i*2] && amm_byteenable[i*2+1])
					test++;
			if (test == 1)
				axi_arsize <= 3'b001;
			test = 0;
			for (int i=0; i<P_DBYTES; i++)
				if (amm_byteenable[i])
					test++;
			if (test == 1)
				axi_arsize <= 3'b000;
		end
	
	typedef enum logic [2:0] {s_idle, s_waddr, s_write, s_wresp, s_raddr, s_read} state_t;
	state_t cs=s_idle, ns;
	
	always @(posedge clk )
		if (reset) begin
			cs <= s_idle;
		end else begin
			cs <= ns;
		end

	always @*
		begin
			ns              <= cs;
			axi_awvalid     <= 1'b0;
			axi_wvalid      <= 1'b0;
			axi_bready      <= 1'b0;
			axi_arvalid     <= 1'b0;
			axi_rready      <= 1'b0;
			amm_waitrequest <= 1'b1;
			case (cs)
				s_idle: begin
					if (amm_write) begin
						axi_awvalid <= 1'b1;
						axi_wvalid  <= 1'b1;
						axi_bready  <= 1'b1;
						ns          <= s_waddr;
					end else if (amm_read) begin
						axi_arvalid <= 1'b1;
						axi_rready  <= 1'b1;
						ns          <= s_raddr;
					end else begin
						amm_waitrequest <= 1'b0;
					end
				end
				s_waddr: begin
					axi_awvalid <= 1'b1;
					axi_wvalid  <= 1'b1;
					axi_bready  <= 1'b1;
					if (axi_awready)
						ns <= s_write;
					if (axi_wready) begin
						ns <= s_wresp;
						if (axi_bvalid) begin
							amm_waitrequest <= 1'b0;
							ns <= s_idle;
						end
					end
				end
				s_write: begin
					axi_wvalid  <= 1'b1;
					axi_bready  <= 1'b1;
					if (axi_wready) begin
						ns <= s_wresp;
						if (axi_bvalid) begin
							amm_waitrequest <= 1'b0;
							ns <= s_idle;
						end
					end
				end
				s_wresp: begin
					axi_bready  <= 1'b1;
					if (axi_bvalid) begin
						ns <= s_idle;
						amm_waitrequest <= 1'b0;
					end
				end
				s_raddr: begin
					axi_arvalid <= 1'b1;
					axi_rready  <= 1'b1;
					if (axi_arready)
						ns <= s_read;
					if (axi_rvalid) begin
						ns <= s_idle;
						amm_waitrequest <= 1'b0;
					end
				end
				s_read: begin
					axi_rready  <= 1'b1;
					if (axi_rvalid) begin
						ns <= s_idle;
						amm_waitrequest <= 1'b0;
					end
				end
			endcase
		end
		
endmodule


//amm2axi module with registers on read data to improve system timing
module amm2axi_rdreg #(
	parameter P_ASIZE  = 32, //width of the address bus (byte aligned addresses)
	parameter P_DBYTES = 4   //width of the data bus in bytes
) (
	//Avalon MM interface (slave)
	input						clk,
	input						reset,
	input	[   P_ASIZE-1:0]	amm_address,
	input	[P_DBYTES*8-1:0]	amm_writedata,
	input	[  P_DBYTES-1:0]	amm_byteenable,
	input						amm_write,
	input						amm_read,
	output	reg [P_DBYTES*8-1:0]	amm_readdata,
	output	 					amm_waitrequest,
	//AXI4Lite interface (master)
	output	[   P_ASIZE-1:0]	axi_awaddr,
	output						axi_awvalid,
	input						axi_awready,
	output	[P_DBYTES*8-1:0]	axi_wdata,
	output	[  P_DBYTES-1:0]	axi_wstrb,
	output						axi_wvalid,
	input						axi_wready,
	output						axi_bready,
	input						axi_bvalid,
	input	[           1:0]	axi_bresp,
	output	[   P_ASIZE-1:0]	axi_araddr,
	output	[           2:0]	axi_arsize,
	output						axi_arvalid,
	input						axi_arready,
	input	[P_DBYTES*8-1:0]	axi_rdata,
	input	[           1:0]	axi_rresp, //input ignored - always valid response expected
	input						axi_rvalid,
	output						axi_rready
);

	wire [P_DBYTES*8-1:0]	amm_readdata_w;
	wire amm_waitrequest_w;
	reg amm_read_ack = 0;
	
	always @(posedge clk) begin
		if (amm_read & ~amm_waitrequest_w) begin
			amm_readdata <= amm_readdata_w;
			amm_read_ack <= 1'b1;
		end
		if (reset | amm_read_ack)
			amm_read_ack <= 1'b0;
	end
	
	assign amm_waitrequest = amm_write? amm_waitrequest_w : ~amm_read_ack;
	

	amm2axi #(P_ASIZE, P_DBYTES) i_amm2axi (
		.clk				(	clk					),
		.reset				(	reset				),
		.amm_address		(	amm_address			),
		.amm_writedata		(	amm_writedata		),
		.amm_byteenable		(	amm_byteenable		),
		.amm_write			(	amm_write			),
		.amm_read			(	amm_read			),
		.amm_readdata		(	amm_readdata_w		),
		.amm_waitrequest	(	amm_waitrequest_w	),
		.axi_awaddr			(	axi_awaddr			),
		.axi_awvalid		(	axi_awvalid			),
		.axi_awready		(	axi_awready			),
		.axi_wdata			(	axi_wdata			),
		.axi_wstrb			(	axi_wstrb			),
		.axi_wvalid			(	axi_wvalid			),
		.axi_wready			(	axi_wready			),
		.axi_bready			(	axi_bready			),
		.axi_bvalid			(	axi_bvalid			),
		.axi_bresp			(	axi_bresp			),
		.axi_araddr			(	axi_araddr			),
		.axi_arsize			(	axi_arsize			),
		.axi_arvalid		(	axi_arvalid			),
		.axi_arready		(	axi_arready			),
		.axi_rdata			(	axi_rdata			),
		.axi_rresp			(	axi_rresp			),
		.axi_rvalid			(	axi_rvalid			),
		.axi_rready			(	axi_rready			)
	);


endmodule


