//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple Avalon MM with readdatavalid to AXI4 Lite module
//----------------------------------------------------------------------------

module ammrv2axi #(
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
	output	reg					amm_waitrequest,
	output	[P_DBYTES*8-1:0]	amm_readdata,
	output						amm_readdatavalid,
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
	assign amm_readdata      = axi_rdata;
	assign amm_readdatavalid = axi_rvalid;
	
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
	
	typedef enum int {s_idle, s_waddr, s_write, s_wresp, s_raddr, s_read} state_t;
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
						ns          <= s_waddr;
					end else if (amm_read) begin
						axi_arvalid <= 1'b1;
						ns          <= s_raddr;
					end else begin
						//amm_waitrequest <= 1'b0;
					end
				end
				s_waddr: begin
					axi_awvalid <= 1'b1;
					axi_wvalid  <= 1'b1;
					if (axi_awready) begin
						ns <= s_write;
						if (axi_wready) begin
							ns <= s_wresp;
							amm_waitrequest <= 1'b0;
						end
					end
				end
				s_write: begin
					axi_wvalid  <= 1'b1;
					axi_bready  <= 1'b1;
					if (axi_wready) begin
						ns <= s_wresp;
						amm_waitrequest <= 1'b0;
						if (axi_bvalid) begin
							ns <= s_idle;
						end
					end
				end
				s_wresp: begin
					axi_bready  <= 1'b1;
					if (axi_bvalid) begin
						ns <= s_idle;
					end
				end
				s_raddr: begin
					axi_arvalid <= 1'b1;
					if (axi_arready) begin
						ns <= s_read;
						amm_waitrequest <= 1'b0;
					end
				end
				s_read: begin
					axi_rready  <= 1'b1;
					if (axi_rvalid) begin
						ns <= s_idle;
					end
				end
			endcase
		end
		
endmodule


