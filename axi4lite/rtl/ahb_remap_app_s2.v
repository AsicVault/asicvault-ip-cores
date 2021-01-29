//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : address re-mapping logic for APP CPU S2 port to access 
//             : peripherals in HPMS
//----------------------------------------------------------------------------

module ahb_remap_app_s2 (
	//AHB Slave Interface - from CoreAHB (slave)
	input		[31:0]	s_haddr		,
	input		[ 1:0]	s_hsize		,
	input		[ 2:0]	s_hburst	,
	input		[ 3:0]	s_hprot		,
	input		[ 1:0]	s_htrans	,
	input		[31:0]	s_hwdata	,
	input				s_hwrite	,
	input				s_hmastlock	,
	input				s_hready	,
	input				s_hselx		,
	output		[31:0] 	s_hrdata	,
	output				s_hresp		,
	output				s_hreadyout	,
	
	//AHB Master Interface - to CoreAHB (master)
	output		[31:0]	m_haddr		,
	output		[ 1:0]	m_hsize		,
	output		[ 2:0]	m_hburst	,
	output		[ 3:0]	m_hprot		,
	output		[ 1:0]	m_htrans	,
	output		[31:0]	m_hwdata	,
	output				m_hlock		,
	output				m_hwrite	,
	input		[31:0] 	m_hrdata	,
	input				m_hresp		,
	input				m_hready	
);

	assign m_haddr[ 7: 0] = s_haddr[ 7: 0];
	assign m_haddr[15: 8] = s_haddr[16]? (s_haddr[15:8] < 8'd4)? 8'd4: s_haddr[15:8] : s_haddr[15:8];
	assign m_haddr[31:16] = s_haddr[16]? 16'h4002 : 16'h4004;
	
	assign m_hsize     = s_hsize    ;
	assign m_hburst    = s_hburst   ;
	assign m_hprot     = s_hprot    ;
	assign m_htrans    = s_htrans & {s_hselx, s_hselx} & {s_hready, s_hready};
	assign m_hwdata    = s_hwdata   ;
	assign m_hlock     = s_hmastlock;
	assign m_hwrite    = s_hwrite   ;
	assign s_hrdata    = m_hrdata   ;
	assign s_hresp     = m_hresp    ;
	assign s_hreadyout = m_hready   ;

endmodule

