//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Inferred USRAM based 64 x 260-bit operand memory for 
//             : mul256_op_ahblite_*
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------


module mul256_op_usram (
	input				clk				,
	input				rstn			,
	input		[ 9:0]	bus_addr		,
	input		[31:0]	bus_wdata		,
	input				bus_write		,
	input				bus_read		,
	output	reg	[31:0]	bus_rdata		,
	output				bus_ready_early	,
	output	reg			bus_ready	=0	,
	
	input				op_read			,
	input		[  5:0]	op_raddr		,
	output		[259:0]	op_rdata		,
	input		[  5:0] op_waddr		,
	input				op_write		,
	input		[259:0] op_wdata		,
	output	reg			op_wready	=0	
);

	reg [18*16-1:0] mem [0:63]; /* synthesis syn_ramstyle = "no_rw_check" */
	wire [7:0] we;
	assign we = ((8'd1 << bus_addr[2:0]) & {8{bus_write & bus_ready}}) | {8{op_wready & op_write}};
	
	wire [5:0] waddr = op_wready? op_waddr: bus_addr[9:4];
	
	reg [18*16-1:0] bus_rdata_wide;
	reg [18*16-1:0] op_rdata_wide;
	reg bus_read_1 = 0;
	assign bus_ready_early = (bus_read | (op_wready? (bus_write & ~op_write) : bus_write)) & ~bus_ready;
	
	always @(posedge clk) begin : mem_write
		integer i;
		for (i=1; i<9; i=i+1)
			if (we[i-1])
				mem[waddr][36*i-1 -:36] <= op_wready? {(i==8)? op_wdata[259:256]: 4'd0, op_wdata[32*i-1 -:32]}: {4'd0, bus_wdata};
	end

	always @(posedge clk)
		if (~rstn) begin
			bus_ready <= 1'b0;
			op_wready <= 1'b0;
			//bus_read_1<= 0;
		end else begin
			bus_ready <= bus_ready_early;
			//bus_read_1<= 0;
			if (op_wready) begin
				if (bus_write & ~op_write) begin
					op_wready <= 1'b0;
				end
			end else begin
				if (op_write & ~bus_write)
					op_wready <= 1'b1;
			end
			//if (bus_read)
			//	bus_read_1<= 1'b1 & ~bus_ready;
		end
	
	always @(posedge clk) 
		if (bus_read)
			bus_rdata_wide <= mem[bus_addr[9:4]];
	
	always @* begin : mem_bus_read
		integer i;
		if (bus_addr[3]) begin
			bus_rdata <= {28'd0, bus_rdata_wide[36*8-1 -:4]};
		end else begin
			for (i=1; i<9; i=i+1)
				if ((i-1)==bus_addr[2:0])
					bus_rdata <= bus_rdata_wide[36*i-1-4 -:32];
		end
	end
	
	always @(posedge clk)
		if (op_read)
			op_rdata_wide <= mem[op_raddr];
	
	genvar g;
	generate for(g=1;g<9;g=g+1) begin : op_rdata_select
		assign op_rdata[32*g-1 -:32] = op_rdata_wide[36*g-1-4 -:32];
	end endgenerate
	assign op_rdata[259:256] = op_rdata_wide[36*8-1 -:4];
	
endmodule
