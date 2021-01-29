//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : a module to write data into SRAM from Avalon MM bus
//-----------------------------------------------------------------------------

module amm2sram_we #(
	parameter P_ASIZE   = 10, //width of the sram address
	parameter P_DBYTES  =  4  //width of the sram data in bytes - defines how data is mapped to addresses
) (
	//AMM interface (slave)
	input							clk			,
	input							reset		,
	amm_if.slave					amm			,
	// SRAM interface
	output	reg [P_ASIZE-1:0]		sram_waddr	,
	output	reg [P_DBYTES*8-1:0]	sram_wdata	,
	input		[P_DBYTES*8-1:0]	sram_rdata	,
	output	reg						sram_we	=0	,
	output							sram_re		
);

	reg [1:0] sel = 0;
	reg rdy = 0;
	reg cmd = 0;
	assign amm.waitrequest = ~rdy;
	reg read1 = 0, read2 = 0;
	
	assign sram_re = read1;
	
	always @(posedge clk)
		if (reset) begin
			sram_we <= 1'b0;
			sel <= 0;
			rdy <= 0;
			cmd <= 0;
			read1 <= 0;
			read2 <= 0;
		end else begin 
			rdy <= 0;
			sel <= 0;
			sram_we <= 1'b0;
			case (P_DBYTES)
				4: begin
					sram_we <= sram_we? 1'b0 : amm.write;
					rdy <= sram_we? 1'b0 : (amm.write | read2);
					read1 <= (read1|read2|rdy)? 1'b0 : amm.read;
					read2 <= (read2|rdy)? 1'b0 : read1;
				end
				2: begin
					if (cmd) begin
						sram_we <= (amm.byteenable[3:2] == 2'b11);
						rdy <= 1'b1;
						cmd <= 1'b0;
					end else begin
						cmd <= amm.write;
						sram_we <= amm.write & (amm.byteenable[1:0] == 2'b11);
					end
				end
				default: begin
					if (cmd) begin
						sram_we <= amm.byteenable[sel];
						rdy <= (sel == 2'd3);
						sel <= sel + 1'b1;
						cmd <= ~(sel == 2'd3);
					end else begin
						cmd <= amm.write;
						sram_we <= amm.write & amm.byteenable[sel];
						sel <= sel + 1'b1;
					end
				end
			endcase 
			
		end
	
	always @(posedge clk) begin
		case (P_DBYTES)
			4: begin
				sram_waddr <= amm.address[P_ASIZE+2-1 : 2];
				sram_wdata <= amm.writedata[31: 0];
				if (read2)
					amm.readdata <= sram_rdata;
			end
			2: begin
				sram_waddr <= {amm.address[P_ASIZE+1-1 : 2], cmd};
				sram_wdata <= cmd? amm.writedata[31:16] : amm.writedata[15:0];
			end
			default: begin
				sram_waddr <= {amm.address[P_ASIZE-1 : 2], sel};
				case (sel)
					2'b01	: sram_wdata <= amm.writedata[15: 8];
					2'b10	: sram_wdata <= amm.writedata[23:16];
					2'b11	: sram_wdata <= amm.writedata[31:24];
					default	: sram_wdata <= amm.writedata[ 7: 0];
				endcase
			end
		endcase
	end

endmodule
