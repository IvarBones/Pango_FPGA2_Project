`timescale 1ns / 1ps
module HDMI_IN_DDR3_bin_ero_dil_top#(
	parameter MEM_ROW_ADDR_WIDTH   = 15         ,
	parameter MEM_COL_ADDR_WIDTH   = 10         ,
	parameter MEM_BADDR_WIDTH      = 3          ,
	parameter MEM_DQ_WIDTH         =  32        ,
	parameter MEM_DQS_WIDTH        =  32/8
)(
	input                                sys_clk              ,//27Mhz
    input                                clk_p ,
    input                                clk_n ,
    input                                rst_in ,

// 新增：5个用户按键（按手册定义，低电平有效）key
    input                                KEY0                 ,// 阈值+10
    input                                KEY1                 ,// 阈值-10
    input                                KEY2                 ,// 阈值复位
    input                                KEY3                 ,// 预留

//DDR
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_cs_n                  ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a                     ,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,
    output reg                           heart_beat_led            ,
    output                               ddr_init_done             ,
    output                               init_over_rx              ,
//MS72xx       
    output                               rstn_out                  ,
    output                               hd_scl                ,
    inout                                hd_sda                ,
    output                               hdmi_int_led              ,//HDMI_OUT初始化完成

    //HDMI_in
    input             pixclk_in    ,                            
    input             vs_in    , 
    input             hs_in    , 
    input             de_in    ,
    input     [7:0]   r_in    , 
    input     [7:0]   g_in    , 
    input     [7:0]   b_in    , 
//HDMI_OUT
    output                               pix_clk   /*synthesis PAP_MARK_DEBUG="1"*/                ,//pixclk                           
    output    reg                           vs_out    /*synthesis PAP_MARK_DEBUG="1"*/                , 
    output    reg                           hs_out    /*synthesis PAP_MARK_DEBUG="1"*/                , 
    output    reg                           de_out    /*synthesis PAP_MARK_DEBUG="1"*/                ,
    output    reg    [7:0]                  r_out     /*synthesis PAP_MARK_DEBUG="1"*/                , 
    output    reg    [7:0]                  g_out     /*synthesis PAP_MARK_DEBUG="1"*/                , 
    output    reg    [7:0]                  b_out     /*synthesis PAP_MARK_DEBUG="1"*/                ,

// 新增：GPIO输出（阈值判断结果，高有效）
    output reg                          gpio_y_th              ,// y坐标超阈值输出
    output reg                          gpio_angle_th              // angle角度超阈值输出
);
/////////////////////////////////////////////////////////////////////////////////////
// ENABLE_DDR
    parameter CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;//28
    parameter TH_1S = 27'd33000000;
/////////////////////////////////////////////////////////////////////////////////////
    reg  [15:0]                 rstn_1ms            ;
    wire[15:0]                  o_rgb565            ;

//axi bus   
    wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr                 ;
    wire                        axi_awuser_ap              ;
    wire [3:0]                  axi_awuser_id              ;
    wire [3:0]                  axi_awlen                  ;
    wire                        axi_awready                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_awvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata                  ;
    wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb                  ;
    wire                        axi_wready                 ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [3:0]                  axi_wusero_id              ;
    wire                        axi_wusero_last            ;
    wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr                 ;
    wire                        axi_aruser_ap              ;
    wire [3:0]                  axi_aruser_id              ;
    wire [3:0]                  axi_arlen                  ;
    wire                        axi_arready                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_arvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata                   /* synthesis syn_keep = 1 */;
    wire                        axi_rvalid                  /* synthesis syn_keep = 1 */;
    wire [3:0]                  axi_rid                    ;
    wire                        axi_rlast                  ;
    reg  [26:0]                 cnt                        ;
    reg  [15:0]                 cnt_1                      ;
/////////////////////////////////////////////////////////////////////////////////////
//PLL
pll pll_gen_clk (
    .clkin1   (  sys_clk    ),//27MHz
    .clkout0  (  pix_clk    ),//148.5

    .lock (  locked     )
);


cfg_pll cfg_pll_inst (
  .clkout0(cfg_clk),    // output
  .lock(),          // output
  .clkin1(sys_clk)       // input
);




ms72xx_ctl ms72xx_ctl(
    .clk         (  cfg_clk    ), //input       clk,
    .rst_n       (  rstn_out   ), //input       rstn,
           
    .init_over_rx(  rx_init_done),                 
    .init_over   (  init_over  ), //output      init_over,
    .iic_scl     (  hd_scl    ), //output      iic_scl,
    .iic_sda     (  hd_sda    )  //inout       iic_sda
);
    assign   init_over_rx = rx_init_done;
   assign    hdmi_int_led    =    init_over; 
    
    always @(posedge cfg_clk)
    begin
    	if(!locked)
    	    rstn_1ms <= 16'd0;
    	else
    	begin
    		if(rstn_1ms == 16'h2710)
    		    rstn_1ms <= rstn_1ms;
    		else
    		    rstn_1ms <= rstn_1ms + 1'b1;
    	end
    end
    



    reg    rstn_d0;
    reg    rstn_d1;




    assign rstn_out = (rstn_1ms == 16'h2710);


 reg  rst_reg ;
    always @ (posedge sys_clk )
        if (~rst_in)
            rst_reg <= 1'b1 ;
        else
            rst_reg <= 1'b0 ;

wire    [15:0]    hdmi_data_in;
assign    hdmi_data_in = {r_in[7:3],g_in[7:2],b_in[7:3]};


wire    vs_reg;
wire    hs_reg;
wire    rd_en ;

// ------------------------------
// 例化1：KEY0（模式切换）
// ------------------------------
wire key0_press;  // KEY0单次触发信号
wire key0_state;  // KEY0当前状态
key#(
    .DEBOUNCE_CNT(20'd540000)  // 20ms消抖（27MHz）
)u_key0(
    .sys_clk    (sys_clk      ),
    .rst_in     (rst_in       ),
    .key_raw    (KEY0         ),  // 接顶层KEY0端口（硬件低电平有效）
    .key_press  (key0_press   ),  // 输出：KEY0单次按下触发
    .key_state  (key0_state   )   // 输出：KEY0当前状态
);

// ------------------------------
// 例化2：KEY1（阈值+）
// ------------------------------
wire key1_press;
wire key1_state;
key#(
    .DEBOUNCE_CNT(20'd540000)
)u_key1(
    .sys_clk    (sys_clk      ),
    .rst_in     (rst_in       ),
    .key_raw    (KEY1         ),
    .key_press  (key1_press   ),
    .key_state  (key1_state   )
);

// ------------------------------
// 例化3：KEY2（阈值-）
// ------------------------------
wire key2_press;
wire key2_state;
key#(
    .DEBOUNCE_CNT(20'd540000)
)u_key2(
    .sys_clk    (sys_clk      ),
    .rst_in     (rst_in       ),
    .key_raw    (KEY2         ),
    .key_press  (key2_press   ),
    .key_state  (key2_state   )
);

wire key3_press;
wire key3_state;
key#(
    .DEBOUNCE_CNT(20'd540000)
)u_key3(
    .sys_clk    (sys_clk      ),
    .rst_in     (rst_in       ),
    .key_raw    (KEY3         ),
    .key_press  (key3_press   ),
    .key_state  (key3_state   )
);

// ------------------------------
// 模式定义：新增MODE_Y_MIN和MODE_Y_MAX，KEY0循环切换
// ------------------------------
localparam MODE_BIN          =   3'd0;  // 模式0：二值化阈值（bin_th）
localparam MODE_SOBEL        =   3'd1;  // 模式1：Sobel阈值（sobel_th）
localparam MODE_Y_MIN        =   3'd2;  // 模式2：y_min阈值（0~240，下限）
localparam MODE_Y_MAX        =   3'd3;  // 模式3：y_max阈值（240~480，上限）
localparam MODE_ANGLE_TH     =   3'd4;  // 模式4：angle阈值（0~180，原模式3顺延）
localparam MODE_Z_ANGLE_TH   =   3'd5;  //z_ange_th
localparam MODE_SET_TEMPLATE =   3'd6;  // 设置此时的长边长为cos求z_angle的长边，方便调试
localparam MODE_AREA_TH      =   3'd7;

reg [2:0] curr_mode;  // 扩展为3位寄存器（支持0~4共5个模式）

// ------------------------------
// 阈值寄存器（修复：y_min/y_max改为11位，匹配图像高度480）
// ------------------------------
reg [7:0] bin_th_sys;          // 模式0：二值化阈值（0~255，8位足够）
reg [7:0] sobel_th_sys;        // 模式1：Sobel阈值（0~255，8位足够）
reg [10:0] y_min_sys;          // 模式2：y_min阈值（0~479，11位支持0~2047）
reg [10:0] y_max_sys;          // 模式3：y_max阈值（0~479，11位支持）
reg [7:0] angle_th_sys;        // 模式4：angle阈值（0~90，8位足够）
reg [7:0] z_angle_th_sys;      // 新增：z_angle阈值（0~85，8位足够，初始值45）
reg       set_template_flag;    //是否设置此时的长边长为cos求z_angle的长边
reg [17:0] area_th_sys;  // 连通域最小面积（0~131071，足够覆盖640*480图像）
wire [23:0] area_th_sys_24bit = {6'b0, area_th_sys};  // 扩展为24位供char_proc显示

// 补全字符叠加模块所需24位信号
wire [23:0] sobel_th_sys_24bit = {16'b0, sobel_th_sys};
wire [23:0] y_min_sys_24bit    = {13'b0, y_min_sys};    // 11位扩展24位
wire [23:0] y_max_sys_24bit    = {13'b0, y_max_sys};    // 11位扩展24位



//KEY0
always @(posedge sys_clk or negedge rst_in) begin
    if (!rst_in) begin
        curr_mode <= MODE_BIN;
    end else if (key0_press) begin
        case (curr_mode)
            MODE_BIN        : curr_mode <= MODE_SOBEL;
            MODE_SOBEL      : curr_mode <= MODE_Y_MIN;
            MODE_Y_MIN      : curr_mode <= MODE_Y_MAX;
            MODE_Y_MAX      : curr_mode <= MODE_ANGLE_TH;
            MODE_ANGLE_TH   : curr_mode <= MODE_Z_ANGLE_TH;
            MODE_Z_ANGLE_TH : curr_mode <= MODE_SET_TEMPLATE;
            MODE_SET_TEMPLATE : curr_mode <= MODE_AREA_TH;  // 新增：切到area_th模式
            MODE_AREA_TH    : curr_mode <= MODE_BIN;  // 新增：循环回初始模式
            default         : curr_mode <= MODE_BIN;
        endcase
    end
end

// ------------------------------
// 阈值调节逻辑（修复：Ymax位宽与边界，添加有效范围约束）
// ------------------------------
always @(posedge sys_clk or negedge rst_in) begin
    if (!rst_in) begin
        bin_th_sys    <= 8'd65;
        sobel_th_sys  <= 8'd100;
        y_min_sys     <= 11'd80;    // 初始y_min（11位）
        y_max_sys     <= 11'd400;   // 初始y_max（11位，400≤480）
        angle_th_sys  <= 8'd45;
        z_angle_th_sys<= 8'd45;  // 新增：z_angle_th初始值（与angle_th一致）
        area_th_sys   <= 18'd50;
    end else begin
        case (curr_mode)
            // 模式0：二值化阈值（边界检查）
            MODE_BIN: begin
                if (key1_press && bin_th_sys < 8'd250)  
                    bin_th_sys <= bin_th_sys + 8'd2;
                else if (key2_press && bin_th_sys > 8'd5)  
                    bin_th_sys <= bin_th_sys - 8'd2;
            end
            
            // 模式1：Sobel阈值（边界检查）
            MODE_SOBEL: begin
                if (key1_press && sobel_th_sys < 8'd250) 
                    sobel_th_sys <= sobel_th_sys + 8'd2;
                else if (key2_press && sobel_th_sys > 8'd5) 
                    sobel_th_sys <= sobel_th_sys - 8'd2;
            end
            
            // 模式2：调节y_min（修复：11位边界，确保y_min < y_max-10）
            MODE_Y_MIN: begin
                if (key1_press && y_min_sys < 11'd460 && y_min_sys < (y_max_sys - 11'd10)) 
                    y_min_sys <= y_min_sys + 11'd5;  // 步长5（11位）
                else if (key2_press && y_min_sys > 11'd5) 
                    y_min_sys <= y_min_sys - 11'd5;
            end
            
            // 模式3：调节y_max（修复：11位边界，核心修复点）
            MODE_Y_MAX: begin
                if (key1_press && y_max_sys < 11'd475 && y_max_sys > (y_min_sys + 11'd10)) 
                    y_max_sys <= y_max_sys + 11'd5;  // 不超过475（留5余量）
                else if (key2_press && y_max_sys > 11'd245) 
                    y_max_sys <= y_max_sys - 11'd5;  // 不低于245
            end
            
            // 模式4：调节angle阈值（边界检查）
            MODE_ANGLE_TH: begin
                if (key1_press && angle_th_sys < 8'd85) 
                    angle_th_sys <= angle_th_sys + 8'd2;
                else if (key2_press && angle_th_sys > 8'd5) 
                    angle_th_sys <= angle_th_sys - 8'd2;
            end
            //模式5：调节z_angle阈值
            MODE_Z_ANGLE_TH: begin
                if (key1_press && z_angle_th_sys < 8'd85)  // 上限85（与angle_th一致）
                    z_angle_th_sys <= z_angle_th_sys + 8'd2;  // 步长2
                else if (key2_press && z_angle_th_sys > 8'd5)  // 下限5
                    z_angle_th_sys <= z_angle_th_sys - 8'd2;
            end

            MODE_SET_TEMPLATE: begin
                if (key1_press)  // 
                    set_template_flag <= 1;  // 步长2
                else if (key2_press )  //
                    set_template_flag <= 0;
            end

// 新增：MODE_AREA_TH调节（步长10，边界0~1000）
            MODE_AREA_TH: begin
                if (key1_press && area_th_sys < 18'd1000)  // 上限1000（可按需调整）
                    area_th_sys <= area_th_sys + 18'd10;  // 步长10
                else if (key2_press && area_th_sys > 18'd0)  // 下限0
                    area_th_sys <= area_th_sys - 18'd10;
            end
            
            default: ;
        endcase
    end
end

// ------------------------------
// 3种数据切换状态定义
// ------------------------------
reg [1:0] data_sel;  // 3种数据切换标志

// KEY3单次按下触发状态循环
always @(posedge sys_clk or negedge rst_in) begin
    if (!rst_in) begin
        data_sel <= 2'b00;  // 初始默认使用原数据组
    end else if (key3_press) begin  
        case (data_sel)
            2'b00: data_sel <= 2'b01;
            2'b01: data_sel <= 2'b10;
            2'b10: data_sel <= 2'b00;
            default: data_sel <= 2'b00;
        endcase
    end
end


// ------------------------------
// 阈值跨时钟域同步（修复：新增pix_clk域同步，用于字符显示）
// ------------------------------
// 1. 到pixclk_in域（判断模块用）
reg [7:0] bin_th_sync1, bin_th_sync2;    // 二值化阈值同步
reg [7:0] sobel_th_sync1, sobel_th_sync2;// Sobel阈值同步
reg [10:0] y_min_sync1, y_min_sync2;     // y_min同步（11位）
reg [10:0] y_max_sync1, y_max_sync2;     // y_max同步（11位）
reg [7:0] angle_th_sync1, angle_th_sync2;// angle阈值同步
reg [7:0] z_angle_th_sync1, z_angle_th_sync2;  // 两级同步消除亚稳态
reg [17:0] area_th_sync1, area_th_sync2;  // 两级同步消除亚稳态

// 2. 到pix_clk域（字符显示模块用，新增同步）
reg [7:0] bin_th_pix1, bin_th_pix2;      // 字符显示用bin_th同步
reg [7:0] sobel_th_pix1, sobel_th_pix2;  // 字符显示用sobel_th同步
reg [10:0] y_min_pix1, y_min_pix2;       // 字符显示用y_min同步
reg [10:0] y_max_pix1, y_max_pix2;       // 字符显示用y_max同步
reg [7:0] angle_th_pix1, angle_th_pix2;  // 字符显示用angle_th同步
reg [7:0] z_angle_th_pix1, z_angle_th_pix2;    // 两级同步
reg [17:0] area_th_pix1, area_th_pix2;

// 同步外部信号到pixclk_in域（两级同步，消抖+防亚稳态）
reg set_template_sync1, set_template_sync2;
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        set_template_sync1 <= 1'b0;
        set_template_sync2 <= 1'b0;
    end else begin
        set_template_sync1 <= set_template_flag;  // 一级同步
        set_template_sync2 <= set_template_sync1;  // 二级同步（最终同步后的值）
    end
end

// 检测同步后的上升沿（仅当从0→1时产生1个时钟周期的脉冲）
reg set_template_prev;
wire set_template_posedge;  // 上升沿脉冲（仅1拍有效）
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        set_template_prev <= 1'b0;
    end else begin
        set_template_prev <= set_template_sync2;  // 延迟1拍，用于边沿检测
    end
end
assign set_template_posedge = set_template_sync2 && !set_template_prev;  // 上升沿条件：当前1，前一拍0


// ------------------------------
// 同步到pixclk_in域（判断模块用）
// ------------------------------
always @(posedge pixclk_in or negedge rst_in) begin
    if (!rst_in) begin
        y_min_sync1 <= 11'd80;
        y_min_sync2 <= 11'd80;
        y_max_sync1 <= 11'd400;
        y_max_sync2 <= 11'd400;
        bin_th_sync1 <= 8'd65;
        bin_th_sync2 <= 8'd65;
        sobel_th_sync1 <= 8'd100;
        sobel_th_sync2 <= 8'd100;
        angle_th_sync1 <= 8'd45;
        angle_th_sync2 <= 8'd45;
        z_angle_th_sync1 <= 8'd45;
        z_angle_th_sync2 <= 8'd45;
        area_th_sync1 <= 18'd50;
        area_th_sync2 <= 18'd50;
    end else begin
        // y_min同步（11位，2拍延迟，匹配defect模块延迟）
        y_min_sync1 <= y_min_sys;
        y_min_sync2 <= y_min_sync1;
        // y_max同步（11位）
        y_max_sync1 <= y_max_sys;
        y_max_sync2 <= y_max_sync1;
        // 二值化阈值同步
        bin_th_sync1 <= bin_th_sys;
        bin_th_sync2 <= bin_th_sync1;
        // Sobel阈值同步
        sobel_th_sync1 <= sobel_th_sys;
        sobel_th_sync2 <= sobel_th_sync1;
        // angle阈值同步
        angle_th_sync1 <= angle_th_sys;
        angle_th_sync2 <= angle_th_sync1;
       //z_angle
        z_angle_th_sync1 <= z_angle_th_sys;
        z_angle_th_sync2 <= z_angle_th_sync1;
       //cca_area
        area_th_sync1 <= area_th_sys;
        area_th_sync2 <= area_th_sync1; 
    end
end

// ------------------------------
// 同步到pix_clk域（字符显示模块用，新增）
// ------------------------------
always @(posedge pix_clk or negedge rst_in) begin
    if (!rst_in) begin
        bin_th_pix1 <= 8'd65;
        bin_th_pix2 <= 8'd65;
        sobel_th_pix1 <= 8'd100;
        sobel_th_pix2 <= 8'd100;
        y_min_pix1 <= 11'd80;
        y_min_pix2 <= 11'd80;
        y_max_pix1 <= 11'd400;
        y_max_pix2 <= 11'd400;
        angle_th_pix1 <= 8'd45;
        angle_th_pix2 <= 8'd45;
        z_angle_th_pix1 <= 8'd45;
        z_angle_th_pix2 <= 8'd45;
        area_th_pix1 <= 18'd50;
        area_th_pix2 <= 18'd50;
    end else begin
        // 两级同步，消除亚稳态
        bin_th_pix1 <= bin_th_sys;
        bin_th_pix2 <= bin_th_pix1;
        
        sobel_th_pix1 <= sobel_th_sys;
        sobel_th_pix2 <= sobel_th_pix1;
        
        y_min_pix1 <= y_min_sys;
        y_min_pix2 <= y_min_pix1;
        
        y_max_pix1 <= y_max_sys;
        y_max_pix2 <= y_max_pix1;
        
        angle_th_pix1 <= angle_th_sys;
        angle_th_pix2 <= angle_th_pix1;

        z_angle_th_pix1 <= z_angle_th_sys;
        z_angle_th_pix2 <= z_angle_th_pix1;  // 同步后传给char_proc

        area_th_pix1 <= area_th_sys;
        area_th_pix2 <= area_th_pix1;

    end
end




//////////////////////////////////////////////////////////////////////////////////////////////////////////
//灰度化
wire    y_vs;
wire    y_de;
wire    y_hs;
wire    [7:0]    y_data;

RGB2YCbCr RGB2YCbCr_inst
    (
    .clk(pixclk_in),              // input
    .rst_n(rstn_out),          // input
    .vsync_in(vs_in),    // input
    .hsync_in(de_in),    // input
    .de_in(de_in),          // input
    .red(r_in[7:3]),              // input[4:0]
    .green(g_in[7:2]),          // input[5:0]
    .blue(b_in[7:3]),            // input[4:0]
    .vsync_out(y_vs),  // output
    .hsync_out(y_hs),  // output
    .de_out(y_de),        // output
    .y(y_data),                  // output[7:0]
    .cb(),                // output[7:0]
    .cr()                 // output[7:0]
);

//3x3矩阵
wire    [7:0]    matrix11_median;
wire    [7:0]    matrix12_median;
wire    [7:0]    matrix13_median;
                         
wire    [7:0]    matrix21_median;
wire    [7:0]    matrix22_median;
wire    [7:0]    matrix23_median;
    		          
wire    [7:0]    matrix31_median;
wire    [7:0]    matrix32_median;
wire    [7:0]    matrix33_median;
wire             matrix_de_median;

matrix_3x3#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_median_matrix_3x3(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out   ),
    .video_vs    ( y_vs        ),
    .video_de    ( y_de        ),
    .video_data  ( y_data      ),
    .matrix_de   ( matrix_de_median   ),
    .matrix11    ( matrix11_median    ),
    .matrix12    ( matrix12_median    ),
    .matrix13    ( matrix13_median    ),
    .matrix21    ( matrix21_median    ),
    .matrix22    ( matrix22_median    ),
    .matrix23    ( matrix23_median    ),
    .matrix31    ( matrix31_median    ),
    .matrix32    ( matrix32_median    ),
    .matrix33    ( matrix33_median    )
);                 
                   
wire    [7:0]    median_data;
wire             median_vs  ;
wire             median_de  ;
wire             median_hs  ;

median_filter_3x3 u_median_filter_3x3(
    .clk         ( pixclk_in         ),
    .rst_n       ( rstn_out       ),
    .vsync_in    ( y_vs    ),
    .hsync_in    ( matrix_de_median    ),
    .de_in       ( matrix_de_median       ),
    .data11      ( matrix11_median       ),
    .data12      ( matrix12_median       ),
    .data13      ( matrix13_median       ),
    .data21      ( matrix21_median       ),
    .data22      ( matrix22_median       ),
    .data23      ( matrix23_median       ),
    .data31      ( matrix31_median       ),
    .data32      ( matrix32_median       ),
    .data33      ( matrix33_median       ),
    .target_data ( median_data ),
    .vsync_out   ( median_vs   ),
    .hsync_out   ( median_hs   ),
    .de_out      ( median_de      )
);
//sobel+二值化：分支
wire    [7:0]    matrix11_sobel;
wire    [7:0]    matrix12_sobel;
wire    [7:0]    matrix13_sobel;
                         
wire    [7:0]    matrix21_sobel;
wire    [7:0]    matrix22_sobel;
wire    [7:0]    matrix23_sobel;
    		          
wire    [7:0]    matrix31_sobel;
wire    [7:0]    matrix32_sobel;
wire    [7:0]    matrix33_sobel;
wire             matrix_de_sobel;
matrix_3x3#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_sobel_matrix_3x3(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out   ),
    .video_vs    ( median_vs        ),
    .video_de    ( median_de        ),
    .video_data  ( median_data      ),
    .matrix_de   ( matrix_de_sobel   ),
    .matrix11    ( matrix11_sobel    ),
    .matrix12    ( matrix12_sobel),
    .matrix13    ( matrix13_sobel),
    .matrix21    ( matrix21_sobel),
    .matrix22    ( matrix22_sobel),
    .matrix23    ( matrix23_sobel),
    .matrix31    ( matrix31_sobel),
    .matrix32    ( matrix32_sobel),
    .matrix33    ( matrix33_sobel)
);

//sobel算子
wire    [7:0]    sobel_data;
wire             sobel_vs  ;
wire             sobel_de  ;
wire             sobel_hs  ;
sobel u_sobel(
    .video_clk  ( pixclk_in  ),
    .rst_n      ( rstn_out      ),
    .sobel_threshold(sobel_th_sync2     ),
    .matrix_de  ( matrix_de_sobel  ),
    .matrix_vs  ( median_vs  ),
    .matrix11   ( matrix11_sobel   ),
    .matrix12   ( matrix12_sobel   ),
    .matrix13   ( matrix13_sobel   ),
    .matrix21   ( matrix21_sobel   ),
    .matrix22   ( matrix22_sobel   ),
    .matrix23   ( matrix23_sobel   ),
    .matrix31   ( matrix31_sobel   ),
    .matrix32   ( matrix32_sobel   ),
    .matrix33   ( matrix33_sobel   ),
    .sobel_vs   ( sobel_vs   ),
    .sobel_de   ( sobel_de   ),
    .sobel_data  ( sobel_data  )
);

//二值化
wire    bin_de;
wire    bin_vs;
wire    bin_hs;
wire    bin_data;
binarization u_binarization(
    .clk        ( pixclk_in        ),
    .rst_n      ( rstn_out      ),
    .vsync_in   ( sobel_vs  ),  // sobel后场同步
    .hsync_in   ( sobel_de  ),  // sobel行同步
    .de_in      ( sobel_de  ),  // sobel数据使能
    .y_in       ( sobel_data ),  // sobel数据
    .bin_threshold  (bin_th_sync2   ),  // 传入动态阈值
    .vsync_out  ( bin_vs  ),
    .hsync_out  ( bin_hs  ),
    .de_out     ( bin_de     ),
    .pix        ( bin_data        )
);


//二值化+腐蚀：分支
wire    bin2_de;
wire    bin2_vs;
wire    bin2_hs;
wire    bin2_data;
binarization u_binarization_erosion(
    .clk        ( pixclk_in        ),
    .rst_n      ( rstn_out      ),
    .vsync_in   ( median_vs  ),  // 高斯滤波后场同步
    .hsync_in   ( median_hs  ),  // 延迟后行同步
    .de_in      ( median_de  ),  // 高斯滤波后数据使能
    .y_in       ( median_data ),  // 高斯滤波后灰度数据
    .bin_threshold  (bin_th_sync2   ),  // 传入动态阈值
    .vsync_out  ( bin2_vs  ),
    .hsync_out  ( bin2_hs  ),
    .de_out     ( bin2_de     ),
    .pix        ( bin2_data        )
);

wire [15:0] bin2_data_16bit;
assign bin2_data_16bit = {16{bin2_data}};


wire  [10:0] center_position_x;
wire  [10:0] center_position_y;
wire  [6:0]  angle;  // 7位角度（0~127对应0~180度）
wire  [6:0]  z_angle;
wire         point_vs;
wire         point_de;
wire         is_minus;
wire         defect_valid;
defect#(
    .IMG_WIDTH       ( 11'd640 ),
    .IMG_HEIGHT      ( 11'd480 ),
    .COORD_WID       ( 11      ),
    .TAN_REG_WID     ( 16      ),
    .ANGLE_WID       ( 7       ),
    .DELAY_CYCLES    ( 1       ),  // 延迟2拍（与阈值同步匹配）
    .SLOPE_THRESHOLD ( 1       )
)u_defect_coord(
    .pixclk_in         ( pixclk_in           ),
    .rstn_out          ( rstn_out            ),
    .bin2_vs           ( bin2_vs             ),
    .bin2_de           ( bin2_de             ),
    .bin2_data         ( bin2_data           ),
    .set_template_flag (set_template_posedge ),
    .center_position_x (center_position_x    ),
    .center_position_y (center_position_y    ),
    .angle             (angle                ),
    .z_angle           (z_angle              ),
    .point_vs          (point_vs             ),
    .point_de          (point_de             ),
    .is_minus          (is_minus             ),
    .defect_valid      (defect_valid         )
);

wire [23:0] center_position_x_24bit = {13'b0,center_position_x};
wire [23:0] center_position_y_24bit = {13'b0,center_position_y};
wire [23:0] angle_24bit = {17'b0,angle};
wire [23:0] z_angle_24bit = {17'b0,z_angle};

// ------------------------------
// 阈值判断模块（修复：添加边界约束）
// ------------------------------
wire                          y_th_flag       ;
wire                          angle_th_flag   ;
wire                          y_angle_vs_out  ;
wire                          y_angle_de_out  ;

y_angle_th_check#(
    .Y_DATA_WID    (11),    // 匹配center_position_y（11位）
    .ANGLE_DATA_WID(7),     // 匹配angle（7位）
    .TH_WID        (11)     // y_min/y_max为11位
)u_y_angle_th_check(
    .clk             (pixclk_in           ),
    .rst_n           (rstn_out            ),
    .y_data          (center_position_y   ),
    .angle_data      (angle               ),
    .y_min           (y_min_sync2         ),
    .y_max           (y_max_sync2         ),
    .angle_th        (angle_th_sync2      ),
    .vs_in           (point_vs            ),
    .de_in           (point_de            ),
    .y_th_flag       (y_th_flag           ),  // y < y_min 或 y > y_max 时高
    .angle_th_flag   (angle_th_flag       ),  // angle > angle_th 时高
    .vs_out          (y_angle_vs_out      ),
    .de_out          (y_angle_de_out      )
);

// GPIO输出（打1拍稳定）
//always @(posedge pixclk_in or negedge rst_in) begin
//    if (!rst_in) begin
//        gpio_y_th     <= 1'b0;
//        gpio_angle_th <= 1'b0;
//    end else begin
//        gpio_y_th     <= y_th_flag;
//        gpio_angle_th <= angle_th_flag;
//    end
//end
// ==================== 基于标志信号的方波生成器 ====================
// 使用2位计数器生成高频方波（时钟的1/4分频）
reg [1:0] square_wave_counter;
reg square_wave_output;
reg gpio_enable;  // 方波输出使能信号

// 当计数器达到特定值（如2'b10）后，输出锁定为高电平
always @(posedge pixclk_in or negedge rst_in) begin
    if (!rst_in) begin
        square_wave_counter <= 2'b00;
        square_wave_output <= 1'b0;
    end else begin
        square_wave_counter <= square_wave_counter + 1'b1;
        
        // 当计数器≥2时输出恒高（10和11状态）
        square_wave_output <= (square_wave_counter >= 2'b10) ? 1'b1 : 1'b0;
    end
end
// 方波输出使能逻辑：任一标志为1时使能方波输出
always @(*) begin
    gpio_enable = y_th_flag || angle_th_flag || is_defect  ;
end

// ==================== GPIO输出控制 ====================
always @(posedge pixclk_in or negedge rst_in) begin
    if (!rst_in) begin
        gpio_y_th     <= 1'b0;
        gpio_angle_th <= 1'b0;
    end else begin
        // 当使能有效时输出方波，否则输出低电平
        gpio_y_th     <= gpio_enable ? square_wave_output : 1'b0;//square_wave_output
        gpio_angle_th <= gpio_enable ? square_wave_output : 1'b0;//square_wave_output
        
        // 可选：如果您希望两个GPIO独立控制，可以使用以下代码：
        //gpio_y_th     <= y_th_flag ? square_wave_output : 1'b0;
        //gpio_angle_th <= angle_th_flag ? square_wave_output : 1'b0;
    end
end

//---------------腐蚀1--------------------------
//单bit可以不定义，默认单bit,故矩阵的单bit数据这里都不wire定义出来
//erosion1
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_erosion_1(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out   ),
    .video_vs    ( bin2_vs        ),
    .video_de    ( bin2_de        ),
    .video_data  ( bin2_data      ),
    .matrix_de   ( matrix_de_1bit_1   ),
    .matrix11    ( matrix11_1bit_1    ),
    .matrix12    ( matrix12_1bit_1    ),
    .matrix13    ( matrix13_1bit_1    ),
    .matrix21    ( matrix21_1bit_1    ),
    .matrix22    ( matrix22_1bit_1    ),
    .matrix23    ( matrix23_1bit_1    ),
    .matrix31    ( matrix31_1bit_1    ),
    .matrix32    ( matrix32_1bit_1    ),    
    .matrix33    ( matrix33_1bit_1    )
);

wire    erosion_vs_1;
wire    erosion_de_1;
wire    erosion_data_1;
   
erosion u_erosion_1(
    .video_clk    ( pixclk_in      ),
    .rst_n        ( rstn_out       ),
    .bin_vs       ( bin2_vs         ),
    .bin_de       ( matrix_de_1bit_1 ),
    .bin_data_11  ( matrix11_1bit_1  ),
    .bin_data_12  ( matrix12_1bit_1  ),
    .bin_data_13  ( matrix13_1bit_1  ),
    .bin_data_21  ( matrix21_1bit_1  ),
    .bin_data_22  ( matrix22_1bit_1  ),
    .bin_data_23  ( matrix23_1bit_1  ),
    .bin_data_31  ( matrix31_1bit_1  ),
    .bin_data_32  ( matrix32_1bit_1  ),
    .bin_data_33  ( matrix33_1bit_1  ),
    .erosion_vs   ( erosion_vs_1   ),
    .erosion_de   ( erosion_de_1   ),
    .erosion_data  ( erosion_data_1  )
);


//erosion2
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_erosion_2(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out        ),
    .video_vs    ( erosion_vs_1        ),
    .video_de    ( erosion_de_1        ),
    .video_data  ( erosion_data_1      ),
    .matrix_de   ( matrix_de_1bit_2   ),
    .matrix11    ( matrix11_1bit_2     ),
    .matrix12    ( matrix12_1bit_2     ),
    .matrix13    ( matrix13_1bit_2     ),
    .matrix21    ( matrix21_1bit_2     ),
    .matrix22    ( matrix22_1bit_2     ),
    .matrix23    ( matrix23_1bit_2     ),
    .matrix31    ( matrix31_1bit_2     ),
    .matrix32    ( matrix32_1bit_2     ),    
    .matrix33    ( matrix33_1bit_2     )
); 
 
wire    erosion_vs_2;
wire    erosion_de_2;
wire    erosion_data_2;
   
erosion u_erosion_2(
    .video_clk    ( pixclk_in      ),
    .rst_n        ( rstn_out       ),
    .bin_vs       ( erosion_vs_1         ),
    .bin_de       ( matrix_de_1bit_2  ),
    .bin_data_11  ( matrix11_1bit_2   ),
    .bin_data_12  ( matrix12_1bit_2   ),
    .bin_data_13  ( matrix13_1bit_2   ),
    .bin_data_21  ( matrix21_1bit_2   ),
    .bin_data_22  ( matrix22_1bit_2   ),
    .bin_data_23  ( matrix23_1bit_2   ),
    .bin_data_31  ( matrix31_1bit_2   ),
    .bin_data_32  ( matrix32_1bit_2   ),
    .bin_data_33  ( matrix33_1bit_2   ),
    .erosion_vs   ( erosion_vs_2   ),
    .erosion_de   ( erosion_de_2   ),
    .erosion_data  ( erosion_data_2  )
);

//erosion3
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_erosion_3(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out        ),
    .video_vs    ( erosion_vs_2        ),
    .video_de    ( erosion_de_2        ),
    .video_data  ( erosion_data_2      ),
    .matrix_de   ( matrix_de_1bit_3   ),
    .matrix11    ( matrix11_1bit_3     ),
    .matrix12    ( matrix12_1bit_3     ),
    .matrix13    ( matrix13_1bit_3     ),
    .matrix21    ( matrix21_1bit_3     ),
    .matrix22    ( matrix22_1bit_3     ),
    .matrix23    ( matrix23_1bit_3     ),
    .matrix31    ( matrix31_1bit_3     ),
    .matrix32    ( matrix32_1bit_3     ),    
    .matrix33    ( matrix33_1bit_3     )
); 
wire    erosion_vs_3;
wire    erosion_de_3;
wire    erosion_data_3;
   
erosion u_erosion_3(
    .video_clk    ( pixclk_in      ),
    .rst_n        ( rstn_out       ),
    .bin_vs       ( erosion_vs_2         ),
    .bin_de       ( matrix_de_1bit_3  ),
    .bin_data_11  ( matrix11_1bit_3   ),
    .bin_data_12  ( matrix12_1bit_3   ),
    .bin_data_13  ( matrix13_1bit_3   ),
    .bin_data_21  ( matrix21_1bit_3   ),
    .bin_data_22  ( matrix22_1bit_3   ),
    .bin_data_23  ( matrix23_1bit_3   ),
    .bin_data_31  ( matrix31_1bit_3   ),
    .bin_data_32  ( matrix32_1bit_3   ),
    .bin_data_33  ( matrix33_1bit_3   ),
    .erosion_vs   ( erosion_vs_3   ),
    .erosion_de   ( erosion_de_3   ),
    .erosion_data  ( erosion_data_3  )
);

//erosion4
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_erosion_4(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out        ),
    .video_vs    ( erosion_vs_3        ),
    .video_de    ( erosion_de_3        ),
    .video_data  ( erosion_data_3      ),
    .matrix_de   ( matrix_de_1bit_4   ),
    .matrix11    ( matrix11_1bit_4     ),
    .matrix12    ( matrix12_1bit_4     ),
    .matrix13    ( matrix13_1bit_4     ),
    .matrix21    ( matrix21_1bit_4     ),
    .matrix22    ( matrix22_1bit_4     ),
    .matrix23    ( matrix23_1bit_4     ),
    .matrix31    ( matrix31_1bit_4     ),
    .matrix32    ( matrix32_1bit_4     ),    
    .matrix33    ( matrix33_1bit_4     )
); 
wire    erosion_vs_4;
wire    erosion_de_4;
wire    erosion_data_4;
   
erosion u_erosion_4(
    .video_clk    ( pixclk_in      ),
    .rst_n        ( rstn_out       ),
    .bin_vs       ( erosion_vs_3         ),
    .bin_de       ( matrix_de_1bit_4  ),
    .bin_data_11  ( matrix11_1bit_4   ),
    .bin_data_12  ( matrix12_1bit_4   ),
    .bin_data_13  ( matrix13_1bit_4   ),
    .bin_data_21  ( matrix21_1bit_4   ),
    .bin_data_22  ( matrix22_1bit_4   ),
    .bin_data_23  ( matrix23_1bit_4   ),
    .bin_data_31  ( matrix31_1bit_4   ),
    .bin_data_32  ( matrix32_1bit_4   ),
    .bin_data_33  ( matrix33_1bit_4   ),
    .erosion_vs   ( erosion_vs_4   ),
    .erosion_de   ( erosion_de_4   ),
    .erosion_data  ( erosion_data_4  )
);


//erosion5
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_erosion_5(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out        ),
    .video_vs    ( erosion_vs_4        ),
    .video_de    ( erosion_de_4        ),
    .video_data  ( erosion_data_4      ),
    .matrix_de   ( matrix_de_1bit_5   ),
    .matrix11    ( matrix11_1bit_5     ),
    .matrix12    ( matrix12_1bit_5     ),
    .matrix13    ( matrix13_1bit_5     ),
    .matrix21    ( matrix21_1bit_5     ),
    .matrix22    ( matrix22_1bit_5     ),
    .matrix23    ( matrix23_1bit_5     ),
    .matrix31    ( matrix31_1bit_5     ),
    .matrix32    ( matrix32_1bit_5     ),    
    .matrix33    ( matrix33_1bit_5     )
); 
wire    erosion_vs_5;
wire    erosion_de_5;
wire    erosion_data_5;
   
erosion u_erosion_5(
    .video_clk    ( pixclk_in      ),
    .rst_n        ( rstn_out       ),
    .bin_vs       ( erosion_vs_4         ),
    .bin_de       ( matrix_de_1bit_5  ),
    .bin_data_11  ( matrix11_1bit_5   ),
    .bin_data_12  ( matrix12_1bit_5   ),
    .bin_data_13  ( matrix13_1bit_5   ),
    .bin_data_21  ( matrix21_1bit_5   ),
    .bin_data_22  ( matrix22_1bit_5   ),
    .bin_data_23  ( matrix23_1bit_5   ),
    .bin_data_31  ( matrix31_1bit_5   ),
    .bin_data_32  ( matrix32_1bit_5   ),
    .bin_data_33  ( matrix33_1bit_5   ),
    .erosion_vs   ( erosion_vs_5   ),
    .erosion_de   ( erosion_de_5   ),
    .erosion_data  ( erosion_data_5  )
);

//erosion6
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_erosion_6(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out        ),
    .video_vs    ( erosion_vs_5        ),
    .video_de    ( erosion_de_5        ),
    .video_data  ( erosion_data_5      ),
    .matrix_de   ( matrix_de_1bit_6   ),
    .matrix11    ( matrix11_1bit_6     ),
    .matrix12    ( matrix12_1bit_6     ),
    .matrix13    ( matrix13_1bit_6     ),
    .matrix21    ( matrix21_1bit_6     ),
    .matrix22    ( matrix22_1bit_6     ),
    .matrix23    ( matrix23_1bit_6     ),
    .matrix31    ( matrix31_1bit_6     ),
    .matrix32    ( matrix32_1bit_6     ),    
    .matrix33    ( matrix33_1bit_6     )
); 
wire    erosion_vs;
wire    erosion_de;
wire    erosion_data;
   
erosion u_erosion_6(
    .video_clk    ( pixclk_in      ),
    .rst_n        ( rstn_out       ),
    .bin_vs       ( erosion_vs_5         ),
    .bin_de       ( matrix_de_1bit_6  ),
    .bin_data_11  ( matrix11_1bit_6   ),
    .bin_data_12  ( matrix12_1bit_6   ),
    .bin_data_13  ( matrix13_1bit_6   ),
    .bin_data_21  ( matrix21_1bit_6   ),
    .bin_data_22  ( matrix22_1bit_6   ),
    .bin_data_23  ( matrix23_1bit_6   ),
    .bin_data_31  ( matrix31_1bit_6   ),
    .bin_data_32  ( matrix32_1bit_6   ),
    .bin_data_33  ( matrix33_1bit_6   ),
    .erosion_vs   ( erosion_vs   ),
    .erosion_de   ( erosion_de   ),
    .erosion_data  ( erosion_data  )
);
//FIFO

//bin_data先到
// 1. FIFO信号定义（连续读写，无复位相关信号）
wire        fifo_wr_en;                  // 写使能
wire        fifo_rd_en;                  // 读使能
wire [0:0]  fifo_wr_data = bin_data;     // 写数据：bin_data
wire [0:0]  fifo_rd_data;                // 读数据：缓存的bin_data
wire        fifo_wr_full;                // 满标志
wire        fifo_almost_full;            // 将满预警
wire        fifo_almost_empty;           // 将空预警

// 读写使能（防溢+防读空）
assign fifo_wr_en = bin_de & !fifo_wr_full & !fifo_almost_full;
assign fifo_rd_en = erosion_de & !fifo_almost_empty;

// FIFO例化
u_fifo_bin_erosion u_fifo_cache_bin (
  .clk              (pixclk_in),
  .rst              (1'b0),               // 连续读写无复位
  .wr_en            (fifo_wr_en),
  .wr_data          (fifo_wr_data),
  .wr_full          (fifo_wr_full),
  .almost_full      (fifo_almost_full),
  .rd_en            (fifo_rd_en),
  .rd_data          (fifo_rd_data),
  .almost_empty     (fifo_almost_empty),
  // 省略调试用信号
  .wr_water_level   (),
  .rd_empty         (),
  .rd_water_level   ()
);

// 相与结果（修正result_de：绑定FIFO读出有效+后到数据有效）
wire        result_data = fifo_rd_data & erosion_data;
wire        result_de = fifo_rd_en & erosion_de;  // 仅FIFO读有效+erosion有效时输出
wire        result_vs = erosion_vs;

//dilate膨胀
wire    dilate_vs;
wire    dilate_de;
wire    dilate_data;
matrix_3x3_1bit#(
    .IMG_WIDTH   ( 11'd640 ),
    .IMG_HEIGHT  ( 11'd480 )
)u_matrix_3x3_result(
    .video_clk   ( pixclk_in       ),
    .rst_n       ( rstn_out        ),
    .video_vs    ( result_vs        ),
    .video_de    ( result_de        ),
    .video_data  ( result_data      ),
    .matrix_de   ( matrix_de_result   ),
    .matrix11    ( matrix11_result     ),
    .matrix12    ( matrix12_result     ),
    .matrix13    ( matrix13_result     ),
    .matrix21    ( matrix21_result     ),
    .matrix22    ( matrix22_result     ),
    .matrix23    ( matrix23_result     ),
    .matrix31    ( matrix31_result     ),
    .matrix32    ( matrix32_result     ),    
    .matrix33    ( matrix33_result     )
); 

dilate u_dilate(
    .video_clk    ( pixclk_in    ),
    .rst_n        ( rstn_out        ),
    .bin_vs       ( result_vs       ),
    .bin_de       ( matrix_de_result   ),
    .bin_data_11  ( matrix11_result  ),
    .bin_data_12  ( matrix12_result  ),
    .bin_data_13  ( matrix13_result  ),
    .bin_data_21  ( matrix21_result  ),
    .bin_data_22  ( matrix22_result  ),
    .bin_data_23  ( matrix23_result  ),
    .bin_data_31  ( matrix31_result  ),
    .bin_data_32  ( matrix32_result  ),
    .bin_data_33  ( matrix33_result  ),
    .dilate_vs    ( dilate_vs    ),
    .dilate_de    ( dilate_de    ),
    .dilate_data  ( dilate_data  )
);

wire write_data_vs = dilate_vs;
wire write_data_de = dilate_de;
// 定义延迟寄存器（3级移位寄存器，实现3个时钟周期延迟）
reg [4:0] vs_delay_chain;  // vs信号延迟链（[0]：1拍延迟，[1]：2拍延迟，[2]：3拍延迟）
reg [4:0] de_delay_chain;  // de信号延迟链

// 时钟沿触发移位，实现延迟
always @(posedge pixclk_in or negedge rstn_out) begin  // 假设使用pixclk_in作为时钟，rstn_out为复位
    if (!rstn_out) begin
        // 复位时延迟链清零，避免不定态
        vs_delay_chain <= 5'b00000;
        de_delay_chain <= 5'b00000;
    end else begin
        // 每时钟沿移位：新数据从最低位进入，逐级传递到高位
        vs_delay_chain <= {vs_delay_chain[3:0], write_data_vs};  // 右移，最高位[4]为5拍延迟
        de_delay_chain <= {de_delay_chain[3:0], write_data_de};
    end
end

// 延迟3个时钟周期后的输出信号
wire write_data_vs_dly5 = vs_delay_chain[4];  // 取延迟链最高位，即3拍延迟后的值
wire write_data_de_dly5 = de_delay_chain[4];
wire [15:0] write_data_16bit  = {16{dilate_data}};


//连通域

wire           LinkRunCCA_de;
wire [37:0]    LinkRunCCA_data;

LinkRunCCA
    #(
    .imheight(11'd480),
    .imwidth (11'd640)
    )u_LinkRunCCA
    (
    .clk(pixclk_in),                      // input
    .rst(~rstn_out),                      // input
    .datavalid(dilate_de),          // input
    .pix_in(dilate_data),                // input
    .area_th(area_th_sync2),              // input[18:0]
    .datavalid_out(LinkRunCCA_de),  // output
    .box_out(LinkRunCCA_data)               // output[37:0]
);



wire [3:0]   box_count;
wire [379:0] box_all;

box_merger #(
    .MAX_BOX_NUM(10)
) u_box_merger (
    .clk(pixclk_in),
    .rst_n(rstn_out),
    .vs_in(~dilate_vs),       // ✅ 必须一致
    .eoc_in(LinkRunCCA_de),
    .box_in(LinkRunCCA_data),
    .box_count_out(box_count),
    .box_all_out(box_all)
);

wire is_defect = (box_count > 4'd0) ? 1'b1 : 1'b0;

// ==================== 1. vs 跨时钟同步 (pixclk_in → pix_clk) ====================
reg vs_sync1, vs_sync2;
always @(posedge pix_clk or negedge ddr_init_done) begin
    if (!ddr_init_done) begin
        vs_sync1 <= 1'b0;
        vs_sync2 <= 1'b0;
    end else begin
        vs_sync1 <= ~dilate_vs;  // ✅ 使用与 box_merger 完全一致的信号
        vs_sync2 <= vs_sync1;
    end
end

// ✅ 产生 "上升沿脉冲"（只持续一个 pixel clock）
wire frame_start_pix = vs_sync1 & ~vs_sync2;


// ==================== 2. box_count 一帧锁存 ====================
reg [3:0] box_count_latch;
always @(posedge pix_clk or negedge ddr_init_done) begin
    if (!ddr_init_done)
        box_count_latch <= 4'd0;
    else if (frame_start_pix)          // ✅ 只在帧开始更新
        box_count_latch <= box_count;
end


// ==================== 3. box_all 一帧锁存 ====================
reg [379:0] box_all_latch;
always @(posedge pix_clk or negedge ddr_init_done) begin
    if (!ddr_init_done)
        box_all_latch <= 380'd0;
    else if (frame_start_pix)          //  一帧只锁存一次，整帧稳定使用
        box_all_latch <= box_all;
end


// ------------------------------
// 切换后的数据信号（输出到fram_buf）（三种模式进行切换）
// ------------------------------
wire        wr_fsync_sel;  // 切换后的帧同步（均取反，统一逻辑）
wire        wr_en_sel;     // 切换后的数据有效
wire [15:0] wr_data_sel;   // 切换后的16位像素数据

assign wr_fsync_sel = (data_sel == 2'b00) ? ~vs_in        // 原数据：~vs_in
                    : (data_sel == 2'b01) ? ~write_data_vs_dly5    // 新数据1：~result_vs
                    : ~bin2_vs;                       // 新数据2：~bin2_vs（统一取反）

assign wr_en_sel    = (data_sel == 2'b00) ? de_in         // 原数据：de_in
                    : (data_sel == 2'b01) ? write_data_de_dly5    // 新数据1：result_de
                    : bin2_de;                        // 新数据2：bin2_de

assign wr_data_sel  = (data_sel == 2'b00) ? hdmi_data_in  // 原数据：hdmi_data_in（16位）
                    : (data_sel == 2'b01) ? write_data_16bit  // 新数据1：write_data_result（16位）
                    : bin2_data_16bit;                     // 新数据2：扩展后的bin2_data（16位）

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//修改ddr读写模块v1
    fram_buf #(
    .H_NUM                (12'd640),
    .V_NUM                (12'd480)
    )fram_buf(
        .ddr_clk        (  core_clk             ),//input                         ddr_clk,
        .ddr_rstn       (  ddr_init_done        ),//input                         ddr_rstn,
        //data_in                                  
        .vin_clk        (  pixclk_in         ),//input                         vin_clk,
        .wr_fsync       (  wr_fsync_sel           ),//input                         wr_fsync,//~vs_in  ~result_vs
        .wr_en          (  wr_en_sel           ),//input                         wr_en,    //de_in   result_de 
        .wr_data        (  wr_data_sel            ),//input  [15 : 0]  wr_data,//hdmi_data_in  write_data_result
        //data_out
        .vout_clk       (  pix_clk              ),//input                         vout_clk,
        .rd_fsync       (  vs_reg               ),//input                         rd_fsync,
        .rd_en          (  rd_en                ),//input                         rd_en,
        .vout_de        (  de_o               ),//output                        vout_de,
        .vout_data      (  o_rgb565             ),//output [PIX_WIDTH- 1'b1 : 0]  vout_data,
        .init_done      (  init_done            ),//output reg                    init_done,
        //axi bus
        .axi_awaddr     (  axi_awaddr           ),// output[27:0]
        .axi_awid       (  axi_awuser_id        ),// output[3:0]
        .axi_awlen      (  axi_awlen            ),// output[3:0]
        .axi_awsize     (                       ),// output[2:0]
        .axi_awburst    (                       ),// output[1:0]
        .axi_awready    (  axi_awready          ),// input
        .axi_awvalid    (  axi_awvalid          ),// output               
        .axi_wdata      (  axi_wdata            ),// output[255:0]
        .axi_wstrb      (  axi_wstrb            ),// output[31:0]
        .axi_wlast      (  axi_wusero_last      ),// input
        .axi_wvalid     (                       ),// output
        .axi_wready     (  axi_wready           ),// input
        .axi_bid        (  4'd0                 ),// input[3:0]
        .axi_araddr     (  axi_araddr           ),// output[27:0]
        .axi_arid       (  axi_aruser_id        ),// output[3:0]
        .axi_arlen      (  axi_arlen            ),// output[3:0]
        .axi_arsize     (                       ),// output[2:0]
        .axi_arburst    (                       ),// output[1:0]
        .axi_arvalid    (  axi_arvalid          ),// output
        .axi_arready    (  axi_arready          ),// input
        .axi_rready     (                       ),// output
        .axi_rdata      (  axi_rdata            ),// input[255:0]
        .axi_rvalid     (  axi_rvalid           ),// input
        .axi_rlast      (  axi_rlast            ),// input
        .axi_rid        (  axi_rid              ) // input[3:0]         
    );


parameter  color_d = 24'h9B30FF;//9B30FF    紫色
wire    [7:0]    rgb_data_r;
wire    [7:0]    rgb_data_g;
wire    [7:0]    rgb_data_b;

assign    rgb_data_r = o_rgb?color_d[23:16]:{o_rgb565[15:11],3'd0} ;
assign    rgb_data_g = o_rgb?color_d[15:8]:{o_rgb565[10:5],2'd0} ;
assign    rgb_data_b = o_rgb?color_d[7:0]:{o_rgb565[4:0],3'd0} ;


always  @(posedge pix_clk)begin


        vs_out       <=  vs_reg        ;
        hs_out       <=  hs_reg        ;
        de_out       <=  o_de           ;
        r_out        <=  rgb_data_r    ;
        g_out        <=  rgb_data_g    ;
        b_out        <=  rgb_data_b    ;

end
/////////////////////////////////////////////////////////////////////////////////////
//产生visa时序 
wire                        hs         ;
wire                        vs         ;
wire                        de         ;
//MODE_1080p
parameter V_TOTAL = 12'd525;  //场扫描周期Ver Total Time
parameter V_FP = 12'd2;        //场显示前沿V Front Porch
parameter V_BP = 12'd25;       //场显示后沿V Back Porch
parameter V_SYNC = 12'd2;      //场同步Ver Sync Time
parameter V_ACT = 12'd480;    //场有效数据Ver Addr Time
parameter H_TOTAL = 12'd800;  //行扫描周期Hor Total Time
parameter H_FP = 12'd16;       //行显示前沿H Front Porch
parameter H_BP = 12'd48;      //行显示后沿H Back Porch
parameter H_SYNC = 12'd96;     //行同步Hor Sync Time
parameter H_ACT = 12'd640;    //行数据有效Hor Addr Time
parameter HV_OFFSET = 12'd0;   
parameter   X_WIDTH = 4'd12;
parameter   Y_WIDTH = 4'd12; 
wire [X_WIDTH - 1'b1:0]     act_x      ;
wire [Y_WIDTH - 1'b1:0]     act_y      ;  
sync_vg #(
    .X_BITS               (  X_WIDTH              ), 
    .Y_BITS               (  Y_WIDTH              ),
    .V_TOTAL              (  V_TOTAL              ),//                        
    .V_FP                 (  V_FP                 ),//                        
    .V_BP                 (  V_BP                 ),//                        
    .V_SYNC               (  V_SYNC               ),//                        
    .V_ACT                (  V_ACT                ),//                        
    .H_TOTAL              (  H_TOTAL              ),//                        
    .H_FP                 (  H_FP                 ),//                        
    .H_BP                 (  H_BP                 ),//                        
    .H_SYNC               (  H_SYNC               ),//                        
    .H_ACT                (  H_ACT                ) //                        

) sync_vg                                         
(                                                 
    .clk                  (  pix_clk               ),//input                   clk,                                 
    .rstn                 (  ddr_init_done                 ),//input                   rstn,                            
    .vs_out               (  vs_reg                   ),//output reg              vs_out,                                                                                                                                      
    .hs_out               (  hs_reg                   ),//output reg              hs_out,            
    .de_out               (  rd_en                   ),//output reg              de_out,             
    .x_act                (  act_x                ),//output reg [X_BITS-1:0] x_out,             
    .y_act                (  act_y                ) //output reg [Y_BITS:0]   y_out,             
); 


////////////////////////////////////////////////////////////////////////////////////////////

//字符叠加
wire    o_rgb;    //标志位
wire    o_de;


// ==================== 字符显示模块实例化（修复：传入pix_clk域同步后的阈值） ====================
char_proc #(
    .CHAR_HEIGHT(12'd8),                                     // 字符高度
    .CHAR_WIDTH(12'd8),                                      // 字符宽度
    .DIGIT_LEN(4),                                           // 数字位数                                      
    .CHAR_X_MODE(12'd15),    .CHAR_Y_MODE(12'd15),           //mode
    .CHAR_X_BIN(12'd15),    .CHAR_Y_BIN(12'd30),             //bin_th
    .CHAR_X_SOBEL(12'd15),  .CHAR_Y_SOBEL(12'd45),           //sobel_th
    .CHAR_X_YMIN(12'd15),    .CHAR_Y_YMIN(12'd60),           //y_min
    .CHAR_X_YMAX(12'd15),   .CHAR_Y_YMAX(12'd75),            //y_max
    .CHAR_X_ANGLETH(12'd15), .CHAR_Y_ANGLETH(12'd90),        //angle_th
    .CHAR_X_X(12'd200),       .CHAR_Y_X(12'd15),             //center_position_x
    .CHAR_X_Y(12'd200),      .CHAR_Y_Y(12'd30),              //center_position_y
    .CHAR_X_ANGLE(12'd200),  .CHAR_Y_ANGLE(12'd45),          //angle
    .CHAR_X_Z_ANGLE (12'd200), .CHAR_Y_Z_ANGLE (12'd60),     //z_angle
    .SCREEN_W(12'd640),        .SCREEN_H(12'd480),           //width,length
    .CHAR_X_AREATH(12'd15),    .CHAR_Y_AREATH(12'd105),      //cca_area
    .CHAR_X_Z_ANGLETH (12'd15),.CHAR_Y_Z_ANGLETH (12'd120),  // z_angle_th起始Y（AngleTh下方25像素）
    .CROSS_LENGTH(12'd5)
) u_char_proc (
    .pix_clk(pix_clk),
    .rst_n(ddr_init_done),
    .i_de(de_o),
    .x_act(act_x),
    .y_act(act_y),
    .distance_mm(center_position_x_24bit),//
    .distance_mm_2(center_position_y_24bit),//
    .distance_mm_3(angle_24bit),//
    .z_angle (z_angle_24bit),
    .angle(is_minus),
    .curr_mode(curr_mode),
    // 关键修改：传入同步后的box信号
    .box_count_out(box_count_latch),
    .box_all(box_all_latch),    // 锁存后的380位数据（pix_clk域）
    .bin_th(bin_th_pix2),         // 同步后的值
    .sobel_th(sobel_th_pix2),
    .y_min(y_min_pix2),//
    .y_max(y_max_pix2),//
    .angle_th(angle_th_pix2),
    .z_angle_th(z_angle_th_pix2),
    .area_th(area_th_pix2),
    .o_de(o_de),
    .o_rgb(o_rgb)
);

wire clk_125Mhz ;

GTP_INBUFGDS #(
    .IOSTANDARD("DEFAULT"),
    .TERM_DIFF("ON")
) u_gtp (
    .O(clk_125Mhz), // OUTPUT  
    .I(clk_p), // INPUT  
    .IB(clk_n) // INPUT  
);

//ddr    
        ddr3_test u_ddr3_test_h (
             .ref_clk                   (clk_125Mhz            ),
             .resetn                    (rstn_out           ),// input
             .ddr_init_done             (ddr_init_done      ),// output

             .pll_lock                  (pll_lock           ),// output

             .core_clk                  (core_clk),                                  // output

             .phy_pll_lock              (phy_pll_lock),                          // output
             .gpll_lock                 (gpll_lock),                                // output
             .rst_gpll_lock             (rst_gpll_lock),                        // output
             .ddrphy_cpd_lock           (ddrphy_cpd_lock),                    // output
             //.ddr_init_done             (ddr_init_done),                        // output


             .axi_awaddr                (axi_awaddr         ),// input [27:0]
             .axi_awuser_ap             (1'b0               ),// input
             .axi_awuser_id             (axi_awuser_id      ),// input [3:0]
             .axi_awlen                 (axi_awlen          ),// input [3:0]
             .axi_awready               (axi_awready        ),// output
             .axi_awvalid               (axi_awvalid        ),// input
             .axi_wdata                 (axi_wdata          ),
             .axi_wstrb                 (axi_wstrb          ),// input [31:0]
             .axi_wready                (axi_wready         ),// output
             .axi_wusero_id             (                   ),// output [3:0]
             .axi_wusero_last           (axi_wusero_last    ),// output
             .axi_araddr                (axi_araddr         ),// input [27:0]
             .axi_aruser_ap             (1'b0               ),// input
             .axi_aruser_id             (axi_aruser_id      ),// input [3:0]
             .axi_arlen                 (axi_arlen          ),// input [3:0]
             .axi_arready               (axi_arready        ),// output
             .axi_arvalid               (axi_arvalid        ),// input
             .axi_rdata                 (axi_rdata          ),// output [255:0]
             .axi_rid                   (axi_rid            ),// output [3:0]
             .axi_rlast                 (axi_rlast          ),// output
             .axi_rvalid                (axi_rvalid         ),// output

             .apb_clk                   (1'b0               ),// input
             .apb_rst_n                 (1'b1               ),// input
             .apb_sel                   (1'b0               ),// input
             .apb_enable                (1'b0               ),// input
             .apb_addr                  (8'b0               ),// input [7:0]
             .apb_write                 (1'b0               ),// input
             .apb_ready                 (                   ), // output
             .apb_wdata                 (16'b0              ),// input [15:0]
             .apb_rdata                 (                   ),// output [15:0]
//             .apb_int                   (                   ),// output

             .mem_rst_n                 (mem_rst_n          ),// output
             .mem_ck                    (mem_ck             ),// output
             .mem_ck_n                  (mem_ck_n           ),// output
             .mem_cke                   (mem_cke            ),// output
             .mem_cs_n                  (mem_cs_n           ),// output
             .mem_ras_n                 (mem_ras_n          ),// output
             .mem_cas_n                 (mem_cas_n          ),// output
             .mem_we_n                  (mem_we_n           ),// output
             .mem_odt                   (mem_odt            ),// output
             .mem_a                     (mem_a              ),// output [14:0]
             .mem_ba                    (mem_ba             ),// output [2:0]
             .mem_dqs                   (mem_dqs            ),// inout [3:0]
             .mem_dqs_n                 (mem_dqs_n          ),// inout [3:0]
             .mem_dq                    (mem_dq             ),// inout [31:0]
             .mem_dm                    (mem_dm             ),// output [3:0]
             //debug

  .dbg_gate_start(1'b0),                      // input
  .dbg_cpd_start(1'b0),                        // input
  .dbg_ddrphy_rst_n(1'b1),                  // input
  .dbg_gpll_scan_rst(1'b0),                // input
  .samp_position_dyn_adj(1'b0),        // input
  .init_samp_position_even(32'd0),    // input [31:0]
  .init_samp_position_odd(32'd0),      // input [31:0]
  .wrcal_position_dyn_adj(1'b0),      // input
  .init_wrcal_position(32'd0),            // input [31:0]
  .force_read_clk_ctrl(1'b0),            // input
  .init_slip_step(16'd0),                      // input [15:0]
  .init_read_clk_ctrl(12'd0),              // input [11:0]
  .debug_calib_ctrl(),                  // output [33:0]
  .dbg_slice_status(),                  // output [67:0]
  .dbg_slice_state(),                    // output [87:0]
  .debug_data(),                              // output [275:0]
  .dbg_dll_upd_state(),                // output [1:0]
  .debug_gpll_dps_phase(),          // output [8:0]
  .dbg_rst_dps_state(),                // output [2:0]
  .dbg_tran_err_rst_cnt(),          // output [5:0]
  .dbg_ddrphy_init_fail(),          // output
  .debug_cpd_offset_adj(1'b0),          // input
  .debug_cpd_offset_dir(1'b0),          // input
  .debug_cpd_offset(10'd0),                  // input [9:0]
  .debug_dps_cnt_dir0(),              // output [9:0]
  .debug_dps_cnt_dir1(),              // output [9:0]
  .ck_dly_en(1'b0),                                // input
  .init_ck_dly_step(8'h0),                  // input [7:0]
  .ck_dly_set_bin(),                      // output [7:0]
  .align_error(),                            // output
  .debug_rst_state(),                    // output [3:0]
  .debug_cpd_state()                     // output [3:0]
       );

//心跳信号
     always@(posedge core_clk) begin
        if (!ddr_init_done)
            cnt <= 27'd0;
        else if ( cnt >= TH_1S )
            cnt <= 27'd0;
        else
            cnt <= cnt + 27'd1;
     end

     always @(posedge core_clk)
        begin
        if (!ddr_init_done)
            heart_beat_led <= 1'd1;
        else if ( cnt >= TH_1S )
            heart_beat_led <= ~heart_beat_led;
    end
                 
/////////////////////////////////////////////////////////////////////////////////////
endmodule
