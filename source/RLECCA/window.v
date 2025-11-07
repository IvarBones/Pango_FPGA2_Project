module window(clk,rst,datavalid,pix_in_current,pix_in_previous,A,B,C,D);

input clk,rst,datavalid,pix_in_current,pix_in_previous;
output reg A,B,C,D;

always@(posedge clk or posedge rst) begin
	if(rst)begin
		A<=0;B<=0;
		C<=0;D<=0;
	end
	else if(datavalid)begin
		A<=B;B<=pix_in_previous;
		C<=D;D<=pix_in_current;
	end
end	
endmodule
