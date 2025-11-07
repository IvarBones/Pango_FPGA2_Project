module feature_accumulator(
	clk,rst,datavalid,DAC,DMG,CLR,dp,ep,d,e
);

parameter imwidth=512;
parameter imheight=512;
parameter x_bit=9;
parameter y_bit=9;
parameter address_bit=8;
parameter data_bit=38;
parameter extra_bit = 19;
parameter latency=3; //latency to offset counter x, 3 if holes filling, else 1
parameter rstx=imwidth-latency;
parameter rsty=imheight-1;
parameter compx=imwidth-1;
input clk,rst,datavalid,DAC,DMG,CLR;
input [data_bit-1:0]dp;
input [extra_bit-1:0] ep;
output reg [data_bit-1:0]d;
output reg [extra_bit-1:0]e;

////coordinate counter
reg [x_bit-1:0]x;
reg [y_bit-1:0]y;
always@(posedge clk or posedge rst)begin
	if(rst)begin 
		x<=rstx[x_bit-1:0];y<=rsty[y_bit-1:0];
	end
	else if(datavalid)begin
		if(x==compx[x_bit-1:0])begin
			x<=0;
			if(y==rsty[y_bit-1:0])
				y<=0;
			else y<=y+1;
		end
		else x<=x+1;
	end
end

/////register d
wire [x_bit-1:0]minx,maxx,minx1,maxx1;
wire [y_bit-1:0]miny,maxy,miny1,maxy1;
wire [extra_bit-1:0] area1,area;
//data accumulate
assign minx1=(DAC&(x<d[data_bit-1:data_bit-x_bit]))?x:d[data_bit-1:data_bit-x_bit];
assign maxx1=(DAC&(x>d[data_bit-x_bit-1:2*y_bit]))?x:d[data_bit-x_bit-1:2*y_bit];
assign miny1=(DAC&(y<d[2*y_bit-1:y_bit]))?y:d[2*y_bit-1:y_bit];
assign maxy1=(DAC&(y>d[y_bit-1:0]))?y:d[y_bit-1:0];
assign area1=(DAC)?e+1:e;
//data merge
assign minx=(DMG&(dp[data_bit-1:data_bit-x_bit]<minx1))?dp[data_bit-1:data_bit-x_bit]:minx1;
assign maxx=(DMG&(dp[data_bit-x_bit-1:2*y_bit]>maxx1))?dp[data_bit-x_bit-1:2*y_bit]:maxx1;
assign miny=(DMG&(dp[2*y_bit-1:y_bit]<miny1))?dp[2*y_bit-1:y_bit]:miny1;
assign maxy=(DMG&(dp[y_bit-1:0]>maxy1))?dp[y_bit-1:0]:maxy1;
assign area=(DMG)?ep+area1:area1;

always@(posedge clk or posedge rst)begin
	if(rst)begin
		d<={{x_bit{1'b1}},{x_bit{1'b0}},{y_bit{1'b1}},{y_bit{1'b0}}};
		e<=0;
	end

	else if(datavalid)begin
		if(CLR)begin
			d<={{x_bit{1'b1}},{x_bit{1'b0}},{y_bit{1'b1}},{y_bit{1'b0}}}; //CLR
			e<=0;
		end
		else begin
			d<={minx,maxx,miny,maxy};
			e<=area;
		end
	end
end

endmodule
