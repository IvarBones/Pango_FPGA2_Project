/////////////////////////////////////////////////////////////////////////////////////
// 瑕疵四点顶点提取模块（ROM适配最终修正版）
// 修复内容：
// 1. 修正ROM复位极性（active-high），使用.rst(~rstn_out)
// 2. 地址打一拍寄存(rom_addr_reg)，适配同步ROM时序
// 3. 优化ROM数据锁存逻辑，确保仿真可见输出
// 4. 新增ROM相关输出端口（tan_rom_addr/data/reg、cos_rom_addr/data/reg）
// 5. 修复端口声明语法、信号名一致性及复位初始化问题
/////////////////////////////////////////////////////////////////////////////////////
module defect#(
    parameter IMG_WIDTH       = 11'd640,   // 图像宽度
    parameter IMG_HEIGHT      = 11'd480,   // 图像高度
    parameter COORD_WID       = 11,        // 坐标位宽（0~2047）
    parameter TAN_REG_WID     = 16,        // tan值锁存寄存器位宽（×64计算用）
    parameter ANGLE_WID       = 7,         // 角度位宽（匹配ROM rd_data[6:0]）
    parameter DELAY_CYCLES    = 1,         // 延迟索引（1→2拍延迟）
    parameter SLOPE_THRESHOLD = 1,         // 倾斜判断阈值
    parameter Z_DELTA_X       = 300        // 用于求三维z轴角度
)(
    input                       pixclk_in,
    input                       rstn_out,   // 低电平复位（ROM复位信号取反使用）
    input                       bin2_vs,
    input                       bin2_de,
    input                       bin2_data,
    input                       set_template_flag,

    // 核心输出：顶点坐标、中心坐标、有效性
    output reg [COORD_WID-1:0]  defect_p1_x,
    output reg [COORD_WID-1:0]  defect_p1_y,
    output reg [COORD_WID-1:0]  defect_p2_x,
    output reg [COORD_WID-1:0]  defect_p2_y,
    output reg [COORD_WID-1:0]  defect_p3_x,
    output reg [COORD_WID-1:0]  defect_p3_y,
    output reg [COORD_WID-1:0]  defect_p4_x,
    output reg [COORD_WID-1:0]  defect_p4_y,
    output reg [COORD_WID-1:0]  center_position_x,
    output reg [COORD_WID-1:0]  center_position_y,
    output reg                  defect_valid,
    output reg [ANGLE_WID-1:0]  angle,
    output reg [ANGLE_WID-1:0]  z_angle,
    output reg                  is_minus,   // 1为正，0为负
    output                      point_vs,
    output                      point_de,

    // -------------------------- 新增：ROM相关输出端口 --------------------------
    // tan ROM（angle_rom）接口
    output wire [11:0]          tan_rom_addr,      // ROM地址（输出）
    output wire [ANGLE_WID-1:0] tan_rom_data,      // ROM原始数据（未锁存，输出）
    output reg [ANGLE_WID-1:0]  tan_rom_data_reg,  // ROM锁存数据（输出）
    // cos ROM（z_angle_rom）接口
    output wire [11:0]          cos_rom_addr,      // ROM地址（输出）
    output wire [ANGLE_WID-1:0] cos_rom_data,      // ROM原始数据（未锁存，输出）
    output reg [ANGLE_WID-1:0]  cos_rom_data_reg   // ROM锁存数据（输出）
    // --------------------------------------------------------------------------
);


/////////////////////////////////////////////////////////////////////////////////////
// 1. 行列计数器（图像坐标计数）
/////////////////////////////////////////////////////////////////////////////////////
reg [COORD_WID-1:0] x_cnt, y_cnt;
always@(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        x_cnt <= 0;
    else if(x_cnt == IMG_WIDTH - 1'b1)
        x_cnt <= 0;
    else if(bin2_de)
        x_cnt <= x_cnt + 1'b1;

always@(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        y_cnt <= 0;
    else if(y_cnt == IMG_HEIGHT - 1'b1 && x_cnt == IMG_WIDTH - 1'b1)
        y_cnt <= 0;
    else if(x_cnt == IMG_WIDTH - 1'b1)
        y_cnt <= y_cnt + 1'b1;

/////////////////////////////////////////////////////////////////////////////////////
// 2. 极值检测逻辑（提取缺陷的x/y极值及对应坐标）
/////////////////////////////////////////////////////////////////////////////////////
reg [COORD_WID-1:0] x_min_reg, x_min_y_min_reg, x_min_y_max_reg;
reg [COORD_WID-1:0] x_max_reg, x_max_y_min_reg, x_max_y_max_reg;
reg [COORD_WID-1:0] y_min_reg, y_min_x_min_reg, y_min_x_max_reg;
reg [COORD_WID-1:0] y_max_reg, y_max_x_min_reg, y_max_x_max_reg;

reg bin2_vs_prev;
wire bin2_vs_posedge = bin2_vs && !bin2_vs_prev;  // 场同步上升沿（帧起始）
always@(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        bin2_vs_prev <= 0;
    else
        bin2_vs_prev <= bin2_vs;

always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        // 复位时初始化极值（x_min设最大，x_max设最小，确保首帧能更新）
        x_min_reg <= IMG_WIDTH - 1'b1;  x_min_y_min_reg <= IMG_HEIGHT - 1'b1;  x_min_y_max_reg <= 0;
        x_max_reg <= 0;                 x_max_y_min_reg <= IMG_HEIGHT - 1'b1;  x_max_y_max_reg <= 0;
        y_min_reg <= IMG_HEIGHT - 1'b1; y_min_x_min_reg <= IMG_WIDTH - 1'b1;   y_min_x_max_reg <= 0;
        y_max_reg <= 0;                 y_max_x_min_reg <= IMG_WIDTH - 1'b1;   y_max_x_max_reg <= 0;
    end 
    else if (bin2_vs_posedge) begin
        // 每帧起始重置极值（准备新帧检测）
        x_min_reg <= IMG_WIDTH - 1'b1;  x_min_y_min_reg <= IMG_HEIGHT - 1'b1;  x_min_y_max_reg <= 0;
        x_max_reg <= 0;                 x_max_y_min_reg <= IMG_HEIGHT - 1'b1;  x_max_y_max_reg <= 0;
        y_min_reg <= IMG_HEIGHT - 1'b1; y_min_x_min_reg <= IMG_WIDTH - 1'b1;   y_min_x_max_reg <= 0;
        y_max_reg <= 0;                 y_max_x_min_reg <= IMG_WIDTH - 1'b1;   y_max_x_max_reg <= 0;
    end 
    else if (bin2_de && bin2_data == 1'b1) begin
        // 检测到缺陷像素（bin2_data=1），更新x/y极值及对应y/x坐标
        // 更新x最小值（x_min）及对应y的极值
        if (x_cnt < x_min_reg) begin
            x_min_reg       <= x_cnt;
            x_min_y_min_reg <= y_cnt;
            x_min_y_max_reg <= y_cnt;
        end else if (x_cnt == x_min_reg) begin
            if (y_cnt < x_min_y_min_reg) x_min_y_min_reg <= y_cnt;
            if (y_cnt > x_min_y_max_reg) x_min_y_max_reg <= y_cnt;
        end

        // 更新x最大值（x_max）及对应y的极值
        if (x_cnt > x_max_reg) begin
            x_max_reg       <= x_cnt;
            x_max_y_min_reg <= y_cnt;
            x_max_y_max_reg <= y_cnt;
        end else if (x_cnt == x_max_reg) begin
            if (y_cnt < x_max_y_min_reg) x_max_y_min_reg <= y_cnt;
            if (y_cnt > x_max_y_max_reg) x_max_y_max_reg <= y_cnt;
        end

        // 更新y最小值（y_min）及对应x的极值
        if (y_cnt < y_min_reg) begin
            y_min_reg       <= y_cnt;
            y_min_x_min_reg <= x_cnt;
            y_min_x_max_reg <= x_cnt;
        end else if (y_cnt == y_min_reg) begin
            if (x_cnt < y_min_x_min_reg) y_min_x_min_reg <= x_cnt;
            if (x_cnt > y_min_x_max_reg) y_min_x_max_reg <= x_cnt;
        end

        // 更新y最大值（y_max）及对应x的极值
        if (y_cnt > y_max_reg) begin
            y_max_reg       <= y_cnt;
            y_max_x_min_reg <= x_cnt;
            y_max_x_max_reg <= x_cnt;
        end else if (y_cnt == y_max_reg) begin
            if (x_cnt < y_max_x_min_reg) y_max_x_min_reg <= x_cnt;
            if (x_cnt > y_max_x_max_reg) y_max_x_max_reg <= x_cnt;
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////
// 3. 顶点锁存 + tan/cos值计算（缺陷形状判断及角度参数计算）
/////////////////////////////////////////////////////////////////////////////////////
wire frame_end_flag = (x_cnt == IMG_WIDTH - 1'b1) && (y_cnt == IMG_HEIGHT - 1'b1);  // 帧结束标志
wire frame_has_defect = (x_min_reg <= x_max_reg);  // 帧内是否存在缺陷（x_min≤x_max）

// 边缘倾斜判断：计算关键边缘的差值
wire [COORD_WID-1:0] y_min_edge_diff = (x_min_y_min_reg > x_max_y_min_reg) ? 
                                       (x_min_y_min_reg - x_max_y_min_reg) : 
                                       (x_max_y_min_reg - x_min_y_min_reg);
wire [COORD_WID-1:0] x_min_edge_diff = (y_min_x_min_reg > y_max_x_min_reg) ? 
                                       (y_min_x_min_reg - y_max_x_min_reg) : 
                                       (y_max_x_min_reg - y_min_x_min_reg);
wire [COORD_WID-1:0] x_max_edge_diff = (y_min_x_max_reg > y_max_x_max_reg) ? 
                                       (y_min_x_max_reg - y_max_x_max_reg) : 
                                       (y_max_x_max_reg - y_min_x_max_reg);

// 缺陷形状分类（直线/内凹/外凸）
wire is_stright = (y_min_edge_diff < SLOPE_THRESHOLD) && (x_min_edge_diff < SLOPE_THRESHOLD);  // 直线
wire is_in      = (x_min_reg <= 10) && (x_max_reg > 0);  // 内凹（x_min靠近左边界）
wire is_out     = (x_max_reg >= 630) && (x_min_reg > 0); // 外凸（x_max靠近右边界）

// 内部寄存器：顶点坐标、中心坐标、tan/cos值、有效性
reg [COORD_WID-1:0] p1_x_reg, p1_y_reg, p2_x_reg, p2_y_reg;
reg [COORD_WID-1:0] p3_x_reg, p3_y_reg, p4_x_reg, p4_y_reg;
reg [COORD_WID-1:0] p_x_reg, p_y_reg;
reg [TAN_REG_WID-1:0] tan_thita_reg;   // tan值寄存器（驱动tan ROM地址）
reg [TAN_REG_WID-1:0] z_cos_thita_reg; // cos值寄存器（驱动cos ROM地址）
reg valid_reg;                         // 缺陷有效性寄存器
reg is_minus_reg;                      // 正负标志寄存器

// 计算x_min与y_min两点的距离及坐标差值（用于tan值计算）
wire signed [COORD_WID-1:0] dx_1 = x_min_reg - y_min_x_min_reg;
wire signed [COORD_WID-1:0] dy_1 = x_min_y_min_reg - y_min_reg;
wire [COORD_WID-1:0] abs_dx_1 = (dx_1 < 0) ? -dx_1 : dx_1;
wire [COORD_WID-1:0] abs_dy_1 = (dy_1 < 0) ? -dy_1 : dy_1;
wire [COORD_WID-1:0] max_v_1 = (abs_dx_1 > abs_dy_1) ? abs_dx_1 : abs_dy_1;
wire [COORD_WID-1:0] min_v_1 = (abs_dx_1 > abs_dy_1) ? abs_dy_1 : abs_dx_1;
wire [COORD_WID-1:0] distance_approx_1 = max_v_1 
                                       + (min_v_1 >> 2) 
                                       + (min_v_1 >> 3);

// 计算x_max与y_min两点的距离及坐标差值（用于正负判断）
wire signed [COORD_WID-1:0] dx_2 = x_max_reg - y_min_x_max_reg;
wire signed [COORD_WID-1:0] dy_2 = x_max_y_min_reg - y_min_reg;
wire [COORD_WID-1:0] abs_dx_2 = (dx_2 < 0) ? -dx_2 : dx_2;
wire [COORD_WID-1:0] abs_dy_2 = (dy_2 < 0) ? -dy_2 : dy_2;
wire [COORD_WID-1:0] max_v_2 = (abs_dx_2 > abs_dy_2) ? abs_dx_2 : abs_dy_2;
wire [COORD_WID-1:0] min_v_2 = (abs_dx_2 > abs_dy_2) ? abs_dy_2 : abs_dx_2;
wire [COORD_WID-1:0] distance_approx_2 = max_v_2 
                                       + (min_v_2 >> 2) 
                                       + (min_v_2 >> 3);

// tan值计算（×64放大，避免小数丢失）
wire [TAN_REG_WID-1:0] dy_mul_64 = (distance_approx_1 > distance_approx_2) ? (abs_dy_1 << 6) : (abs_dy_2 << 6);
wire [TAN_REG_WID-1:0] dx_mul     = (distance_approx_1 > distance_approx_2) ? abs_dx_1 : abs_dx_2;
wire is_minus_wire                = (distance_approx_1 > distance_approx_2) ? 1'b1 : 1'b0;  // 正负标志
wire [TAN_REG_WID-1:0] tan_thita  = (dx_mul == 0) ? 16'd4095 : (dy_mul_64 / dx_mul);  // dx=0时设最大避免除零

// 计算当前delta_x（用于当set_template_flag=1时作为新除数）
wire [COORD_WID-1:0] delta_x_current = (distance_approx_1 > distance_approx_2) ? distance_approx_1 : distance_approx_2;

// -------------------------- 新增：可切换的除数寄存器 --------------------------
reg [COORD_WID-1:0] divisor_reg;  // 存储当前除数（默认Z_DELTA_X，可被delta_x_current更新）

// 除数寄存器控制逻辑：
// - set_template_flag=1：将当前delta_x_current存入divisor_reg（更新除数）
// - set_template_flag=0：保持除数不变（默认Z_DELTA_X或上次更新值）
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        divisor_reg <= Z_DELTA_X;  // 复位时初始化为默认除数
    end else if (set_template_flag == 1'b1) begin
        divisor_reg <= delta_x_current;  // 触发信号有效时，除数更新为当前delta_x
    end
    // else：保持不变，即使用默认值或上次更新的值
end

// cos值计算（基于投影长边长）

wire [20:0] delta_longside_mul_4096 = delta_x_current << 12;  // 被除数仍为当前delta_x计算值
wire [TAN_REG_WID-1:0] z_cos_thita = (divisor_reg == 0) ? 16'd0 : (delta_longside_mul_4096 / divisor_reg);

// 帧结束时锁存顶点坐标、tan/cos值（每帧更新一次）
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        // 复位初始化所有内部寄存器（避免不定态）
        {p1_x_reg, p1_y_reg, p2_x_reg, p2_y_reg, p3_x_reg, p3_y_reg, p4_x_reg, p4_y_reg} <= 0;
        p_x_reg <= 0;  p_y_reg <= 0;  tan_thita_reg <= 0;  z_cos_thita_reg <= 0;
        valid_reg <= 0;  is_minus_reg <= 1'b1;
    end else if (frame_end_flag) begin
        // 帧结束，根据缺陷形状锁存顶点坐标
        if(is_stright)begin  // 
            p1_x_reg <= x_min_reg;        p1_y_reg <= x_min_y_min_reg;
            p2_x_reg <= x_max_reg;        p2_y_reg <= x_max_y_min_reg;
            p3_x_reg <= y_max_x_min_reg;  p3_y_reg <= y_max_reg;
            p4_x_reg <= y_max_x_max_reg;  p4_y_reg <= y_max_reg;
            is_minus_reg <= 1'b1;
            tan_thita_reg <= 16'd4095;    // 直线tan值设最大
            z_cos_thita_reg <= z_cos_thita;
        end else if(is_in)begin  // 
            p1_x_reg <= x_min_reg;        p1_y_reg <= x_min_y_min_reg;
            p2_x_reg <= x_max_reg;        p2_y_reg <= x_max_y_min_reg;
            p3_x_reg <= x_min_reg;        p3_y_reg <= x_min_y_max_reg;
            p4_x_reg <= y_max_x_max_reg;  p4_y_reg <= y_max_reg;
            is_minus_reg <= 1'b1;
            tan_thita_reg <= 16'd0;       // 内凹tan值设0
            z_cos_thita_reg <= 16'd0;
        end else if(is_out)begin  // 
            p1_x_reg <= x_min_reg;        p1_y_reg <= x_min_y_min_reg;
            p2_x_reg <= x_max_reg;        p2_y_reg <= x_max_y_min_reg;
            p3_x_reg <= y_max_x_min_reg;  p3_y_reg <= y_max_reg;
            p4_x_reg <= x_max_reg;        p4_y_reg <= x_max_y_max_reg;
            is_minus_reg <= 1'b1;
            //tan_thita_reg <= tan_thita;    // 锁存计算的tan值
            //z_cos_thita_reg <= z_cos_thita;
        end else begin  // 
            p1_x_reg <= x_min_reg;        p1_y_reg <= x_min_y_min_reg;
            p2_x_reg <= x_max_reg;        p2_y_reg <= x_max_y_min_reg;
            p3_x_reg <= y_min_x_min_reg;  p3_y_reg <= y_min_reg;
            p4_x_reg <= y_max_x_max_reg;  p4_y_reg <= y_max_reg;
            is_minus_reg <= is_minus_wire; // 锁存正负标志
            tan_thita_reg <= tan_thita;    // 锁存计算的tan值
            z_cos_thita_reg <= z_cos_thita;
        end
        // 锁存缺陷中心坐标（取x/y极值的中点）
        p_x_reg <= (x_max_reg + x_min_reg + 1) >> 1;
        p_y_reg <= (y_max_reg + y_min_reg + 1) >> 1;
        valid_reg <= frame_has_defect;  // 锁存缺陷有效性
    end
end

/////////////////////////////////////////////////////////////////////////////////////
// 4. tan ROM接口（angle_rom）：地址生成、数据锁存
/////////////////////////////////////////////////////////////////////////////////////
reg [11:0] rom_addr_reg;          // tan ROM地址寄存器（12位，匹配4096深度）
wire [ANGLE_WID-1:0] rom_tan_data;// tan ROM原始输出数据（7位，对应0~89°）

// tan ROM地址生成（从tan_thita_reg取低12位，适配ROM深度）
always @(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        rom_addr_reg <= 12'd0;
    else
        rom_addr_reg <= tan_thita_reg[11:0];

// 例化tan ROM（紫光同创DRM Based ROM，参数需与IP配置一致）
angle_rom angle_rom_inst (
    .addr   (rom_addr_reg),    // ROM地址（输入）
    .clk    (pixclk_in),       // 时钟（与模块时钟同步）
    .rst    (~rstn_out),       // ROM复位（active-high，与模块复位极性匹配）
    .rd_data(rom_tan_data)     // ROM数据输出（7位角度值）
);

// tan ROM数据锁存（同步时钟，确保数据稳定）
always @(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        tan_rom_data_reg <= 7'd0;  // 复位时锁存数据置0
    else
        tan_rom_data_reg <= rom_tan_data;  // 每时钟沿锁存ROM输出

/////////////////////////////////////////////////////////////////////////////////////
// 5. cos ROM接口（z_angle_rom）：地址生成、数据锁存
/////////////////////////////////////////////////////////////////////////////////////
reg [11:0] rom_addr_reg_zcos;     // cos ROM地址寄存器（12位，匹配4096深度）
wire [ANGLE_WID-1:0] rom_cos_data;// cos ROM原始输出数据（7位，对应0~89°）

// cos ROM地址生成（从z_cos_thita_reg取低12位，适配ROM深度）
always @(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        rom_addr_reg_zcos <= 12'd0;
    else
        rom_addr_reg_zcos <= z_cos_thita_reg[11:0];

// 例化cos ROM（紫光同创DRM Based ROM，参数需与IP配置一致）
z_angle_rom z_angle_rom_inst (
    .addr   (rom_addr_reg_zcos),// ROM地址（输入）
    .clk    (pixclk_in),        // 时钟（与模块时钟同步）
    .rst    (~rstn_out),        // ROM复位（active-high，与模块复位极性匹配）
    .rd_data(rom_cos_data)      // ROM数据输出（7位角度值）
);

// cos ROM数据锁存（同步时钟，确保数据稳定）
always @(posedge pixclk_in or negedge rstn_out)
    if(!rstn_out)
        cos_rom_data_reg <= 7'd0;  // 复位时锁存数据置0
    else
        cos_rom_data_reg <= rom_cos_data;  // 每时钟沿锁存ROM输出

/////////////////////////////////////////////////////////////////////////////////////
// 6. ROM输出端口绑定（将内部信号映射到模块输出）
/////////////////////////////////////////////////////////////////////////////////////
assign tan_rom_addr = rom_addr_reg;      // tan ROM地址 → 模块输出
assign tan_rom_data = rom_tan_data;      // tan ROM原始数据 → 模块输出
assign cos_rom_addr = rom_addr_reg_zcos; // cos ROM地址 → 模块输出
assign cos_rom_data = rom_cos_data;      // cos ROM原始数据 → 模块输出

/////////////////////////////////////////////////////////////////////////////////////
// 7. 输出锁存与同步（将内部寄存器值映射到模块最终输出）
/////////////////////////////////////////////////////////////////////////////////////
reg [DELAY_CYCLES:0] vs_delay_chain, de_delay_chain;  // 场/数据使能延迟链（同步输出）
always @(posedge pixclk_in or negedge rstn_out)
    if (!rstn_out) begin
        vs_delay_chain <= 0;
        de_delay_chain <= 0;
    end else begin
        // 延迟链：确保输出与图像时序同步（延迟DELAY_CYCLES+1拍）
        vs_delay_chain <= {vs_delay_chain[DELAY_CYCLES-1:0], bin2_vs};
        de_delay_chain <= {de_delay_chain[DELAY_CYCLES-1:0], bin2_de};
    end

// 最终输出锁存（每时钟沿更新，与延迟链时序匹配）
always @(posedge pixclk_in or negedge rstn_out)
    if (!rstn_out) begin
        // 复位时最终输出置0
        {defect_p1_x, defect_p1_y, defect_p2_x, defect_p2_y,
         defect_p3_x, defect_p3_y, defect_p4_x, defect_p4_y} <= 0;
        center_position_x <= 0;  center_position_y <= 0;
        angle <= 0;  z_angle <= 0;  defect_valid <= 0;  is_minus <= 1'b1;
    end else begin
        // 映射内部锁存的顶点、中心坐标
        {defect_p1_x, defect_p1_y} <= {p1_x_reg, p1_y_reg};
        {defect_p2_x, defect_p2_y} <= {p2_x_reg, p2_y_reg};
        {defect_p3_x, defect_p3_y} <= {p3_x_reg, p3_y_reg};
        {defect_p4_x, defect_p4_y} <= {p4_x_reg, p4_y_reg};
        center_position_x <= p_x_reg;
        center_position_y <= p_y_reg;
// 关键修改：有缺陷→ROM角度，无缺陷→强制0°
        angle <= valid_reg ? tan_rom_data_reg : 7'd0;  // 无缺陷时angle=0°
        z_angle <= valid_reg ? cos_rom_data_reg : 7'd0;  // 无缺陷时z_angle也设0°（可选，按需求）
        // 映射缺陷有效性、正负标志
        defect_valid <= valid_reg;
        is_minus <= is_minus_reg; 
    end

// 同步后的场/数据使能输出
assign point_vs = vs_delay_chain[DELAY_CYCLES];
assign point_de = de_delay_chain[DELAY_CYCLES];

endmodule