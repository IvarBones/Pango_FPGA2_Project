// 修改后的sobel模块：删除固定Parameter，新增动态阈值Input端口
module	sobel  
(
	input		wire				video_clk		,  // sobel模块时钟（如pixclk_in）
	input		wire				rst_n			,  // 低电平复位
		
	// 新增：动态阈值输入（由按键控制，跨时钟域同步后传入）
	input		wire	[7:0]		sobel_threshold	,  // 动态阈值（原SOBEL_THRESHOLD=28）
	
	// 矩阵数据输入（原有端口不变）	
	input		wire				matrix_de		,
	input		wire				matrix_vs		,
	input		wire	[7:0]		matrix11 		,	
	input		wire	[7:0]   	matrix12 		,
	input		wire	[7:0]   	matrix13 		,
	input		wire	[7:0]		matrix21 		,
	input		wire	[7:0]   	matrix22 		,
	input		wire	[7:0]   	matrix23 		,
	input		wire	[7:0]		matrix31 		,
	input		wire	[7:0]   	matrix32 		,
	input		wire	[7:0]   	matrix33 		,	
	// sobel数据输出（原有端口不变）
	output		wire				sobel_vs		,
	output		wire				sobel_de		,
	output		wire	[7:0]		sobel_data
);

/****************************************************************
%      -1   0  +1    %      +1   2  +1
% gx = -2   0  +2    % gy =  0   0  0
%      -1   0  +1    %      -1  -2  -1
****************************************************************/

/****************************************************************
wire define
****************************************************************/
// （原有内部信号不变，无需修改）

/****************************************************************
reg define
****************************************************************/
reg	[9:0]	gx_temp1;
reg	[9:0]	gx_temp2;
reg	[9:0]	gy_temp1;
reg	[9:0]	gy_temp2;
reg	[9:0]	gx_data;
reg	[9:0]	gy_data;
reg	[10:0]	sobel_data_reg;
reg	[2:0]	video_de_reg;
reg	[2:0]	video_vs_reg;

/****************************************************************
step1 计算卷积（原有逻辑不变）
****************************************************************/
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
	begin
		gx_temp1	<=	9'd0;
        gx_temp2	<=	9'd0;
	end
	else	if(matrix_de)
	begin
		gx_temp1	<=	matrix13 + 2*matrix23 + matrix33;
		gx_temp2	<=	matrix11 + 2*matrix21 + matrix31;
	end
	else
	begin
		gx_temp1	<=	9'd0;
        gx_temp2	<=	9'd0;
	end
end

always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
	begin
		gy_temp1	<=	9'd0;
        gy_temp2	<=	9'd0;
	end
	else	if(matrix_de)
	begin
		gy_temp1	<=	matrix11 + 2*matrix12 + matrix13;
		gy_temp2	<=	matrix31 + 2*matrix32 + matrix33;
	end
	else
	begin
		gy_temp1	<=	9'd0;
        gy_temp2	<=	9'd0;
	end
end

/****************************************************************
step2 求卷积和（原有逻辑不变）
****************************************************************/
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		gx_data	<=	10'd0;
	else	if(gx_temp1 >= gx_temp2)
		gx_data	<=	gx_temp1 - gx_temp2;
	else
		gx_data	<=	gx_temp2 - gx_temp1;
end

always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		gy_data	<=	10'd0;
	else	if(gy_temp1 >= gy_temp2)
		gy_data	<=	gy_temp1 - gy_temp2;
	else
		gy_data	<=	gy_temp2 - gy_temp1;
end
	
/****************************************************************
step3 绝对值相加（原有逻辑不变）
****************************************************************/
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		sobel_data_reg	<=	11'd0;
	else
		sobel_data_reg	<=	gx_data + gy_data;
end

/****************************************************************
时钟延迟（原有3clk延迟逻辑不变）
****************************************************************/
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
	begin
		video_de_reg	<=	3'd0;
        video_vs_reg	<=	3'd0;
	end
	else
	begin
		video_de_reg	<=	{video_de_reg[1:0],matrix_de};
        video_vs_reg	<=	{video_vs_reg[1:0],matrix_vs};
	end
end

/****************************************************************
输出赋值：使用动态阈值input，替换原有固定Parameter
****************************************************************/
assign	sobel_vs		= 	video_vs_reg[2]			;
assign	sobel_de		= 	video_de_reg[2]			;
// 关键修改：用输入端口sobel_threshold替代原SOBEL_THRESHOLD
assign	sobel_data		=	(sobel_data_reg >= sobel_threshold) ? 8'd255 : 8'd0	;	

endmodule