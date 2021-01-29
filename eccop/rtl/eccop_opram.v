//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Inferred USRAM based 64 x 260-bit operand memory for 
//             : ECCOP
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

module eccop_opram (
	input				clk				,
	input				srstn			,
	input				arstn			,
	input		[ 9:0]	bus_addr		,
	input		[31:0]	bus_wdata		,
	input				bus_write		,
	input				bus_read		,
	output	reg	[31:0]	bus_rdata		,
	output	reg			bus_wready		,
	
	input				op_read			,
	input		[  5:0]	op_raddr		,
	output		[259:0]	op_rdata		,
	input		[  5:0] op_waddr		,
	input				op_write		, // op write has priority
	input		[259:0] op_wdata		
);

	reg [18*16-1:0] mem [0:63] /* synthesis syn_ramstyle = "rw_check" */;
	wire [7:0] we;
	assign we = (({7'd0,bus_wready} << bus_addr[2:0]) & {8{bus_write}}) | {8{op_write}};
	
	wire [5:0] waddr = op_write? op_waddr: bus_addr[9:4];
	
	reg [18*16-1:0] bus_rdata_wide;
	reg [18*16-1:0] op_rdata_wide;
	
	//assign bus_wready = ~op_write;
	always @(posedge clk or negedge arstn)
		if (~srstn | ~arstn)
			bus_wready <= 1'b0;
		else
			bus_wready <= bus_wready? 1'b0 : bus_write & ~op_write;
	
	
	always @(posedge clk) begin : mem_write
		integer i;
		for (i=1; i<9; i=i+1)
			if (we[i-1])
				mem[waddr][36*i-1 -:36] <= op_write? {(i==8)? op_wdata[259:256]: 4'd0, op_wdata[32*i-1 -:32]}: {4'd0, bus_wdata};
	end

	always @(posedge clk) 
		if (bus_read)
			bus_rdata_wide <= mem[bus_addr[9:4]];
	
	always @* begin : mem_bus_read
		integer i;
        bus_rdata <= {28'd0, bus_rdata_wide[36*8-1 -:4]};
		if (~bus_addr[3]) begin
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
