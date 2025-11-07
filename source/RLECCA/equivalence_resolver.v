module equivalence_resolver(
	clk,rst,datavalid, //global input
	A,B,C,D,p,hp,np,tp,dp,ep,fp,fn,dd,e, //input from other modules
	h_we,t_we,n_we,d_we, //output to table (write enable)
	h_waddr,t_waddr,n_waddr,d_waddr, //output to table (write address)
	h_wdata,t_wdata,n_wdata,d_wdata,e_wdata, //output to table (write data)
	HCN,DAC,DMG,CLR,EOC,O //output to other modules
);
parameter address_bit=9;
parameter data_bit=38;
parameter extra_bit=19;

input clk,rst,datavalid,A,B,C,D,fp,fn;
input [address_bit-1:0]p,hp,np,tp;
input [data_bit-1:0]dp,dd;
input [extra_bit-1:0] ep,e;

output reg h_we,t_we,n_we,d_we;
output reg[address_bit-1:0]h_waddr,t_waddr,n_waddr,d_waddr;
output reg[address_bit-1:0]h_wdata,t_wdata,n_wdata;
output reg[data_bit-1:0]d_wdata;
output reg[extra_bit-1:0] e_wdata;
output HCN,DAC,DMG,CLR,O;
output reg EOC;

reg [address_bit-1:0]cc,h;
reg f,HBF;
wire Ec,Ep;

assign DMG=O&~(f&hp==h);
assign DAC=D;

/////events
assign Ec=(C&~D);
assign Ep=(A&~B);
assign O=(B&D&(~A|~C));
assign CLR=Ec;
assign HCN=HBF&(np==p);


////cache cc,h,f
always@(posedge clk or posedge rst)
	if(rst)begin
		cc<=0;h<=0;f<=0;
	end
	else if(datavalid)
		if(Ec)begin
			cc<=cc+1; //INC
			f<=0;	//CLR
		end
		else if(O)begin
			h<=h_wdata;f<=1; //ET1,ET2,ET3
		end

/////table update
always@*begin
	h_we=0;h_waddr={address_bit{1'bx}};h_wdata={address_bit{1'bx}};
	t_we=0;t_waddr={address_bit{1'bx}};t_wdata={address_bit{1'bx}};
	n_we=0;n_waddr={address_bit{1'bx}};n_wdata={address_bit{1'bx}};
	d_we=0;d_waddr={address_bit{1'bx}};d_wdata={data_bit{1'bx}};e_wdata={extra_bit{1'bx}};
	EOC=0;HBF=0;
	if(Ec)begin
		n_we=1;n_waddr=cc;n_wdata=cc; //CLR
		h_we=1;h_waddr=cc;h_wdata=cc; //CLR
		case(f)
		0:begin d_we=1;d_waddr=cc;d_wdata=dd;e_wdata=e;end	//DUC
		1:begin d_we=1;d_waddr=h;d_wdata=dd;e_wdata=e;end	//DUH
		endcase
	end
	else if(Ep)begin
		case(fp)
		0:begin	
			d_we=1;d_waddr=np;d_wdata=dp;e_wdata=ep;//DBF
			if(fn)EOC=1;	end	  //EOC
		1:begin	h_we=1;h_waddr=np;h_wdata=hp;HBF=1;end	//HBF
		endcase
	end
	else if(O)
		case({f,fp})
		2'b00:begin
			h_we=1;h_waddr=np;h_wdata=cc;	//ET1
			t_we=1;t_waddr=h_wdata;t_wdata=cc;
		end
		2'b01:begin
			h_we=1;h_waddr=np;h_wdata=hp;	//ET3
			t_we=1;t_waddr=h_wdata;t_wdata=cc;
			n_we=1;n_waddr=tp;n_wdata=cc;	//EM1
		end
		2'b10:begin
			h_we=1;h_waddr=np;h_wdata=h;	//ET2
			t_we=1;t_waddr=h_wdata;t_wdata=cc;
		end
		2'b11:begin
			h_we=1;h_waddr=np;h_wdata=hp;	//ET3
			t_we=1;t_waddr=h_wdata;t_wdata=cc;
			n_we=1;n_waddr=tp;n_wdata=h;	//EM2
		end
		endcase
end


endmodule

