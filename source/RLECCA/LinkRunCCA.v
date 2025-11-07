module LinkRunCCA(clk,rst,datavalid,pix_in,area_th,datavalid_out,box_out);

parameter imwidth=640;
parameter imheight=480;

parameter x_bit=$clog2(imwidth); 
parameter y_bit=$clog2(imheight);
parameter address_bit=x_bit-1;
parameter data_bit=2*(x_bit+y_bit);
parameter extra_bit=19;
parameter latency=3; //latency is 3 with holes_filler

input clk,rst,datavalid,pix_in;
input [extra_bit-1:0] area_th;
output reg datavalid_out;
output reg [data_bit-1:0]box_out;

//rams' wires
wire [address_bit-1:0]n_waddr,n_wdata,n_raddr,n_rdata;
wire [address_bit-1:0]h_waddr,h_wdata,h_raddr,h_rdata;
wire [address_bit-1:0]t_waddr,t_wdata,t_raddr,t_rdata;
wire [address_bit-1:0]d_raddr,d_waddr;
wire [data_bit-1:0] d_rdata,d_wdata;
wire [extra_bit-1:0] e_rdata,e_wdata;
wire n_we,h_we,t_we,d_we;

//connection wires
wire A,B,C,D,r1,r2,fp,fn,O,HCN,DAC,DMG,CLR,EOC;
wire [address_bit-1:0]p,hp,tp,np;
wire [data_bit-1:0]d,dp;
wire [extra_bit-1:0]e,ep;
wire left,hr1,hf_out;


// Next Table: address_bit x address_bit
table_ram Next_Table (
    .wr_data    ( n_wdata ),
    .wr_addr    ( n_waddr ),
    .wr_en      ( n_we & datavalid ),
    .wr_clk     ( clk ),
    .wr_rst     ( rst ),
    .rd_data    ( n_rdata ),
    .rd_addr    ( n_raddr ),
    .rd_clk     ( clk ),
    .rd_rst     ( rst )
);

// Head Table: address_bit x address_bit
table_ram Head_Table (
    .wr_data    ( h_wdata ),
    .wr_addr    ( h_waddr ),
    .wr_en      ( h_we & datavalid ),
    .wr_clk     ( clk ),
    .wr_rst     ( rst ),
    .rd_data    ( h_rdata ),
    .rd_addr    ( h_raddr ),
    .rd_clk     ( clk ),
    .rd_rst     ( rst )
);

// Tail Table: address_bit x address_bit
table_ram Tail_Table (
    .wr_data    ( t_wdata ),
    .wr_addr    ( t_waddr ),
    .wr_en      ( t_we & datavalid ),
    .wr_clk     ( clk ),
    .wr_rst     ( rst ),
    .rd_data    ( t_rdata ),
    .rd_addr    ( t_raddr ),
    .rd_clk     ( clk ),
    .rd_rst     ( rst )
);

// Data Table: data_bit x address_bit
data_table_ram Data_Table (
    .wr_data    ( d_wdata ),
    .wr_addr    ( d_waddr ),
    .wr_en      ( d_we & datavalid ),
    .wr_clk     ( clk ),
    .wr_rst     ( rst ),
    .rd_data    ( d_rdata ),
    .rd_addr    ( d_raddr ),
    .rd_clk     ( clk ),
    .rd_rst     ( rst )
);

// Extra Table: extra_bit x address_bit
extra_table_ram Extra_Table (
  .wr_data(e_wdata),    // input [18:0]
  .wr_addr(d_waddr),    // input [8:0]
  .wr_en(d_we & datavalid),        // input
  .wr_clk(clk),      // input
  .wr_rst(rst),      // input
  .rd_addr(d_raddr),    // input [8:0]
  .rd_data(e_rdata),    // output [18:0]
  .rd_clk(clk),      // input
  .rd_rst(rst)       // input
);


//holes filler
holes_filler HF(clk,rst,datavalid,pix_in,hr1,left,hf_out);
row_buf#(imwidth-2) RBHF(clk,rst,datavalid,left,hr1);



//window & row buffer
window WIN(clk,rst,datavalid,hf_out,r1,A,B,C,D);
row_buf#(imwidth-2) RB(clk,rst,datavalid,C,r1,r2);

//table reader
table_reader#(address_bit,data_bit) TR(
	clk,rst,datavalid, //global input
	A,B,r1,r2,d,e,O,HCN, //input from other modules
	d_we,d_waddr,h_rdata,t_rdata,n_rdata,d_rdata,e_rdata,h_wdata,t_wdata, //input from table
	h_raddr,t_raddr,n_raddr,d_raddr, //output to table
	p,hp,np,tp,dp,ep,fp,fn //output to others module
);

//equivalence resolver
equivalence_resolver#(address_bit,data_bit) ES(
	clk,rst,datavalid, //global input
	A,B,C,D,p,hp,np,tp,dp,ep,fp,fn,d,e, //input from other modules
	h_we,t_we,n_we,d_we, //output to table (write enable)
	h_waddr,t_waddr,n_waddr,d_waddr, //output to table (write address)
	h_wdata,t_wdata,n_wdata,d_wdata,e_wdata, //output to table (write data)
	HCN,DAC,DMG,CLR,EOC,O //output to other modules
);


//feature accumulator
feature_accumulator#(
	.imwidth(imwidth),
	.imheight(imheight),
	.x_bit(x_bit),
	.y_bit(y_bit),
	.address_bit(address_bit),
	.data_bit(data_bit),
	.latency(latency)
	)
	FA(
	clk,rst,datavalid,DAC,DMG,CLR,dp,ep,d,e
);


//registered data output
always@(posedge clk or posedge rst)
	if(rst)begin
		datavalid_out<=0;
		box_out<=0;
	end
	else if(datavalid)begin
		datavalid_out<=0;
		if(EOC&ep>area_th)begin
			datavalid_out<=1;
			box_out<=dp; 
		end
	end

endmodule
