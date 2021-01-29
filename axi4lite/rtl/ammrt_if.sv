//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM Interface definition
//----------------------------------------------------------------------------

interface ammrt_if #(
	parameter P_ASIZE  = 32, //width of the address bus (byte aligned addresses)
	parameter P_DBYTES = 4   //width of the data bus in bytes
) ();
	logic	[   P_ASIZE-1:0]	address;
	logic	[P_DBYTES*8-1:0]	writedata;
	logic	[  P_DBYTES-1:0]	byteenable;
	logic						write;
	logic						read;
	logic						waitrequest;
	logic						readdatavalid;
	logic	[P_DBYTES*8-1:0]	readdata;
	modport slave	(input address, writedata, byteenable, write, read, 
					output waitrequest, readdatavalid, readdata);
	modport master	(output address, writedata, byteenable, write, read,  
					input waitrequest, readdatavalid, readdata);
endinterface