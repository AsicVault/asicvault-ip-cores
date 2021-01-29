//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : eccop_ic
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

module eccop_ic
#(
	parameter aw = 32, //width of the address bus (byte aligned addresses)
	parameter dw = 4 //width of the data bus in bytes
)
(
	//Master Ports
	//MSS Master Input
	input  [  aw-1:0] amm_address,
	input  [  dw-1:0] amm_byteenable,
	input  [dw*8-1:0] amm_writedata,
	input             amm_write,
	input             amm_read,
	output [dw*8-1:0] amm_readdata,
	output            amm_waitrequest,

	//Slave Outputs
	//Operand Memory
	output [  aw-1:0] dat_address,
	output [  dw-1:0] dat_byteenable,
	output [dw*8-1:0] dat_writedata,
	output            dat_write,
	output            dat_read,
	input  [dw*8-1:0] dat_readdata,
	input             dat_waitrequest,
	//Command Memory
	output [  aw-1:0] cod_address,
	output [  dw-1:0] cod_byteenable,
	output [dw*8-1:0] cod_writedata,
	output            cod_write,
	output            cod_read,
	input  [dw*8-1:0] cod_readdata,
	input             cod_waitrequest,
	//Control
	output [  aw-1:0] cmd_address,
	output [  dw-1:0] cmd_byteenable,
	output [dw*8-1:0] cmd_writedata,
	output            cmd_write,
	output            cmd_read,
	input  [dw*8-1:0] cmd_readdata,
	input             cmd_waitrequest,

	//Common Signals
	input areset, //asynchronous active high reset. set to 0 if not used
	input sreset, // synchronous active high reset, set to 0 if not used
	input clk
);




	//array declarations for master mux
	wire [  aw-1:0] w_m_address[0:0];
	wire [dw*8-1:0] w_m_writedata[0:0];
	wire [  dw-1:0] w_m_byteenable[0:0];
	wire            w_m_write[0:0];
	wire            w_m_read[0:0];

	//Array assignements for master mux
	assign w_m_address[0]    = amm_address;
	assign w_m_writedata[0]  = amm_writedata;
	assign w_m_byteenable[0] = amm_byteenable;
	assign w_m_write[0]      = amm_write;
	assign w_m_read[0]       = amm_read;

	//Selector vector for masters
	int master_sel, master_rsel;
	wire [0:0] w_m_select;
	assign w_m_select[0]    = amm_write | amm_read;

	//master selector calculation
	always @*
		for (master_sel=0; master_sel < 0; master_sel++) //last is default - therefore not probed
			if (w_m_select[master_sel]==1'b1)
				break;
	
	//Master input MUX
	reg  [  aw-1:0] master_out_address;
	reg  [dw*8-1:0] master_out_writedata;
	reg  [  dw-1:0] master_out_byteenable;
	reg             master_out_write;
	reg             master_out_read;
	
	wire [dw*8-1:0] master_in_readdata;
	wire            master_in_waitrequest;

	//State machine for transaction control
	typedef enum int {s_init, s_exec} state_t;
	state_t cs;
	
	wire cmd_valid = |w_m_select;
	wire cmd_latch_enable = (cs == s_init) & cmd_valid;
	
	//Command capture
	always @(posedge clk or posedge areset)
		if (areset) begin
			master_out_address    <= 0;
			master_out_writedata  <= 0;
			master_out_byteenable <= 0;
			master_rsel			  <= 0;
		end else if (sreset) begin
			master_out_address    <= 0;
			master_out_writedata  <= 0;
			master_out_byteenable <= 0;
			master_rsel			  <= 0;
		end else begin
			if (cmd_latch_enable) begin
				master_rsel			  <= master_sel;
				master_out_address    <= w_m_address[master_sel];;
				master_out_writedata  <= w_m_writedata[master_sel];
				master_out_byteenable <= w_m_byteenable[master_sel];
			end
		end
	
	
	typedef logic [aw-1:0] address_t;
	
	//Slave decoding logic - address represents bus word index
	wire dat_enable = ((~(address_t'(16384-1)) & master_out_address) == address_t'(0));
	wire cod_enable = ((~(address_t'(16384-1)) & master_out_address) == address_t'(16384));
	wire cmd_enable = ((~(address_t'(16384-1)) & master_out_address) == address_t'(32768));

	//Control signals to slave ports
	assign dat_write = dat_enable & master_out_write;
	assign dat_read  = dat_enable & master_out_read;
	assign cod_write = cod_enable & master_out_write;
	assign cod_read  = cod_enable & master_out_read;
	assign cmd_write = cmd_enable & master_out_write;
	assign cmd_read  = cmd_enable & master_out_read;

	//Slave port connections	
	assign dat_address    = {{(aw-14){1'b0}},master_out_address[14-1:0]}; //only specified range is output from slave port to allow synthesis optimizations
	assign dat_writedata  = master_out_writedata;
	assign dat_byteenable = master_out_byteenable;
	assign cod_address    = {{(aw-14){1'b0}},master_out_address[14-1:0]}; //only specified range is output from slave port to allow synthesis optimizations
	assign cod_writedata  = master_out_writedata;
	assign cod_byteenable = master_out_byteenable;
	assign cmd_address    = {{(aw-14){1'b0}},master_out_address[14-1:0]}; //only specified range is output from slave port to allow synthesis optimizations
	assign cmd_writedata  = master_out_writedata;
	assign cmd_byteenable = master_out_byteenable;
	assign master_in_readdata = 
		  dat_readdata & {(8*dw){dat_enable}}
		| cod_readdata & {(8*dw){cod_enable}}
		| cmd_readdata & {(8*dw){cmd_enable}}
		;
	assign master_in_waitrequest = 
		  dat_waitrequest & dat_enable
		| cod_waitrequest & cod_enable
		| cmd_waitrequest & cmd_enable
		;

	//Read data output
	assign amm_readdata    = master_in_readdata;
	assign amm_waitrequest = ((cs == s_exec) && (master_rsel == 0))? master_in_waitrequest: 1'b1;

	//Transaction control state machine
	always @(posedge clk or posedge areset)
		if (areset) begin
			cs               <= s_init;
			master_out_write <= 1'b0;
			master_out_read  <= 1'b0;
			
		end else if (sreset) begin
			cs               <= s_init;
			master_out_write <= 1'b0;
			master_out_read  <= 1'b0;
			
		end else begin
			case (cs)
				s_init:	if (cmd_valid) begin
							cs <= s_exec;
							master_out_write <= w_m_write[master_sel];
							master_out_read  <= w_m_read[master_sel];
						end

				default: if (master_in_waitrequest == 1'b0) begin
							
							cs <= s_init;
							master_out_write <= 1'b0;
							master_out_read  <= 1'b0;
						 end
			endcase
		end



endmodule
