//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AXI4 Lite to Avalon MM module
//----------------------------------------------------------------------------

module axi2amm #(
	parameter P_ASIZE  = 32, //width of the address bus (byte aligned addresses)
	parameter P_DBYTES = 4   //width of the data bus in bytes
) (
	//Avalon MM interface (master)
	input						clk,
	input						reset, //synchronous active high reset
	output	reg [ P_ASIZE-1:0]	amm_address,
	output	[P_DBYTES*8-1:0]	amm_writedata,
	output	reg [P_DBYTES-1:0]	amm_byteenable,
	output	reg					amm_write,
	output	reg					amm_read,
	input	[P_DBYTES*8-1:0]	amm_readdata,
	input						amm_waitrequest,
	//AXI4Lite interface (slave)
	input	[   P_ASIZE-1:0]	axi_awaddr,
	input						axi_awvalid,
	output	reg					axi_awready,
	input	[P_DBYTES*8-1:0]	axi_wdata,
	input	[  P_DBYTES-1:0]	axi_wstrb,
	input						axi_wvalid,
	input						axi_bready,
	output	reg					axi_bvalid,
	output	[			1:0]	axi_bresp,
	output	reg					axi_wready,
	input	[   P_ASIZE-1:0]	axi_araddr,
	input	[           2:0]	axi_arsize,
	input						axi_arvalid,
	output	reg					axi_arready,
	output	[P_DBYTES*8-1:0]	axi_rdata,
	output	[           1:0]	axi_rresp, //tied to valid response
	output	reg					axi_rvalid,
	input						axi_rready
);

	assign amm_writedata = axi_wdata;
	assign axi_rdata     = amm_readdata;
	assign axi_rresp     = 2'b00;
	
	assign axi_bresp  = 2'b00; //always OK response to writes
	reg [2:0]	r_axi_arsize;
	
	
	always @*
		begin
			if (P_DBYTES == 1) begin
				amm_byteenable <= 1'b1;
			end else if (P_DBYTES == 2) begin
				if (amm_read) begin
					if (r_axi_arsize == 0) begin
						amm_byteenable <= 2'd1 << amm_address[0];
					end else begin
						amm_byteenable <= 2'b11;
					end
				end else begin
					amm_byteenable <= axi_wstrb;
				end
			end else if (P_DBYTES == 4) begin
				if (amm_read) begin
					if (r_axi_arsize == 0) begin
						amm_byteenable <= 4'd1 << amm_address[1:0];
					end else if (r_axi_arsize == 3'b001) begin
						amm_byteenable <= 4'd3 << (amm_address[1:0] & 2'b10);
					end else begin
						amm_byteenable <= 4'd15;
					end
				end else begin
					amm_byteenable <= axi_wstrb;
				end
			end else begin
				if (amm_read) begin
					if (r_axi_arsize == 0) begin
						amm_byteenable <= 8'd1 << amm_address[2:0];
					end else if (r_axi_arsize == 3'b001) begin
						amm_byteenable <= 8'd3 << (amm_address[2:0] & 3'b110);
					end else if (r_axi_arsize == 3'b010) begin
						amm_byteenable <= 8'd15 << (amm_address[2:0] & 3'b100);
					end else begin
						amm_byteenable <= 8'd255;
					end
				end else begin
					amm_byteenable <= axi_wstrb;
				end
			end
		end
	
	typedef enum logic [5:0] {s_idle, s_waddr, s_write, s_wresp, s_raddr, s_read} state_t;
	state_t cs, ns;
	reg	l_amm_write, l_amm_read;
	
	always @(posedge clk)
		if (reset) begin
			cs        <= s_idle;
			amm_write <= 1'b0;
			amm_read  <= 1'b0;
			amm_address <= 0;
			r_axi_arsize <= 0;
		end else begin
			cs <= ns;
			amm_write <= l_amm_write;
			amm_read  <= l_amm_read;
			if (cs == s_idle) begin
				amm_address <= (axi_awvalid)? axi_awaddr: axi_araddr;
				r_axi_arsize <= axi_arsize;
			end
		end

	always @*
		begin
			ns            <= cs;
			axi_awready   <= 1'b0;
			axi_wready    <= 1'b0;
			axi_arready   <= 1'b0;
			axi_rvalid    <= 1'b0;
			axi_bvalid    <= 1'b0;
			l_amm_write   <= 1'b0;
			l_amm_read    <= 1'b0;
			case (cs)
				s_idle: begin
					if (axi_awvalid) begin
						ns <= s_waddr;
						l_amm_write <= axi_wvalid;
					end else if (axi_arvalid) begin
						ns <= s_raddr;
						l_amm_read  <= axi_rready;
					end
				end
				s_waddr: begin
					l_amm_write <= axi_wvalid;
					axi_awready <= 1'b1;
					axi_wready  <= ~amm_waitrequest;
					ns          <= amm_waitrequest? s_write: s_wresp;
				end
				s_write: begin
					l_amm_write <= axi_wvalid;
					if (amm_waitrequest == 1'b0) begin
						l_amm_write <= 1'b0;
						axi_wready  <= 1'b1;
						ns          <= s_wresp;
					end
				end
				s_wresp: begin
					axi_bvalid <= 1'b1;
					if (axi_bready) begin
						ns <= s_idle;
					end
				end
				s_raddr: begin
					l_amm_read  <= axi_rready;
					axi_arready <= 1'b1;
					ns <= s_read;
				end
				s_read: begin
					l_amm_read  <= axi_rready;
					if (amm_read & (amm_waitrequest == 1'b0)) begin
						ns         <= s_idle;
						axi_rvalid <= 1'b1;
						l_amm_read <= 1'b0;
					end
				end
			endcase
		end
		
endmodule
