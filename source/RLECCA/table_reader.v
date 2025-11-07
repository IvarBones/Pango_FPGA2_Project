module table_reader(
	clk,rst,datavalid, //global input
	A,B,r1,r2,d,e,O,HCN, //input from other modules
	d_we,d_waddr,h_rdata,t_rdata,n_rdata,d_rdata,e_rdata,h_wdata,t_wdata, //input from table
	h_raddr,t_raddr,n_raddr,d_raddr, //output to table
	p,hp,np,tp,dp,ep,fp,fn //output to others module
);

parameter address_bit=9;
parameter data_bit=38;
parameter x_bit = 10;
parameter y_bit = 9;
parameter extra_bit = 19;

input clk,rst,datavalid,A,B,r1,r2,O,HCN,d_we;
input [address_bit-1:0]d_waddr,h_rdata,t_rdata,n_rdata,h_wdata,t_wdata;
input [data_bit-1:0]d,d_rdata;
input [extra_bit-1:0]e,e_rdata;
output [address_bit-1:0]n_raddr,h_raddr,t_raddr,d_raddr;
output reg [address_bit-1:0]p,hp,np;
output [address_bit-1:0]tp;
output [data_bit-1:0]dp;
output [extra_bit-1:0]ep;
output reg fp,fn;

reg [address_bit-1:0]Rtp;
reg [data_bit-1:0]Rdp;
reg [extra_bit-1:0]Rep;

////label counter p
reg [address_bit-1:0]pc;
always@(posedge clk or posedge rst)
	if(rst)begin
		pc<=0;p<=0;
	end
	else if(datavalid)begin
		p<=pc;
		if(r1&~r2)begin
			pc<=pc+1;
		end	
	end

//////primary tables
assign n_raddr=pc;
assign h_raddr=pc;

//////secondary tables
assign t_raddr=(HCN)?h_wdata:h_rdata; 
assign d_raddr=(HCN)?h_wdata:h_rdata;

//////previous row run cache
wire DCN;
assign DCN=(d_we)&(d_waddr==hp);

assign tp=(~A&B)?t_rdata:Rtp;
assign dp=(~A&B)?d_rdata:Rdp;
assign ep=(~A&B)?e_rdata:Rep;
localparam [data_bit-1:0] INIT_BBOX = {{x_bit{1'b1}}, {x_bit{1'b0}}, {y_bit{1'b1}}, {y_bit{1'b0}}};
always@(posedge clk or posedge rst)
	if(rst)begin
		np<=0;hp<=0;fp<=0;fn<=0;Rtp<=0;
		Rdp <= INIT_BBOX;
		Rep <= 0;
	end
	else if(datavalid)begin
		Rtp<=tp;Rdp<=dp;Rep<=ep;
		if(DCN)begin
			Rdp<=d;
			Rep<=e;
		end
		if(~B&r1)begin
			hp<=t_raddr;
			fp<=~(t_raddr==p);
			np<=n_rdata;
			fn<=(n_rdata==p);
		end
		else if(O)begin
			Rtp<=t_wdata;
			fp<=1;
			hp<=h_wdata;
		end
	end
	
endmodule
