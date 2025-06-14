// 對一點點 v3
module HDL_final(
    input clk,
    input rst_n,
    input CC,
    input TP,
    input IM,
    input IG,
    input UM,
    input [7:0] Brig,
    input [26:0] DPi,

    input [2:0] Sync_IM,
    input [2:0] Sync_IG,
    input [2:0] Sync_UM,

    output reg [26:0] DPo
  );

  // 位置計數器
  reg [10:0] h_cnt, v_cnt;

  // Pipeline stages
  reg [26:0] stage1_data, stage2_data, stage3_data, stage4_data, stage5_data;
  reg [10:0] h_cnt_d1, v_cnt_d1, h_cnt_d2, v_cnt_d2, h_cnt_d3, v_cnt_d3, h_cnt_d4, v_cnt_d4;

  // Stage 1: CC相關變數
  reg [7:0] cc_r, cc_g, cc_b;

  // Stage 2: TP相關變數
  reg [7:0] tp_r, tp_g, tp_b;

  // Stage 3: IM相關變數
  reg [7:0] im_r, im_g, im_b;

  // Stage 4: IG相關變數
  reg [7:0] ig_r, ig_g, ig_b;

  // Stage 5: UM相關變數
  reg [7:0] um_r, um_g, um_b;
  reg [15:0] enhanced_r, enhanced_g, enhanced_b;

  // 記憶體控制信號
  wire [10:0] mem1_r_addr, mem1_w_addr, mem2_r_addr, mem2_w_addr;
  wire [23:0] mem1_din, mem2_din;
  wire [23:0] mem1_dout, mem2_dout;
  wire mem1_web, mem1_re, mem1_cs, mem2_web, mem2_re, mem2_cs;

  // 記憶體實例化
  MEM2048X24 mem1 (
               .CK(clk),
               .CS(mem1_cs),
               .WEB(mem1_web),
               .RE(mem1_re),
               .R_ADDR(mem1_r_addr),
               .W_ADDR(mem1_w_addr),
               .D_IN(mem1_din),
               .D_OUT(mem1_dout)
             );

  MEM2048X24 mem2 (
               .CK(clk),
               .CS(mem2_cs),
               .WEB(mem2_web),
               .RE(mem2_re),
               .R_ADDR(mem2_r_addr),
               .W_ADDR(mem2_w_addr),
               .D_IN(mem2_din),
               .D_OUT(mem2_dout)
             );

  //=== 位置計數器 ===
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt <= 0;
      v_cnt <= 0;
    end
    else if (DPi[24])
    begin // den有效時計數
      if (h_cnt == 1919)
      begin
        h_cnt <= 0;
        if (v_cnt == 1079)
        begin
          v_cnt <= 0;
        end
        else
        begin
          v_cnt <= v_cnt + 1;
        end
      end
      else
      begin
        h_cnt <= h_cnt + 1;
      end
    end
    else if (DPi[26])
    begin // vsync重置
      h_cnt <= 0;
      v_cnt <= 0;
    end
  end

  // Pipeline計數器延遲
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt_d1 <= 0;
      v_cnt_d1 <= 0;
      h_cnt_d2 <= 0;
      v_cnt_d2 <= 0;
      h_cnt_d3 <= 0;
      v_cnt_d3 <= 0;
      h_cnt_d4 <= 0;
      v_cnt_d4 <= 0;
    end
    else
    begin
      h_cnt_d1 <= h_cnt;
      v_cnt_d1 <= v_cnt;
      h_cnt_d2 <= h_cnt_d1;
      v_cnt_d2 <= v_cnt_d1;
      h_cnt_d3 <= h_cnt_d2;
      v_cnt_d3 <= v_cnt_d2;
      h_cnt_d4 <= h_cnt_d3;
      v_cnt_d4 <= v_cnt_d3;
    end
  end

  //=== Stage 1: CC (Color Correction) ===
  // 直接在RGB域進行亮度調整
  always @(*)
  begin
    if (CC)
    begin
      // 分4個區域調整亮度
      if (h_cnt < 480)
      begin        // 第一部分: 減少 1.0*Brig
        cc_r = (DPi[23:16] > Brig) ? (DPi[23:16] - Brig) : 8'd0;
        cc_g = (DPi[15:8] > Brig) ? (DPi[15:8] - Brig) : 8'd0;
        cc_b = (DPi[7:0] > Brig) ? (DPi[7:0] - Brig) : 8'd0;
      end
      else if (h_cnt < 960)
      begin // 第二部分: 減少 0.5*Brig
        cc_r = (DPi[23:16] > (Brig >> 1)) ? (DPi[23:16] - (Brig >> 1)) : 8'd0;
        cc_g = (DPi[15:8] > (Brig >> 1)) ? (DPi[15:8] - (Brig >> 1)) : 8'd0;
        cc_b = (DPi[7:0] > (Brig >> 1)) ? (DPi[7:0] - (Brig >> 1)) : 8'd0;
      end
      else if (h_cnt < 1440)
      begin // 第三部分: 增加 0.5*Brig
        cc_r = ((DPi[23:16] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[23:16] + (Brig >> 1));
        cc_g = ((DPi[15:8] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[15:8] + (Brig >> 1));
        cc_b = ((DPi[7:0] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[7:0] + (Brig >> 1));
      end
      else
      begin                   // 第四部分: 增加 1.0*Brig
        cc_r = ((DPi[23:16] + Brig) > 255) ? 8'd255 : (DPi[23:16] + Brig);
        cc_g = ((DPi[15:8] + Brig) > 255) ? 8'd255 : (DPi[15:8] + Brig);
        cc_b = ((DPi[7:0] + Brig) > 255) ? 8'd255 : (DPi[7:0] + Brig);
      end
    end
    else
    begin
      cc_r = DPi[23:16];
      cc_g = DPi[15:8];
      cc_b = DPi[7:0];
    end
  end

  // Stage 1 register
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage1_data <= 0;
    end
    else
    begin
      stage1_data <= {DPi[26:24], cc_r, cc_g, cc_b};
    end
  end

  //=== Stage 2: TP (Test Pattern) ===
  always @(*)
  begin
    if (TP)
    begin
      // 簡單的測試圖案
      if (h_cnt_d1 < 480)
      begin
        tp_r = 8'd255;
        tp_g = 8'd0;
        tp_b = 8'd0;      // Red
      end
      else if (h_cnt_d1 < 960)
      begin
        tp_r = 8'd0;
        tp_g = 8'd255;
        tp_b = 8'd0;      // Green
      end
      else if (h_cnt_d1 < 1440)
      begin
        tp_r = 8'd0;
        tp_g = 8'd0;
        tp_b = 8'd255;      // Blue
      end
      else
      begin
        tp_r = 8'd255;
        tp_g = 8'd255;
        tp_b = 8'd255;  // White
      end
    end
    else
    begin
      tp_r = stage1_data[23:16];
      tp_g = stage1_data[15:8];
      tp_b = stage1_data[7:0];
    end
  end

  // Stage 2 register
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage2_data <= 0;
    end
    else
    begin
      stage2_data <= {stage1_data[26:24], tp_r, tp_g, tp_b};
    end
  end

  //=== Stage 3: IM (Image Motion) ===
  // 暫時保持簡單的透傳
  always @(*)
  begin
    im_r = stage2_data[23:16];
    im_g = stage2_data[15:8];
    im_b = stage2_data[7:0];
  end

  // Stage 3 register
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage3_data <= 0;
    end
    else
    begin
      stage3_data <= {stage2_data[26:24], im_r, im_g, im_b};
    end
  end

  //=== Stage 4: IG (Image Format) ===
  // RGB to YUV to RGB 轉換
  wire [15:0] yuv_y, yuv_u, yuv_v;
  wire [15:0] rgb_r, rgb_g, rgb_b;
  wire signed [8:0] u_diff, v_diff;

  // RGB to YUV 轉換 (LAB10公式)
  // Y = 0.299*R + 0.587*G + 0.114*B
  // U = -0.169*R - 0.331*G + 0.5*B + 128
  // V = 0.5*R - 0.419*G - 0.081*B + 128
  assign yuv_y = (77 * stage3_data[23:16] + 150 * stage3_data[15:8] + 29 * stage3_data[7:0]);
  assign yuv_u = ((128 * stage3_data[7:0] - 43 * stage3_data[23:16] - 85 * stage3_data[15:8]) + (128 << 8));
  assign yuv_v = ((128 * stage3_data[23:16] - 107 * stage3_data[15:8] - 21 * stage3_data[7:0]) + (128 << 8));

  // YUV to RGB 轉換 (LAB10公式)
  // R = Y + 1.402*(V-128)
  // G = Y - 0.344*(U-128) - 0.714*(V-128)
  // B = Y + 1.772*(U-128)
  assign u_diff = (yuv_u >> 8) - 128;
  assign v_diff = (yuv_v >> 8) - 128;

  assign rgb_r = (yuv_y >> 8) + ((359 * v_diff) >> 8);
  assign rgb_g = (yuv_y >> 8) - ((88 * u_diff + 183 * v_diff) >> 8);
  assign rgb_b = (yuv_y >> 8) + ((454 * u_diff) >> 8);

  always @(*)
  begin
    if (IG)
    begin
      // 限制RGB範圍並輸出
      ig_r = (rgb_r[15]) ? 8'd0 : (rgb_r > 255) ? 8'd255 : rgb_r[7:0];
      ig_g = (rgb_g[15]) ? 8'd0 : (rgb_g > 255) ? 8'd255 : rgb_g[7:0];
      ig_b = (rgb_b[15]) ? 8'd0 : (rgb_b > 255) ? 8'd255 : rgb_b[7:0];
    end
    else
    begin
      ig_r = stage3_data[23:16];
      ig_g = stage3_data[15:8];
      ig_b = stage3_data[7:0];
    end
  end

  // Stage 4 register
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage4_data <= 0;
    end
    else
    begin
      stage4_data <= {stage3_data[26:24], ig_r, ig_g, ig_b};
    end
  end

  //=== Stage 5: UM (Unsharp Mask) ===
  // 使用記憶體2實作邊緣增強
  assign mem2_cs = 1'b1;
  assign mem2_w_addr = h_cnt_d3;
  assign mem2_r_addr = h_cnt_d4;
  assign mem2_din = stage4_data[23:0];
  assign mem2_web = ~DPi[24];
  assign mem2_re = DPi[24];

  wire [7:0] blur_r, blur_g, blur_b;
  wire [7:0] edge_r, edge_g, edge_b;

  // 簡化的模糊 (使用前一個像素)
  assign blur_r = mem2_dout[23:16];
  assign blur_g = mem2_dout[15:8];
  assign blur_b = mem2_dout[7:0];

  // 邊緣檢測 (絕對差值)
  assign edge_r = (stage4_data[23:16] > blur_r) ? (stage4_data[23:16] - blur_r) : (blur_r - stage4_data[23:16]);
  assign edge_g = (stage4_data[15:8] > blur_g) ? (stage4_data[15:8] - blur_g) : (blur_g - stage4_data[15:8]);
  assign edge_b = (stage4_data[7:0] > blur_b) ? (stage4_data[7:0] - blur_b) : (blur_b - stage4_data[7:0]);

  always @(*)
  begin
    if (UM)
    begin
      // Unsharp Mask: Output = Input + α × Edge
      // 使用 Brig 作為 α 係數 (0~199% 範圍)
      enhanced_r = stage4_data[23:16] + ((Brig * edge_r) >> 8);
      enhanced_g = stage4_data[15:8] + ((Brig * edge_g) >> 8);
      enhanced_b = stage4_data[7:0] + ((Brig * edge_b) >> 8);

      // 限制輸出範圍
      um_r = (enhanced_r > 255) ? 8'd255 : enhanced_r[7:0];
      um_g = (enhanced_g > 255) ? 8'd255 : enhanced_g[7:0];
      um_b = (enhanced_b > 255) ? 8'd255 : enhanced_b[7:0];
    end
    else
    begin
      um_r = stage4_data[23:16];
      um_g = stage4_data[15:8];
      um_b = stage4_data[7:0];
    end
  end

  // Stage 5 register
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage5_data <= 0;
    end
    else
    begin
      stage5_data <= {stage4_data[26:24], um_r, um_g, um_b};
    end
  end

  // 記憶體1控制信號 (不使用)
  assign mem1_cs = 1'b0;
  assign mem1_web = 1'b1;
  assign mem1_re = 1'b0;
  assign mem1_w_addr = 11'b0;
  assign mem1_r_addr = 11'b0;
  assign mem1_din = 24'b0;

  //=== 最終輸出 ===
  // 根據功能開關選擇輸出階段
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      DPo <= 0;
    end
    else
    begin
      // 根據開啟的功能選擇對應階段的輸出
      if (UM)
        DPo <= stage5_data;
      else if (IG)
        DPo <= stage4_data;
      else if (IM)
        DPo <= stage3_data;
      else if (TP)
        DPo <= stage2_data;
      else
        DPo <= stage1_data;  // 只有CC功能時直接輸出stage1
    end
  end

endmodule
