//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : a module to take Avalon MM from i_clk domain to o_clk domain
//-----------------------------------------------------------------------------

module amm_dsync #(
	parameter P_DELAYED_CMD = 0 // set to one to give address, writedata, byteenable 1 cycle ahead of read/write (enables multicycle path)
)(
	input			i_clk		,
	input			i_reset		,
	amm_if.slave	i			,
	
	input			o_clk		,
	input			o_reset		,
	amm_if.master	o			
);

	reg [31:0] o_address_meta		;
	reg [31:0] o_writedata_meta		;
	reg [ 3:0] o_byteenable_meta	;
	reg o_read_meta  = 1'b0;
	reg o_write_meta = 1'b0;
	
	reg [31:0] i_readdata_meta, o_readdata_rt;
	wire i_ce, o_ce, i_ocmd, o_icmd;
	reg o_ce1 = 0;
	
	reg i_cmd = 0, o_cmd = 0, i_wait = 0, o_wait = 0, i_waitr=0;
	
	assign o.address	= o_address_meta	;
	assign o.writedata	= o_writedata_meta	;
	assign o.byteenable	= o_byteenable_meta	;
	
	assign i.readdata = i_readdata_meta ;
	
	always @(posedge o_clk) begin
		if (o_ce) begin
			o_address_meta   <= i.address   ;
			o_writedata_meta <= i.writedata ;
			o_byteenable_meta<= i.byteenable;
		end
		if (o.read & ~o.waitrequest) begin
			o_readdata_rt <= o.readdata;
		end
	end

	always @(posedge i_clk)
		if (i_ce)
			i_readdata_meta <= o_readdata_rt;
	
	assign i_ce = (i_cmd == i_ocmd) & i_wait;
	assign i.waitrequest = i_wait? i.write? (i_cmd != i_ocmd) : 1'b1 : ~i_waitr ;
	
	always @(posedge i_clk)
		if (i_reset) begin
			i_cmd         <= 1'b0;
			i_wait        <= 1'b0;
			i_waitr       <= 1'b0;
		end else begin 
			i_waitr <= 1'b0;
			if (i_wait) begin
				if (i_cmd == i_ocmd) begin
					i_wait <= 1'b0;
					i_waitr<= i.read;
				end
			end else begin
				if (i.write | (i.read & ~i_waitr)) begin
					i_wait <= 1'b1;
					i_cmd  <= ~i_cmd;
				end
			end
		end
		
	nsync #(.N(2),.R(0)) i_out_nsync (.r(o_reset),.c(o_clk),.i(i_cmd),.o(o_icmd));
	nsync #(.N(2),.R(0)) i_in_nsync  (.r(i_reset),.c(i_clk),.i(o_cmd),.o(i_ocmd));
		
		
	assign o.read  = o_read_meta; 
	assign o.write = o_write_meta;
	assign o_ce = (o_icmd != o_cmd) & ~(o.read | o.write | o_ce1);
		
	always @(posedge o_clk)
		if (o_reset) begin
			o_cmd   <= 1'b0;
			o_ce1   <= 1'b0;
			o_read_meta <= 1'b0;
			o_write_meta<= 1'b0;
		end else begin
			o_ce1 <= o_ce;
			if (o_read_meta | o_write_meta) begin
				if (o.waitrequest == 1'b0) begin
					o_read_meta <= 1'b0;
					o_write_meta<= 1'b0;
					o_cmd  <= o_icmd;
				end
			end else begin
				if ((P_DELAYED_CMD? o_ce1 : o_ce)) begin
					o_read_meta <= i.read;
					o_write_meta<= i.write;
				end
			end
		end
		
		
endmodule
