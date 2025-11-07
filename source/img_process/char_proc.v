
`timescale 1ns / 1ps

module char_proc#(
    // ==================== 显示区域配置 ====================
    parameter CHAR_X_MODE    = 12'd15,    // 模式显示起始X
    parameter CHAR_Y_MODE    = 12'd15,    // 模式显示起始Y
    parameter CHAR_X_BIN     = 12'd200,   // 二值化阈值起始X
    parameter CHAR_Y_BIN     = 12'd15,    // 二值化阈值起始Y
    parameter CHAR_X_SOBEL   = 12'd350,   // Sobel阈值起始X
    parameter CHAR_Y_SOBEL   = 12'd15,    // Sobel阈值起始Y
    parameter CHAR_X_YMIN    = 12'd15,    // YMin阈值起始X
    parameter CHAR_Y_YMIN    = 12'd40,    // YMin阈值起始Y
    parameter CHAR_X_YMAX    = 12'd200,   // YMax阈值起始X
    parameter CHAR_Y_YMAX    = 12'd40,    // YMax阈值起始Y
    parameter CHAR_X_ANGLETH = 12'd350,   // AngleTh阈值起始X
    parameter CHAR_Y_ANGLETH = 12'd40,    // AngleTh阈值起始Y
// 新增：z_angle_th显示参数（仿照AngleTh，Y坐标设为65，避免与AngleTh重叠）
    parameter CHAR_X_Z_ANGLETH = 12'd15, // z_angle_th起始X（与AngleTh对齐）
    parameter CHAR_Y_Z_ANGLETH = 12'd90,  // z_angle_th起始Y（AngleTh下方25像素）
    parameter CHAR_X_X       = 12'd15,    // X坐标显示起始X
    parameter CHAR_Y_X       = 12'd65,    // X坐标显示起始Y
    parameter CHAR_X_Y       = 12'd200,   // Y坐标显示起始X
    parameter CHAR_Y_Y       = 12'd65,    // Y坐标显示起始Y
    parameter CHAR_X_ANGLE   = 12'd350,   // Angle显示起始X
    parameter CHAR_Y_ANGLE   = 12'd65,    // Angle显示起始Y
    parameter CHAR_X_Z_ANGLE = 12'd200,   // Z_Angle起始X
    parameter CHAR_Y_Z_ANGLE = 12'd90,    // Z_Angle起始Y

    // ==================== 基础参数 ====================
    parameter CHAR_HEIGHT    = 12'd8,     // 字符高度
    parameter CHAR_WIDTH     = 12'd8,     // 字符宽度
    parameter DIGIT_LEN      = 4,         // 数字位数
    parameter CROSS_LENGTH   = 12'd5,     // 十字线长度
    parameter SCREEN_W       = 12'd640,   // 屏幕宽度
    parameter SCREEN_H       = 12'd480,   // 屏幕高度
// 新增：AreaTh阈值显示坐标（避开已有区域，放在z_angle_th下方）
    parameter CHAR_X_AREATH    = 12'd15,    // AreaTh起始X（与z_angle_th对齐）
    parameter CHAR_Y_AREATH    = 12'd115,   // AreaTh起始Y（z_angle_th下方25像素）
    //box_merge输入
    parameter MAX_BOX_NUM    =  10
)(
    input              pix_clk,         // 像素时钟
    input              rst_n,           // 复位
    input              i_de,            // 输入数据有效
    input [11:0]       x_act,           // 当前X坐标
    input [11:0]       y_act,           // 当前Y坐标

    // 数据输入
    input [23:0]       distance_mm,     // X坐标数据
    input [23:0]       distance_mm_2,   // Y坐标数据
    input [23:0]       distance_mm_3,   // Angle数据
    input              angle,           // Angle符号
    input [23:0]       z_angle,         // Z_Angle数据
    input [2:0]        curr_mode,       // 当前模式
    input [7:0]        bin_th,          // 二值化阈值
    input [7:0]        sobel_th,        // Sobel阈值
    input [7:0]        y_min,           // Y最小值
    input [10:0]       y_max,           // Y最大值
    input [7:0]        angle_th,        // 角度阈值
    input [7:0]        z_angle_th,
    input [17:0]       area_th,          // 新增：连通域最小面积阈值（18位，0~131071）
    input [MAX_BOX_NUM*38-1:0] box_all,  // 来自 bbox_collect
    input [3:0]        box_count_out,

    output reg         o_de,            // 输出数据有效
    output reg         o_rgb            // 输出像素
);

// ==================== 1. 字模声明区域 ====================
// 基本字符字模
wire [7:0] char_a [7:0];      // a
wire [7:0] char_n [7:0];      // n  
wire [7:0] char_g [7:0];      // g
wire [7:0] char_l [7:0];      // l
wire [7:0] char_e [7:0];      // e
wire [7:0] char_colon [7:0];  // ：
wire [7:0] char_x [7:0];      // x
wire [7:0] char_y [7:0];      // y
wire [7:0] char_plus [7:0];   // +
wire [7:0] char_minus [7:0];  // -

// 新增字符字模
wire [7:0] char_M [7:0];      // M
wire [7:0] char_o [7:0];      // o
wire [7:0] char_d [7:0];      // d
wire [7:0] char_B [7:0];      // B
wire [7:0] char_i [7:0];      // i
wire [7:0] char_S [7:0];      // S
wire [7:0] char_T [7:0];      // T
wire [7:0] char_h [7:0];      // h
wire [7:0] char_Y [7:0];      // Y
wire [7:0] char_A [7:0];      // A
wire [7:0] char_r [7:0];      // r
wire [7:0] char_c [7:0];      // c
wire [7:0] char_u [7:0];      // u
wire [7:0] char_m [7:0];      // m
wire [7:0] char_b [7:0];      // b
wire [7:0] char_z [7:0];      //z
// 数字字模
wire [7:0] digit_0 [7:0];
wire [7:0] digit_1 [7:0];
wire [7:0] digit_2 [7:0];
wire [7:0] digit_3 [7:0];
wire [7:0] digit_4 [7:0];
wire [7:0] digit_5 [7:0];
wire [7:0] digit_6 [7:0];
wire [7:0] digit_7 [7:0];
wire [7:0] digit_8 [7:0];
wire [7:0] digit_9 [7:0];

// ==================== 1. 字模声明（仅保留用户提供的15个新字模+原有必要字符） ====================
// 新字模（用户提供：M、o、d、B、i、S、T、h、Y、A、r、c、u、m、b）
wire [7:0] char_M [7:0];      // M（索引10）
wire [7:0] char_o [7:0];      // o（索引11）
wire [7:0] char_d [7:0];      // d（索引12）
wire [7:0] char_B [7:0];      // B（索引13）
wire [7:0] char_i [7:0];      // i（索引14）
wire [7:0] char_S [7:0];      // S（索引15）
wire [7:0] char_T [7:0];      // T（索引16）
wire [7:0] char_h [7:0];      // h（索引17）
wire [7:0] char_Y [7:0];      // Y（索引18）
wire [7:0] char_A [7:0];      // A（索引19）
wire [7:0] char_r [7:0];      // r（索引20）
wire [7:0] char_c [7:0];      // c（索引21）
wire [7:0] char_u [7:0];      // u（索引22）
wire [7:0] char_m [7:0];      // m（索引23）
wire [7:0] char_b [7:0];      // b（索引24）

// 原有必要字符（a、n、g、l、e、：、x、y、+、-、数字0~9）
wire [7:0] char_a [7:0];      // a（索引0）
wire [7:0] char_n [7:0];      // n（索引1）
wire [7:0] char_g [7:0];      // g（索引2）
wire [7:0] char_l [7:0];      // l（索引3）
wire [7:0] char_e [7:0];      // e（索引4）
wire [7:0] char_colon [7:0];  // ：（索引5）
wire [7:0] char_x [7:0];      // x（索引6）
wire [7:0] char_y [7:0];      // y（索引7）
wire [7:0] char_plus [7:0];   // +（索引8）
wire [7:0] char_minus [7:0];  // -（索引9）

// 数字字模（保留原有，用户未修改）
wire [7:0] digit_0 [7:0];
wire [7:0] digit_1 [7:0];
wire [7:0] digit_2 [7:0];
wire [7:0] digit_3 [7:0];
wire [7:0] digit_4 [7:0];
wire [7:0] digit_5 [7:0];
wire [7:0] digit_6 [7:0];
wire [7:0] digit_7 [7:0];
wire [7:0] digit_8 [7:0];
wire [7:0] digit_9 [7:0];

// ==================== 2. 字模赋值（严格按用户提供的新字模，逐行对应） ====================
// 用户提供新字模：每行对应8个十六进制数（00~FF），共8行
// M: 00、00、46、66、6A、52、52、00
assign char_M[0] = 8'h00; assign char_M[1] = 8'h00; assign char_M[2] = 8'h46;
assign char_M[3] = 8'h66; assign char_M[4] = 8'h6A; assign char_M[5] = 8'h52;
assign char_M[6] = 8'h52; assign char_M[7] = 8'h00;

// o: 00、00、00、3C、42、42、3C、00
assign char_o[0] = 8'h00; assign char_o[1] = 8'h00; assign char_o[2] = 8'h00;
assign char_o[3] = 8'h3C; assign char_o[4] = 8'h42; assign char_o[5] = 8'h42;
assign char_o[6] = 8'h3C; assign char_o[7] = 8'h00;

// d: 00、02、02、3E、42、42、3F、00
assign char_d[0] = 8'h00; assign char_d[1] = 8'h02; assign char_d[2] = 8'h02;
assign char_d[3] = 8'h3E; assign char_d[4] = 8'h42; assign char_d[5] = 8'h42;
assign char_d[6] = 8'h3F; assign char_d[7] = 8'h00;

// B: 00、00、7E、46、7A、42、7E、00
assign char_B[0] = 8'h00; assign char_B[1] = 8'h00; assign char_B[2] = 8'h7E;
assign char_B[3] = 8'h46; assign char_B[4] = 8'h7A; assign char_B[5] = 8'h42;
assign char_B[6] = 8'h7E; assign char_B[7] = 8'h00;

// i: 00、18、00、78、18、18、7E、00
assign char_i[0] = 8'h00; assign char_i[1] = 8'h18; assign char_i[2] = 8'h00;
assign char_i[3] = 8'h78; assign char_i[4] = 8'h18; assign char_i[5] = 8'h18;
assign char_i[6] = 8'h7E; assign char_i[7] = 8'h00;

// S: 00、3C、42、70、0C、02、7C、00
assign char_S[0] = 8'h00; assign char_S[1] = 8'h3C; assign char_S[2] = 8'h42;
assign char_S[3] = 8'h70; assign char_S[4] = 8'h0C; assign char_S[5] = 8'h02;
assign char_S[6] = 8'h7C; assign char_S[7] = 8'h00;

// T: 00、00、FE、10、10、10、18、00
assign char_T[0] = 8'h00; assign char_T[1] = 8'h00; assign char_T[2] = 8'hFE;
assign char_T[3] = 8'h10; assign char_T[4] = 8'h10; assign char_T[5] = 8'h10;
assign char_T[6] = 8'h18; assign char_T[7] = 8'h00;

// h: 00、40、40、7C、42、42、42、00
assign char_h[0] = 8'h00; assign char_h[1] = 8'h40; assign char_h[2] = 8'h40;
assign char_h[3] = 8'h7C; assign char_h[4] = 8'h42; assign char_h[5] = 8'h42;
assign char_h[6] = 8'h42; assign char_h[7] = 8'h00;

// Y: 00、00、66、24、18、10、18、00
assign char_Y[0] = 8'h00; assign char_Y[1] = 8'h00; assign char_Y[2] = 8'h66;
assign char_Y[3] = 8'h24; assign char_Y[4] = 8'h18; assign char_Y[5] = 8'h10;
assign char_Y[6] = 8'h18; assign char_Y[7] = 8'h00;

// A: 00、00、18、28、3C、44、42、00
assign char_A[0] = 8'h00; assign char_A[1] = 8'h00; assign char_A[2] = 8'h18;
assign char_A[3] = 8'h28; assign char_A[4] = 8'h3C; assign char_A[5] = 8'h44;
assign char_A[6] = 8'h42; assign char_A[7] = 8'h00;

// r: 00、00、00、6E、30、20、70、00
assign char_r[0] = 8'h00; assign char_r[1] = 8'h00; assign char_r[2] = 8'h00;
assign char_r[3] = 8'h6E; assign char_r[4] = 8'h30; assign char_r[5] = 8'h20;
assign char_r[6] = 8'h70; assign char_r[7] = 8'h00;

// c: 00、00、00、3C、40、40、3C、00
assign char_c[0] = 8'h00; assign char_c[1] = 8'h00; assign char_c[2] = 8'h00;
assign char_c[3] = 8'h3C; assign char_c[4] = 8'h40; assign char_c[5] = 8'h40;
assign char_c[6] = 8'h3C; assign char_c[7] = 8'h00;

// u: 00、00、00、C6、42、42、3F、00
assign char_u[0] = 8'h00; assign char_u[1] = 8'h00; assign char_u[2] = 8'h00;
assign char_u[3] = 8'hC6; assign char_u[4] = 8'h42; assign char_u[5] = 8'h42;
assign char_u[6] = 8'h3F; assign char_u[7] = 8'h00;

// m: 00、00、00、F6、4A、4A、4A、00
assign char_m[0] = 8'h00; 
assign char_m[1] = 8'h00; 
assign char_m[2] = 8'h00;
assign char_m[3] = 8'hF6; 
assign char_m[4] = 8'h4A; 
assign char_m[5] = 8'h4A;
assign char_m[6] = 8'h4A;
assign char_m[7] = 8'h00;

// b: 00、40、40、5C、62、42、7C、00
assign char_b[0] = 8'h00; assign char_b[1] = 8'h40; assign char_b[2] = 8'h40;
assign char_b[3] = 8'h5C; assign char_b[4] = 8'h62; assign char_b[5] = 8'h42;
assign char_b[6] = 8'h7C; assign char_b[7] = 8'h00;

// 原有必要字符（用户未修改，保留原逻辑）
assign char_a[0] = 8'h00; assign char_a[1] = 8'h00; assign char_a[2] = 8'h00;
assign char_a[3] = 8'h3C; assign char_a[4] = 8'h1C; assign char_a[5] = 8'h64;
assign char_a[6] = 8'h7F; assign char_a[7] = 8'h00;

assign char_n[0] = 8'h00; assign char_n[1] = 8'h00; assign char_n[2] = 8'h00;
assign char_n[3] = 8'h7C; assign char_n[4] = 8'h42; assign char_n[5] = 8'h42;
assign char_n[6] = 8'h42; assign char_n[7] = 8'h00;

assign char_g[0] = 8'h00; assign char_g[1] = 8'h00; assign char_g[2] = 8'h00;
assign char_g[3] = 8'h3A; assign char_g[4] = 8'h44; assign char_g[5] = 8'h38;
assign char_g[6] = 8'h3E; assign char_g[7] = 8'h7E;

assign char_l[0] = 8'h00; assign char_l[1] = 8'h10; assign char_l[2] = 8'h10;
assign char_l[3] = 8'h10; assign char_l[4] = 8'h10; assign char_l[5] = 8'h10;
assign char_l[6] = 8'h18; assign char_l[7] = 8'h00;

assign char_e[0] = 8'h00; assign char_e[1] = 8'h00; assign char_e[2] = 8'h00;
assign char_e[3] = 8'h3C; assign char_e[4] = 8'h42; assign char_e[5] = 8'h7C;
assign char_e[6] = 8'h3C; assign char_e[7] = 8'h00;

assign char_colon[0] = 8'h00; assign char_colon[1] = 8'h00; assign char_colon[2] = 8'h00;
assign char_colon[3] = 8'h00; assign char_colon[4] = 8'h30; assign char_colon[5] = 8'h00;
assign char_colon[6] = 8'h30; assign char_colon[7] = 8'h00;

assign char_x[0] = 8'h00; assign char_x[1] = 8'h00; assign char_x[2] = 8'h00;
assign char_x[3] = 8'h76; assign char_x[4] = 8'h18; assign char_x[5] = 8'h18;
assign char_x[6] = 8'h24; assign char_x[7] = 8'h00;

assign char_y[0] = 8'h00; assign char_y[1] = 8'h00; assign char_y[2] = 8'h00;
assign char_y[3] = 8'h66; assign char_y[4] = 8'h24; assign char_y[5] = 8'h18;
assign char_y[6] = 8'h08; assign char_y[7] = 8'h70;

assign char_plus[0] = 8'h00; 
assign char_plus[1] = 8'h10; 
assign char_plus[2] = 8'h10;
assign char_plus[3] = 8'h10; 
assign char_plus[4] = 8'hFE; 
assign char_plus[5] = 8'h10;
assign char_plus[6] = 8'h10; 
assign char_plus[7] = 8'h10;

assign char_minus[0] = 8'h00; assign char_minus[1] = 8'h00; assign char_minus[2] = 8'h00;
assign char_minus[3] = 8'hFE; assign char_minus[4] = 8'h00; assign char_minus[5] = 8'h00;
assign char_minus[6] = 8'h00; assign char_minus[7] = 8'h00;

// 告知用户需补充的z字模数据格式（示例格式，需用户替换实际值）：
assign char_z[0] = 8'h00; // 第1行（如00）
assign char_z[1] = 8'h00; // 第2行（如00）
assign char_z[2] = 8'h00; // 第3行（如XX）
assign char_z[3] = 8'h7C; // 第4行（如XX）
assign char_z[4] = 8'h08; // 第5行（如XX）
assign char_z[5] = 8'h10; // 第6行（如XX）
assign char_z[6] = 8'h7E; // 第7行（如XX）
assign char_z[7] = 8'h00; // 第8行（如00）

// 数字字模（保留原有，用户未修改）
assign digit_0[0] = 8'h00; assign digit_0[1] = 8'h18; assign digit_0[2] = 8'h66; assign digit_0[3] = 8'h42;
assign digit_0[4] = 8'h42; assign digit_0[5] = 8'h42; assign digit_0[6] = 8'h3C; assign digit_0[7] = 8'h00;

assign digit_1[0] = 8'h00; assign digit_1[1] = 8'h08; assign digit_1[2] = 8'h18; assign digit_1[3] = 8'h08;
assign digit_1[4] = 8'h08; assign digit_1[5] = 8'h08; assign digit_1[6] = 8'h18; assign digit_1[7] = 8'h00;

assign digit_2[0] = 8'h00; assign digit_2[1] = 8'h3C; assign digit_2[2] = 8'h42; assign digit_2[3] = 8'h06;
assign digit_2[4] = 8'h08; assign digit_2[5] = 8'h30; assign digit_2[6] = 8'h7E; assign digit_2[7] = 8'h00;

assign digit_3[0] = 8'h00; assign digit_3[1] = 8'h38; assign digit_3[2] = 8'h46; assign digit_3[3] = 8'h04;
assign digit_3[4] = 8'h0C; assign digit_3[5] = 8'h42; assign digit_3[6] = 8'h7C; assign digit_3[7] = 8'h00;

assign digit_4[0] = 8'h00; assign digit_4[1] = 8'h04; assign digit_4[2] = 8'h1C; assign digit_4[3] = 8'h24;
assign digit_4[4] = 8'h44; assign digit_4[5] = 8'h3C; assign digit_4[6] = 8'h0C; assign digit_4[7] = 8'h00;

assign digit_5[0] = 8'h00; assign digit_5[1] = 8'h7C; assign digit_5[2] = 8'h40; assign digit_5[3] = 8'h78;
assign digit_5[4] = 8'h04; assign digit_5[5] = 8'h04; assign digit_5[6] = 8'h78; assign digit_5[7] = 8'h00;

assign digit_6[0] = 8'h00; assign digit_6[1] = 8'h38; assign digit_6[2] = 8'h40; assign digit_6[3] = 8'h78;
assign digit_6[4] = 8'h44; assign digit_6[5] = 8'h44; assign digit_6[6] = 8'h38; assign digit_6[7] = 8'h00;

assign digit_7[0] = 8'h00; assign digit_7[1] = 8'h7E; assign digit_7[2] = 8'h02; assign digit_7[3] = 8'h04;
assign digit_7[4] = 8'h08; assign digit_7[5] = 8'h10; assign digit_7[6] = 8'h10; assign digit_7[7] = 8'h00;

assign digit_8[0] = 8'h00; assign digit_8[1] = 8'h3C; assign digit_8[2] = 8'h42; assign digit_8[3] = 8'h3C;
assign digit_8[4] = 8'h42; assign digit_8[5] = 8'h42; assign digit_8[6] = 8'h3C; assign digit_8[7] = 8'h00;

assign digit_9[0] = 8'h00; assign digit_9[1] = 8'h3C; assign digit_9[2] = 8'h42; assign digit_9[3] = 8'h3E;
assign digit_9[4] = 8'h02; assign digit_9[5] = 8'h02; assign digit_9[6] = 8'h3C; assign digit_9[7] = 8'h00;

// ==================== 3. 十字线坐标处理 ====================
reg [11:0] cross_x, cross_y;
reg cross_pix;

always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        cross_x <= 12'd0;
        cross_y <= 12'd0;
    end else begin
        cross_x <= (distance_mm[11:0] < SCREEN_W) ? distance_mm[11:0] : SCREEN_W - 1'b1;
        cross_y <= (distance_mm_2[11:0] < SCREEN_H) ? distance_mm_2[11:0] : SCREEN_H - 1'b1;
    end
end

// 十字线绘制逻辑
always @(*) begin
    cross_pix = 1'b0;
    if(i_de) begin
        // 水平十字线
        if((y_act == cross_y) && (x_act >= (cross_x > CROSS_LENGTH ? cross_x - CROSS_LENGTH : 12'd0)) 
           && (x_act <= (cross_x + CROSS_LENGTH < SCREEN_W ? cross_x + CROSS_LENGTH : SCREEN_W - 1'b1)))
            cross_pix = 1'b1;
        // 垂直十字线
        else if((x_act == cross_x) && (y_act >= (cross_y > CROSS_LENGTH ? cross_y - CROSS_LENGTH : 12'd0))
               && (y_act <= (cross_y + CROSS_LENGTH < SCREEN_H ? cross_y + CROSS_LENGTH : SCREEN_H - 1'b1)))
            cross_pix = 1'b1;
    end
end



wire rect_pix; 

// ======================================
// 取前10个box（如果不足10个，后面的就是0）
// 每个box占38位，格式：{x_min[9:0], x_max[9:0], y_min[8:0], y_max[8:0]}
// ======================================
wire [37:0] box0 = box_all[38*1-1 : 38*0];    // [37:0]
wire [37:0] box1 = box_all[38*2-1 : 38*1];    // [75:38]
wire [37:0] box2 = box_all[38*3-1 : 38*2];    // [113:76]
wire [37:0] box3 = box_all[38*4-1 : 38*3];    // [151:114]
wire [37:0] box4 = box_all[38*5-1 : 38*4];    // [189:152]
wire [37:0] box5 = box_all[38*6-1 : 38*5];    // [227:190]
wire [37:0] box6 = box_all[38*7-1 : 38*6];    // [265:228]
wire [37:0] box7 = box_all[38*8-1 : 38*7];    // [303:266]
wire [37:0] box8 = box_all[38*9-1 : 38*8];    // [341:304]
wire [37:0] box9 = box_all[38*10-1: 38*9];    // [379:342]

// ======================================
// 拆坐标（每个box格式一致）
// ======================================
// box0坐标
wire [9:0] x0_min = box0[37:28];
wire [9:0] x0_max = box0[27:18];
wire [8:0] y0_min = box0[17:9];
wire [8:0] y0_max = box0[8:0];

// box1坐标
wire [9:0] x1_min = box1[37:28];
wire [9:0] x1_max = box1[27:18];
wire [8:0] y1_min = box1[17:9];
wire [8:0] y1_max = box1[8:0];

// box2坐标
wire [9:0] x2_min = box2[37:28];
wire [9:0] x2_max = box2[27:18];
wire [8:0] y2_min = box2[17:9];
wire [8:0] y2_max = box2[8:0];

// box3坐标
wire [9:0] x3_min = box3[37:28];
wire [9:0] x3_max = box3[27:18];
wire [8:0] y3_min = box3[17:9];
wire [8:0] y3_max = box3[8:0];

// box4坐标
wire [9:0] x4_min = box4[37:28];
wire [9:0] x4_max = box4[27:18];
wire [8:0] y4_min = box4[17:9];
wire [8:0] y4_max = box4[8:0];

// box5坐标
wire [9:0] x5_min = box5[37:28];
wire [9:0] x5_max = box5[27:18];
wire [8:0] y5_min = box5[17:9];
wire [8:0] y5_max = box5[8:0];

// box6坐标
wire [9:0] x6_min = box6[37:28];
wire [9:0] x6_max = box6[27:18];
wire [8:0] y6_min = box6[17:9];
wire [8:0] y6_max = box6[8:0];

// box7坐标
wire [9:0] x7_min = box7[37:28];
wire [9:0] x7_max = box7[27:18];
wire [8:0] y7_min = box7[17:9];
wire [8:0] y7_max = box7[8:0];

// box8坐标
wire [9:0] x8_min = box8[37:28];
wire [9:0] x8_max = box8[27:18];
wire [8:0] y8_min = box8[17:9];
wire [8:0] y8_max = box8[8:0];

// box9坐标
wire [9:0] x9_min = box9[37:28];
wire [9:0] x9_max = box9[27:18];
wire [8:0] y9_min = box9[17:9];
wire [8:0] y9_max = box9[8:0];

// ======================================
// 单独判断每个box是否命中（边界检测）
// 即使box为0，也不会误触发
// ======================================
wire hit0 = i_de && (
    ((y_act == y0_min) && (x_act >= x0_min) && (x_act <= x0_max)) ||
    ((y_act == y0_max) && (x_act >= x0_min) && (x_act <= x0_max)) ||
    ((x_act == x0_min) && (y_act >= y0_min) && (y_act <= y0_max)) ||
    ((x_act == x0_max) && (y_act >= y0_min) && (y_act <= y0_max))
);

wire hit1 = i_de && (
    ((y_act == y1_min) && (x_act >= x1_min) && (x_act <= x1_max)) ||
    ((y_act == y1_max) && (x_act >= x1_min) && (x_act <= x1_max)) ||
    ((x_act == x1_min) && (y_act >= y1_min) && (y_act <= y1_max)) ||
    ((x_act == x1_max) && (y_act >= y1_min) && (y_act <= y1_max))
);

wire hit2 = i_de && (
    ((y_act == y2_min) && (x_act >= x2_min) && (x_act <= x2_max)) ||
    ((y_act == y2_max) && (x_act >= x2_min) && (x_act <= x2_max)) ||
    ((x_act == x2_min) && (y_act >= y2_min) && (y_act <= y2_max)) ||
    ((x_act == x2_max) && (y_act >= y2_min) && (y_act <= y2_max))
);

wire hit3 = i_de && (
    ((y_act == y3_min) && (x_act >= x3_min) && (x_act <= x3_max)) ||
    ((y_act == y3_max) && (x_act >= x3_min) && (x_act <= x3_max)) ||
    ((x_act == x3_min) && (y_act >= y3_min) && (y_act <= y3_max)) ||
    ((x_act == x3_max) && (y_act >= y3_min) && (y_act <= y3_max))
);

wire hit4 = i_de && (
    ((y_act == y4_min) && (x_act >= x4_min) && (x_act <= x4_max)) ||
    ((y_act == y4_max) && (x_act >= x4_min) && (x_act <= x4_max)) ||
    ((x_act == x4_min) && (y_act >= y4_min) && (y_act <= y4_max)) ||
    ((x_act == x4_max) && (y_act >= y4_min) && (y_act <= y4_max))
);

wire hit5 = i_de && (
    ((y_act == y5_min) && (x_act >= x5_min) && (x_act <= x5_max)) ||
    ((y_act == y5_max) && (x_act >= x5_min) && (x_act <= x5_max)) ||
    ((x_act == x5_min) && (y_act >= y5_min) && (y_act <= y5_max)) ||
    ((x_act == x5_max) && (y_act >= y5_min) && (y_act <= y5_max))
);

wire hit6 = i_de && (
    ((y_act == y6_min) && (x_act >= x6_min) && (x_act <= x6_max)) ||
    ((y_act == y6_max) && (x_act >= x6_min) && (x_act <= x6_max)) ||
    ((x_act == x6_min) && (y_act >= y6_min) && (y_act <= y6_max)) ||
    ((x_act == x6_max) && (y_act >= y6_min) && (y_act <= y6_max))
);

wire hit7 = i_de && (
    ((y_act == y7_min) && (x_act >= x7_min) && (x_act <= x7_max)) ||
    ((y_act == y7_max) && (x_act >= x7_min) && (x_act <= x7_max)) ||
    ((x_act == x7_min) && (y_act >= y7_min) && (y_act <= y7_max)) ||
    ((x_act == x7_max) && (y_act >= y7_min) && (y_act <= y7_max))
);

wire hit8 = i_de && (
    ((y_act == y8_min) && (x_act >= x8_min) && (x_act <= x8_max)) ||
    ((y_act == y8_max) && (x_act >= x8_min) && (x_act <= x8_max)) ||
    ((x_act == x8_min) && (y_act >= y8_min) && (y_act <= y8_max)) ||
    ((x_act == x8_max) && (y_act >= y8_min) && (y_act <= y8_max))
);

wire hit9 = i_de && (
    ((y_act == y9_min) && (x_act >= x9_min) && (x_act <= x9_max)) ||
    ((y_act == y9_max) && (x_act >= x9_min) && (x_act <= x9_max)) ||
    ((x_act == x9_min) && (y_act >= y9_min) && (y_act <= y9_max)) ||
    ((x_act == x9_max) && (y_act >= y9_min) && (y_act <= y9_max))
);

// ======================================
// 最终OR合成（仅有效box参与）
// ======================================
assign rect_pix =
      (box_count_out > 0 ? hit0 : 1'b0)
    | (box_count_out > 1 ? hit1 : 1'b0)
    | (box_count_out > 2 ? hit2 : 1'b0)
    | (box_count_out > 3 ? hit3 : 1'b0)
    | (box_count_out > 4 ? hit4 : 1'b0)
    | (box_count_out > 5 ? hit5 : 1'b0)
    | (box_count_out > 6 ? hit6 : 1'b0)
    | (box_count_out > 7 ? hit7 : 1'b0)
    | (box_count_out > 8 ? hit8 : 1'b0)
    | (box_count_out > 9 ? hit9 : 1'b0);




// ==================== 4. 数据拆分逻辑 ====================
// 阈值数据拆分
reg [3:0] bin_th_thou, bin_th_hund, bin_th_ten, bin_th_unit;
reg [3:0] sobel_th_thou, sobel_th_hund, sobel_th_ten, sobel_th_unit;
reg [3:0] y_min_thou, y_min_hund, y_min_ten, y_min_unit;
reg [3:0] y_max_thou, y_max_hund, y_max_ten, y_max_unit;
reg [3:0] angle_th_thou, angle_th_hund, angle_th_ten, angle_th_unit;
reg [3:0] z_angle_th_thou, z_angle_th_hund, z_angle_th_ten, z_angle_th_unit;
// 新增：area_th数据拆分（18位，范围0~131071，支持5位数字）
reg [3:0] area_th_ten_thou, area_th_thou, area_th_hund, area_th_ten, area_th_unit;

// 坐标数据拆分
reg [3:0] x_thou, x_hund, x_ten, x_unit;
reg [3:0] y_thou, y_hund, y_ten, y_unit;
reg [3:0] angle_thou, angle_hund, angle_ten, angle_unit;
// 新增：z的Angle数据拆分寄存器
reg [3:0] z_angle_thou, z_angle_hund, z_angle_ten, z_angle_unit;

always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        // 初始化所有数字
        {bin_th_thou, bin_th_hund, bin_th_ten, bin_th_unit} <= 16'd0;
        {sobel_th_thou, sobel_th_hund, sobel_th_ten, sobel_th_unit} <= 16'd0;
        {y_min_thou, y_min_hund, y_min_ten, y_min_unit} <= 16'd0;
        {y_max_thou, y_max_hund, y_max_ten, y_max_unit} <= 16'd0;
        {angle_th_thou, angle_th_hund, angle_th_ten, angle_th_unit} <= 16'd0;
        {x_thou, x_hund, x_ten, x_unit} <= 16'd0;
        {y_thou, y_hund, y_ten, y_unit} <= 16'd0;
        {angle_thou, angle_hund, angle_ten, angle_unit} <= 16'd0;
        {z_angle_thou, z_angle_hund, z_angle_ten, z_angle_unit} <= 16'd0;
        {z_angle_th_thou, z_angle_th_hund, z_angle_th_ten, z_angle_th_unit} <=16'd0;
        {area_th_ten_thou, area_th_thou, area_th_hund, area_th_ten, area_th_unit} <=18'd0;
    end else begin
        // 阈值数据拆分（0-255范围）
        bin_th_unit <= bin_th % 10;
        bin_th_ten  <= (bin_th / 10) % 10;
        bin_th_hund <= (bin_th / 100) % 10;
        bin_th_thou <= 4'd0;

        sobel_th_unit <= sobel_th % 10;
        sobel_th_ten  <= (sobel_th / 10) % 10;
        sobel_th_hund <= (sobel_th / 100) % 10;
        sobel_th_thou <= 4'd0;

     //  正确：y_min拆分（11位，范围0-2047）
        y_min_unit <= y_min % 10;                    // 个位
        y_min_ten  <= (y_min / 10) % 10;             // 十位
        y_min_hund <= (y_min / 100) % 10;            // 百位
        y_min_thou <= (y_min / 1000) % 10;           // 千位（支持0-2047）
        
        //  正确：y_max拆分（11位，范围0-2047）
        y_max_unit <= y_max % 10;                    // 个位
        y_max_ten  <= (y_max / 10) % 10;             // 十位
        y_max_hund <= (y_max / 100) % 10;            // 百位
        y_max_thou <= (y_max / 1000) % 10;           // 千位

        angle_th_unit <= angle_th % 10;
        angle_th_ten  <= (angle_th / 10) % 10;
        angle_th_hund <= (angle_th / 100) % 10;
        angle_th_thou <= 4'd0;

        z_angle_th_unit <= z_angle_th % 10;
        z_angle_th_ten  <= (z_angle_th / 10) % 10;
        z_angle_th_hund <= (z_angle_th / 100) % 10;
        z_angle_th_thou <= 4'd0;

        // 坐标数据拆分（0-9999范围）
        x_unit <= distance_mm % 10;
        x_ten  <= (distance_mm / 10) % 10;
        x_hund <= (distance_mm / 100) % 10;
        x_thou <= (distance_mm / 1000) % 10;

        y_unit <= distance_mm_2 % 10;
        y_ten  <= (distance_mm_2 / 10) % 10;
        y_hund <= (distance_mm_2 / 100) % 10;
        y_thou <= (distance_mm_2 / 1000) % 10;

        angle_unit <= distance_mm_3 % 10;
        angle_ten  <= (distance_mm_3 / 10) % 10;
        angle_hund <= (distance_mm_3 / 100) % 10;
        angle_thou <= (distance_mm_3 / 1000) % 10;

        // 新增：z_angle拆分（逻辑同现有Angle）
        z_angle_unit <= z_angle % 10;          // 个位
        z_angle_ten  <= (z_angle / 10) % 10;   // 十位
        z_angle_hund <= (z_angle / 100) % 10;  // 百位
        z_angle_thou <= (z_angle / 1000) % 10; // 千位

        // 新增：area_th拆分（0~131071，5位数字：万+千+百+十+个）
        area_th_unit      <= area_th % 10;                    // 个位
        area_th_ten       <= (area_th / 10) % 10;             // 十位
        area_th_hund      <= (area_th / 100) % 10;            // 百位
        area_th_thou      <= (area_th / 1000) % 10;           // 千位
        area_th_ten_thou  <= (area_th / 10000) % 10;          // 万位（最大13，足够覆盖131071）
    end
end

// ==================== 5. 显示区域判断 ====================
// 区域偏移信号声明
reg [11:0] x_off_mode, y_off_mode;
reg [11:0] x_off_bin, y_off_bin;
reg [11:0] x_off_sobel, y_off_sobel;
reg [11:0] x_off_ymin, y_off_ymin;
reg [11:0] x_off_ymax, y_off_ymax;
reg [11:0] x_off_angth, y_off_angth;
reg [11:0] x_off_z_angth, y_off_z_angth;
reg [11:0] x_off_x, y_off_x;
reg [11:0] x_off_y, y_off_y;
reg [11:0] x_off_angle, y_off_angle;
// 新增：z_angle偏移/有效信号
reg [11:0] x_off_z_angle, y_off_z_angle;
reg [11:0] x_off_areath, y_off_areath;

// 区域有效信号声明
reg char_de_mode, char_de_bin, char_de_sobel;
reg char_de_ymin, char_de_ymax, char_de_angth,char_de_z_angth;
reg char_de_x, char_de_y, char_de_angle,char_de_z_angle;
reg char_de_areath;

// 区域判断逻辑
always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        char_de_mode <= 1'b0; char_de_bin <= 1'b0; char_de_sobel <= 1'b0;
        char_de_ymin <= 1'b0; char_de_ymax <= 1'b0; char_de_angth <= 1'b0;
        char_de_x <= 1'b0; char_de_y <= 1'b0; char_de_angle <= 1'b0;
        
        x_off_mode <= 12'd0; y_off_mode <= 12'd0;
        x_off_bin <= 12'd0; y_off_bin <= 12'd0;
        x_off_sobel <= 12'd0; y_off_sobel <= 12'd0;
        x_off_ymin <= 12'd0; y_off_ymin <= 12'd0;
        x_off_ymax <= 12'd0; y_off_ymax <= 12'd0;
        x_off_angth <= 12'd0; y_off_angth <= 12'd0;
        x_off_z_angth <= 12'd0; y_off_z_angth <= 12'd0;
        x_off_x <= 12'd0; y_off_x <= 12'd0;
        x_off_y <= 12'd0; y_off_y <= 12'd0;
        x_off_angle <= 12'd0; y_off_angle <= 12'd0;
        x_off_z_angle <= 12'd0;y_off_z_angle <= 12'd0;
    end else begin
// 修正3：模式区域宽度=5（"Mode: "）+ 模式名称长度 → 动态适配
        x_off_mode <= x_act - CHAR_X_MODE;
        y_off_mode <= y_act - CHAR_Y_MODE;
        char_de_mode <= (x_act >= CHAR_X_MODE) && 
                       (x_act < CHAR_X_MODE + (5 + mode_name_len_reg)*CHAR_WIDTH) && // 动态宽度
                       (y_act >= CHAR_Y_MODE) && (y_act < CHAR_Y_MODE + CHAR_HEIGHT);

        // 二值化阈值区域 - "BinTh: 0000" (10字符宽度)
        x_off_bin <= x_act - CHAR_X_BIN;
        y_off_bin <= y_act - CHAR_Y_BIN;
        char_de_bin <= (x_act >= CHAR_X_BIN) && (x_act < CHAR_X_BIN + 10*CHAR_WIDTH) &&
                      (y_act >= CHAR_Y_BIN) && (y_act < CHAR_Y_BIN + CHAR_HEIGHT);

// 修正4：Sobel阈值区域宽度=12字符
        x_off_sobel <= x_act - CHAR_X_SOBEL;
        y_off_sobel <= y_act - CHAR_Y_SOBEL;
        char_de_sobel <= (x_act >= CHAR_X_SOBEL) && (x_act < CHAR_X_SOBEL + 12*CHAR_WIDTH) &&
                        (y_act >= CHAR_Y_SOBEL) && (y_act < CHAR_Y_SOBEL + CHAR_HEIGHT);

        // YMin阈值区域 - "YMin: 0000" (9字符宽度)
        x_off_ymin <= x_act - CHAR_X_YMIN;
        y_off_ymin <= y_act - CHAR_Y_YMIN;
        char_de_ymin <= (x_act >= CHAR_X_YMIN) && (x_act < CHAR_X_YMIN + 9*CHAR_WIDTH) &&
                       (y_act >= CHAR_Y_YMIN) && (y_act < CHAR_Y_YMIN + CHAR_HEIGHT);

        // YMax阈值区域 - "YMax: 0000" (9字符宽度)
        x_off_ymax <= x_act - CHAR_X_YMAX;
        y_off_ymax <= y_act - CHAR_Y_YMAX;
        char_de_ymax <= (x_act >= CHAR_X_YMAX) && (x_act < CHAR_X_YMAX + 9*CHAR_WIDTH) &&
                       (y_act >= CHAR_Y_YMAX) && (y_act < CHAR_Y_YMAX + CHAR_HEIGHT);

// 修正5：AngleTh阈值区域宽度=12字符
        x_off_angth <= x_act - CHAR_X_ANGLETH;
        y_off_angth <= y_act - CHAR_Y_ANGLETH;
        char_de_angth <= (x_act >= CHAR_X_ANGLETH) && (x_act < CHAR_X_ANGLETH + 12*CHAR_WIDTH) &&
                        (y_act >= CHAR_Y_ANGLETH) && (y_act < CHAR_Y_ANGLETH + CHAR_HEIGHT);
// 新增：z_angle_th区域判断（与AngleTh一致，宽度12字符）
        x_off_z_angth <= x_act - CHAR_X_Z_ANGLETH;  // 独立X偏移
        y_off_z_angth <= y_act - CHAR_Y_Z_ANGLETH;  // 独立Y偏移
        char_de_z_angth <= (x_act >= CHAR_X_Z_ANGLETH) && (x_act < CHAR_X_Z_ANGLETH + 14*CHAR_WIDTH) &&
                          (y_act >= CHAR_Y_Z_ANGLETH) && (y_act < CHAR_Y_Z_ANGLETH + CHAR_HEIGHT);

        // X坐标显示区域 - "x: 0000" (6字符宽度)
        x_off_x <= x_act - CHAR_X_X;
        y_off_x <= y_act - CHAR_Y_X;
        char_de_x <= (x_act >= CHAR_X_X) && (x_act < CHAR_X_X + 6*CHAR_WIDTH) &&
                    (y_act >= CHAR_Y_X) && (y_act < CHAR_Y_X + CHAR_HEIGHT);

        // Y坐标显示区域 - "y: 0000" (6字符宽度)
        x_off_y <= x_act - CHAR_X_Y;
        y_off_y <= y_act - CHAR_Y_Y;
        char_de_y <= (x_act >= CHAR_X_Y) && (x_act < CHAR_X_Y + 6*CHAR_WIDTH) &&
                    (y_act >= CHAR_Y_Y) && (y_act < CHAR_Y_Y + CHAR_HEIGHT);

        // Angle显示区域 - "angle: ±0000" (11字符宽度)
        x_off_angle <= x_act - CHAR_X_ANGLE;
        y_off_angle <= y_act - CHAR_Y_ANGLE;
        char_de_angle <= (x_act >= CHAR_X_ANGLE) && (x_act < CHAR_X_ANGLE + 11*CHAR_WIDTH) &&
                        (y_act >= CHAR_Y_ANGLE) && (y_act < CHAR_Y_ANGLE + CHAR_HEIGHT);

        // Z_Angle显示区域（修正：独立偏移信号）
        x_off_z_angle <= x_act - CHAR_X_Z_ANGLE; // 独立偏移X
        y_off_z_angle <= y_act - CHAR_Y_Z_ANGLE; // 独立偏移Y
        char_de_z_angle <= (x_act >= CHAR_X_Z_ANGLE) && (x_act < CHAR_X_Z_ANGLE + 10*CHAR_WIDTH) &&
                          (y_act >= CHAR_Y_Z_ANGLE) && (y_act < CHAR_Y_Z_ANGLE + CHAR_HEIGHT);

// 新增：AreaTh显示区域 - "AreaTh: 00000"（13字符宽度：8字符前缀+5位数字）

        x_off_areath <= x_act - CHAR_X_AREATH;
        y_off_areath <= y_act - CHAR_Y_AREATH;
        char_de_areath <= (x_act >= CHAR_X_AREATH) && (x_act < CHAR_X_AREATH + 13*CHAR_WIDTH) &&
                          (y_act >= CHAR_Y_AREATH) && (y_act < CHAR_Y_AREATH + CHAR_HEIGHT);
    end
end

// ==================== 6. 字符绘制任务（修正：添加z字符分支） ====================
task draw_char;
    input [7:0] char_idx;  // 字符索引
    input [3:0] digit;     // 数字值
    input [2:0] y_off;     // 行偏移（0~7）
    input [2:0] x_off;     // 列偏移（0~7）
    output reg pix;         // 像素输出
    
    begin
        case(char_idx)
            // 数字0-9（保持不变）
            8'd23: begin
                case(digit)
                    4'd0: pix = digit_0[y_off][7-x_off];
                    4'd1: pix = digit_1[y_off][7-x_off];
                    4'd2: pix = digit_2[y_off][7-x_off];
                    4'd3: pix = digit_3[y_off][7-x_off];
                    4'd4: pix = digit_4[y_off][7-x_off];
                    4'd5: pix = digit_5[y_off][7-x_off];
                    4'd6: pix = digit_6[y_off][7-x_off];
                    4'd7: pix = digit_7[y_off][7-x_off];
                    4'd8: pix = digit_8[y_off][7-x_off];
                    4'd9: pix = digit_9[y_off][7-x_off];
                    default: pix = 1'b0;
                endcase
            end
            
            // 字母和符号（补充z字符分支）
            8'd0: pix = char_a[y_off][7-x_off];        // a
            8'd1: pix = char_n[y_off][7-x_off];        // n
            8'd2: pix = char_g[y_off][7-x_off];        // g
            8'd3: pix = char_l[y_off][7-x_off];        // l
            8'd4: pix = char_e[y_off][7-x_off];        // e
            8'd5: pix = char_colon[y_off][7-x_off];    // ：
            8'd6: pix = char_x[y_off][7-x_off];        // x
            8'd7: pix = char_y[y_off][7-x_off];        // y
            8'd8: pix = char_plus[y_off][7-x_off];     // +
            8'd9: pix = char_minus[y_off][7-x_off];    // -
            8'd10: pix = char_M[y_off][7-x_off];       // M
            8'd11: pix = char_o[y_off][7-x_off];       // o
            8'd12: pix = char_d[y_off][7-x_off];       // d
            8'd13: pix = char_B[y_off][7-x_off];       // B
            8'd14: pix = char_i[y_off][7-x_off];       // i
            8'd15: pix = char_S[y_off][7-x_off];       // S
            8'd16: pix = char_T[y_off][7-x_off];       // T
            8'd17: pix = char_h[y_off][7-x_off];       // h
            8'd18: pix = char_Y[y_off][7-x_off];       // Y
            8'd19: pix = char_A[y_off][7-x_off];       // A
            8'd20: pix = char_r[y_off][7-x_off];       // r
            8'd21: pix = char_c[y_off][7-x_off];       // c
            8'd22: pix = char_u[y_off][7-x_off];       // u
            8'd23: pix = char_m[y_off][7-x_off];       // m（注意：原数字索引也是23，不冲突）
            8'd24: pix = char_b[y_off][7-x_off];       // b
            8'd25: pix = char_z[y_off][7-x_off];       // 新增：z字符
            default: pix = 1'b0;
        endcase
    end
endtask

// ==================== 7. 模式名称与长度映射函数（保持不变） ====================
function [63:0] get_mode_full_name;
    input [2:0] mode;
    begin
        case(mode)
            3'd0: get_mode_full_name = {8'd13, 8'd14, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}; // "BIN"
            3'd1: get_mode_full_name = {8'd15, 8'd11, 8'd13, 8'd4, 8'd3, 8'd0, 8'd0, 8'd0}; // "SOBEL"
            3'd2: get_mode_full_name = {8'd18, 8'd10, 8'd14, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0}; // "YMin"
            3'd3: get_mode_full_name = {8'd18, 8'd10, 8'd19, 8'd6, 8'd0, 8'd0, 8'd0, 8'd0}; // "YMax"
            3'd4: get_mode_full_name = {8'd19, 8'd1, 8'd2, 8'd3, 8'd4, 8'd0, 8'd0, 8'd0}; // "ANGLE"
            3'd5: get_mode_full_name = {8'd25, 8'd19, 8'd1, 8'd2, 8'd3, 8'd4, 8'd0, 8'd0};//ZANGLE
            3'd6: get_mode_full_name = {8'd16, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};//Template
            3'd7: get_mode_full_name = {8'd19, 8'd20, 8'd4, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}; // "AREA"（A-r-e-a）
            default: get_mode_full_name = {8'd13, 8'd14, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
        endcase
    end
endfunction

function [3:0] get_mode_name_len;
    input [2:0] mode;
    begin
        case(mode)
            3'd0: get_mode_name_len = 4'd3;  // "BIN"
            3'd1: get_mode_name_len = 4'd5;  // "SOBEL"
            3'd2: get_mode_name_len = 4'd4;  // "YMin"
            3'd3: get_mode_name_len = 4'd4;  // "YMax"
            3'd4: get_mode_name_len = 4'd5;  // "ANGLE"
            3'd5: get_mode_name_len = 4'd6; //ZANGLE
            3'd6: get_mode_name_len = 4'd1; //Template"T"
            3'd7: get_mode_name_len = 4'd4;  // "AREA"长度4
            default: get_mode_name_len = 4'd3;
        endcase
    end
endfunction

// 模式名称寄存器（保持不变）
reg [63:0] mode_full_name_reg;
reg [3:0] mode_name_len_reg;

always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_full_name_reg <= 64'd0;
        mode_name_len_reg <= 4'd0;
    end else begin
        mode_full_name_reg <= get_mode_full_name(curr_mode);
        mode_name_len_reg <= get_mode_name_len(curr_mode);
    end
end

// ==================== 8. 像素绘制逻辑 ====================
reg pix_mode, pix_bin, pix_sobel, pix_ymin, pix_ymax, pix_angth,pix_z_angth;
reg pix_x, pix_y, pix_angle;
// 新增：z_angle绘制信号
reg pix_z_angle;
// 字符索引
reg [3:0] char_idx;
// 新增：area_th绘制信号
reg pix_areath;

// 主像素绘制逻辑
always @(*) begin
    // 初始化所有像素为0
    pix_mode = 1'b0; pix_bin = 1'b0; pix_sobel = 1'b0;
    pix_ymin = 1'b0; pix_ymax = 1'b0; pix_angth = 1'b0;pix_z_angth = 1'b0;
    pix_x = 1'b0; pix_y = 1'b0; pix_angle = 1'b0;pix_z_angle = 1'b0;

// -------------------------- 模式显示绘制（灵活适配长度） --------------------------
    if(char_de_mode && (y_off_mode < CHAR_HEIGHT)) begin
        char_idx = x_off_mode / CHAR_WIDTH;
        case(char_idx)
            // 固定绘制"Mode: "（5个字符，索引0-4）
            0: draw_char(8'd10, 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode); // M
            1: draw_char(8'd11, 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode); // o
            2: draw_char(8'd12, 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode); // d
            3: draw_char(8'd4, 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);  // e
            4: draw_char(8'd5, 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);  // ：
            // 动态绘制模式名称（索引5开始，长度=mode_name_len_reg）
            5: if(mode_name_len_reg >= 1) draw_char(mode_full_name_reg[63:56], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            6: if(mode_name_len_reg >= 2) draw_char(mode_full_name_reg[55:48], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            7: if(mode_name_len_reg >= 3) draw_char(mode_full_name_reg[47:40], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            8: if(mode_name_len_reg >= 4) draw_char(mode_full_name_reg[39:32], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            9: if(mode_name_len_reg >= 5) draw_char(mode_full_name_reg[31:24], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            10: if(mode_name_len_reg >= 6) draw_char(mode_full_name_reg[23:16], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            11: if(mode_name_len_reg >= 7) draw_char(mode_full_name_reg[15:8], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            12: if(mode_name_len_reg >= 8) draw_char(mode_full_name_reg[7:0], 4'd0, y_off_mode[2:0], x_off_mode[2:0], pix_mode);
            default: pix_mode = 1'b0; // 超出长度显空
        endcase
    end

    // -------------------------- 二值化阈值显示绘制 --------------------------
    if(char_de_bin && (y_off_bin < CHAR_HEIGHT)) begin
        char_idx = x_off_bin / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd13, 4'd0, y_off_bin[2:0], x_off_bin[2:0], pix_bin); // B
            1: draw_char(8'd14, 4'd0, y_off_bin[2:0], x_off_bin[2:0], pix_bin); // i
            2: draw_char(8'd1, 4'd0, y_off_bin[2:0], x_off_bin[2:0], pix_bin);  // n
            3: draw_char(8'd16, 4'd0, y_off_bin[2:0], x_off_bin[2:0], pix_bin); // T
            4: draw_char(8'd17, 4'd0, y_off_bin[2:0], x_off_bin[2:0], pix_bin); // h
            5: draw_char(8'd5, 4'd0, y_off_bin[2:0], x_off_bin[2:0], pix_bin);  // ：
            6: draw_char(8'd23, bin_th_thou, y_off_bin[2:0], x_off_bin[2:0], pix_bin);
            7: draw_char(8'd23, bin_th_hund, y_off_bin[2:0], x_off_bin[2:0], pix_bin);
            8: draw_char(8'd23, bin_th_ten, y_off_bin[2:0], x_off_bin[2:0], pix_bin);
            9: draw_char(8'd23, bin_th_unit, y_off_bin[2:0], x_off_bin[2:0], pix_bin);
            default: pix_bin = 1'b0;
        endcase
    end

// -------------------------- Sobel阈值绘制（补全12字符） --------------------------
    if(char_de_sobel && (y_off_sobel < CHAR_HEIGHT)) begin
        char_idx = x_off_sobel / CHAR_WIDTH;
        case(char_idx)
            // 完整绘制"SobelTh: "（8个字符，索引0-7）
            0: draw_char(8'd15, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel); // S
            1: draw_char(8'd11, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel); // o
            2: draw_char(8'd13, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel); // b
            3: draw_char(8'd4, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);  // e
            4: draw_char(8'd3, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);  // l
            5: draw_char(8'd16, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel); // T
            6: draw_char(8'd17, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel); // h
            7: draw_char(8'd5, 4'd0, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);  // ：
            // 补全4位数字（索引8-11）
            8: draw_char(8'd23, sobel_th_thou, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);
            9: draw_char(8'd23, sobel_th_hund, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);
            10: draw_char(8'd23, sobel_th_ten, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);
            11: draw_char(8'd23, sobel_th_unit, y_off_sobel[2:0], x_off_sobel[2:0], pix_sobel);
            default: pix_sobel = 1'b0;
        endcase
    end

    // -------------------------- YMin阈值显示绘制 --------------------------
    if(char_de_ymin && (y_off_ymin < CHAR_HEIGHT)) begin
        char_idx = x_off_ymin / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd18, 4'd0, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin); // Y
            1: draw_char(8'd10, 4'd0, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin); // M
            2: draw_char(8'd14, 4'd0, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin); // i
            3: draw_char(8'd1, 4'd0, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin);  // n
            4: draw_char(8'd5, 4'd0, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin);  // ：
            5: draw_char(8'd23, y_min_thou, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin);
            6: draw_char(8'd23, y_min_hund, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin);
            7: draw_char(8'd23, y_min_ten, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin);
            8: draw_char(8'd23, y_min_unit, y_off_ymin[2:0], x_off_ymin[2:0], pix_ymin);
            default: pix_ymin = 1'b0;
        endcase
    end

    // -------------------------- YMax阈值显示绘制 --------------------------
    if(char_de_ymax && (y_off_ymax < CHAR_HEIGHT)) begin
        char_idx = x_off_ymax / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd18, 4'd0, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax); // Y
            1: draw_char(8'd10, 4'd0, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax); // M
            2: draw_char(8'd19, 4'd0, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax); // A
            3: draw_char(8'd6, 4'd0, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax);  // X
            4: draw_char(8'd5, 4'd0, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax);  // ：
            5: draw_char(8'd23, y_max_thou, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax);
            6: draw_char(8'd23, y_max_hund, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax);
            7: draw_char(8'd23, y_max_ten, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax);
            8: draw_char(8'd23, y_max_unit, y_off_ymax[2:0], x_off_ymax[2:0], pix_ymax);
            default: pix_ymax = 1'b0;
        endcase
    end

// -------------------------- AngleTh阈值绘制（补全12字符） --------------------------
    if(char_de_angth && (y_off_angth < CHAR_HEIGHT)) begin
        char_idx = x_off_angth / CHAR_WIDTH;
        case(char_idx)
            // 完整绘制"AngleTh: "（8个字符，索引0-7）
            0: draw_char(8'd19, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth); // A
            1: draw_char(8'd1, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth);  // n
            2: draw_char(8'd2, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth);  // g
            3: draw_char(8'd3, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth);  // l
            4: draw_char(8'd4, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth);  // e
            5: draw_char(8'd16, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth); // T
            6: draw_char(8'd17, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth); // h
            7: draw_char(8'd5, 4'd0, y_off_angth[2:0], x_off_angth[2:0], pix_angth);  // ：
            // 补全4位数字（索引8-11）
            8: draw_char(8'd23, angle_th_thou, y_off_angth[2:0], x_off_angth[2:0], pix_angth);
            9: draw_char(8'd23, angle_th_hund, y_off_angth[2:0], x_off_angth[2:0], pix_angth);
            10: draw_char(8'd23, angle_th_ten, y_off_angth[2:0], x_off_angth[2:0], pix_angth);
            11: draw_char(8'd23, angle_th_unit, y_off_angth[2:0], x_off_angth[2:0], pix_angth);
            default: pix_angth = 1'b0;
        endcase
    end
   // 新增：z_angle_th绘制（与AngleTh一致，无符号，显示"zAngleTh: 0000"）
    if(char_de_z_angth && (y_off_z_angth < CHAR_HEIGHT)) begin
        char_idx = x_off_z_angth / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd25, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth); // z（索引25，已定义）
            1: draw_char(8'd19, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth); // A
            2: draw_char(8'd1, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // n
            3: draw_char(8'd2, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // g
            4: draw_char(8'd3, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // l
            5: draw_char(8'd4, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // e
            6: draw_char(8'd16, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth); // T
            7: draw_char(8'd17, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth); // h
            8: draw_char(8'd5, 4'd0, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // ：（无符号，无+/-）
            9: draw_char(8'd23, z_angle_th_thou, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // 千位
            10: draw_char(8'd23, z_angle_th_hund, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth); // 百位
            11: draw_char(8'd23, z_angle_th_ten, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth);  // 新增：十位
            12: draw_char(8'd23, z_angle_th_unit, y_off_z_angth[2:0], x_off_z_angth[2:0], pix_z_angth); // 个位（移到索引12）
            default: pix_z_angth = 1'b0;
        endcase
    end

    // -------------------------- X坐标显示绘制 --------------------------
    if(char_de_x && (y_off_x < CHAR_HEIGHT)) begin
        char_idx = x_off_x / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd6, 4'd0, y_off_x[2:0], x_off_x[2:0], pix_x);  // x
            1: draw_char(8'd5, 4'd0, y_off_x[2:0], x_off_x[2:0], pix_x);  // ：
            2: draw_char(8'd23, x_thou, y_off_x[2:0], x_off_x[2:0], pix_x);
            3: draw_char(8'd23, x_hund, y_off_x[2:0], x_off_x[2:0], pix_x);
            4: draw_char(8'd23, x_ten, y_off_x[2:0], x_off_x[2:0], pix_x);
            5: draw_char(8'd23, x_unit, y_off_x[2:0], x_off_x[2:0], pix_x);
            default: pix_x = 1'b0;
        endcase
    end

    // -------------------------- Y坐标显示绘制 --------------------------
    if(char_de_y && (y_off_y < CHAR_HEIGHT)) begin
        char_idx = x_off_y / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd7, 4'd0, y_off_y[2:0], x_off_y[2:0], pix_y);  // y
            1: draw_char(8'd5, 4'd0, y_off_y[2:0], x_off_y[2:0], pix_y);  // ：
            2: draw_char(8'd23, y_thou, y_off_y[2:0], x_off_y[2:0], pix_y);
            3: draw_char(8'd23, y_hund, y_off_y[2:0], x_off_y[2:0], pix_y);
            4: draw_char(8'd23, y_ten, y_off_y[2:0], x_off_y[2:0], pix_y);
            5: draw_char(8'd23, y_unit, y_off_y[2:0], x_off_y[2:0], pix_y);
            default: pix_y = 1'b0;
        endcase
    end

    // -------------------------- Angle显示绘制 --------------------------
    if(char_de_angle && (y_off_angle < CHAR_HEIGHT)) begin
        char_idx = x_off_angle / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd0, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle);  // a
            1: draw_char(8'd1, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle);  // n
            2: draw_char(8'd2, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle);  // g
            3: draw_char(8'd3, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle);  // l
            4: draw_char(8'd4, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle);  // e
            5: draw_char(8'd5, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle);  // ：
            6: draw_char(angle ? 8'd8 : 8'd9, 4'd0, y_off_angle[2:0], x_off_angle[2:0], pix_angle); // +/-
            7: draw_char(8'd23, angle_thou, y_off_angle[2:0], x_off_angle[2:0], pix_angle);
            8: draw_char(8'd23, angle_hund, y_off_angle[2:0], x_off_angle[2:0], pix_angle);
            9: draw_char(8'd23, angle_ten, y_off_angle[2:0], x_off_angle[2:0], pix_angle);
            10: draw_char(8'd23, angle_unit, y_off_angle[2:0], x_off_angle[2:0], pix_angle);
            default: pix_angle = 1'b0;
        endcase
    end
   // Z_Angle显示绘制（修正：移出嵌套，独立判断）
    if(char_de_z_angle && (y_off_z_angle < CHAR_HEIGHT)) begin
        char_idx = x_off_z_angle / CHAR_WIDTH;
        case(char_idx)
            0: draw_char(8'd25, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle); // z
            1: draw_char(8'd0, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // a
            2: draw_char(8'd1, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // n
            3: draw_char(8'd2, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // g
            4: draw_char(8'd3, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // l
            5: draw_char(8'd4, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // e
            6: draw_char(8'd5, 4'd0, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // ：
            7: draw_char(8'd23, z_angle_thou, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // 千位
            8: draw_char(8'd23, z_angle_hund, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle); // 百位
            9: draw_char(8'd23, z_angle_ten, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle);  // 十位
            10: draw_char(8'd23, z_angle_unit, y_off_z_angle[2:0], x_off_z_angle[2:0], pix_z_angle); // 个位
            default: pix_z_angle = 1'b0;
        endcase
    end
    // -------------------------- AreaTh阈值显示绘制 --------------------------
    if(char_de_areath && (y_off_areath < CHAR_HEIGHT)) begin
        char_idx = x_off_areath / CHAR_WIDTH;
        case(char_idx)
            // 绘制"AreaTh: "（8个字符，索引0-7）
            0: draw_char(8'd19, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath); // A（索引19）
            1: draw_char(8'd20, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath); // r（索引20）
            2: draw_char(8'd4, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath);  // e（索引4）
            3: draw_char(8'd0, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath);  // a（索引0）
            4: draw_char(8'd16, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath); // T（索引16）
            5: draw_char(8'd17, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath); // h（索引17）
            6: draw_char(8'd5, 4'd0, y_off_areath[2:0], x_off_areath[2:0], pix_areath);  // ：（索引5）
            // 绘制5位数字（索引8-12：万+千+百+十+个）
            7: draw_char(8'd23, area_th_ten_thou, y_off_areath[2:0], x_off_areath[2:0], pix_areath); // 万位
            8: draw_char(8'd23, area_th_thou, y_off_areath[2:0], x_off_areath[2:0], pix_areath);    // 千位
            9: draw_char(8'd23, area_th_hund, y_off_areath[2:0], x_off_areath[2:0], pix_areath);   // 百位
            10: draw_char(8'd23, area_th_ten, y_off_areath[2:0], x_off_areath[2:0], pix_areath);    // 十位
            11: draw_char(8'd23, area_th_unit, y_off_areath[2:0], x_off_areath[2:0], pix_areath);  // 个位
            default: pix_areath = 1'b0;
        endcase
    end
end

// ==================== 9. 输出合成 ====================
always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        o_de <= 1'b0;
        o_rgb <= 1'b0;
    end else begin
        o_de <= i_de;
        // 原有输出合成（保留），新增pix_z_angle到逻辑或中
        o_rgb <= (pix_mode | pix_bin | pix_sobel | pix_ymin | pix_ymax | 
                 pix_angth | pix_x | pix_y | pix_angle | pix_z_angle | pix_z_angth | rect_pix| pix_areath) ? 1'b1 : cross_pix;
    end
end

endmodule