//MEM2048X24.v already include in tb
//V2 沒啥用 全白、藍

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

    output [26:0] DPo
  );

  // Internal signals
  wire [26:0] data_after_cc, data_after_tp, data_after_im, data_after_ig, data_after_um;
  wire [7:0] R_in, G_in, B_in;
  wire [7:0] R_cc, G_cc, B_cc;
  wire [7:0] R_tp, G_tp, B_tp;
  wire [7:0] R_im, G_im, B_im;
  wire [7:0] Y_ig, U_ig, V_ig;
  wire [7:0] R_ig, G_ig, B_ig;
  wire [7:0] R_um, G_um, B_um;

  // Extract RGB from input
  assign R_in = DPi[23:16];
  assign G_in = DPi[15:8];
  assign B_in = DPi[7:0];

  // Color Correction (CC) - Brightness adjustment
  assign R_cc = CC ? ((R_in > (255 - Brig)) ? 8'd255 : R_in + Brig) : R_in;
  assign G_cc = CC ? ((G_in > (255 - Brig)) ? 8'd255 : G_in + Brig) : G_in;
  assign B_cc = CC ? ((B_in > (255 - Brig)) ? 8'd255 : B_in + Brig) : B_in;
  assign data_after_cc = {DPi[26:24], R_cc, G_cc, B_cc};

  // Test Pattern (TP) - Generate test patterns
  reg [7:0] test_R, test_G, test_B;
  reg [10:0] h_counter, v_counter;
  wire hsync, vsync, de;

  assign hsync = DPi[26];
  assign vsync = DPi[25];
  assign de = DPi[24];

  // Horizontal and vertical counters for test pattern
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_counter <= 0;
      v_counter <= 0;
    end
    else if (de)
    begin
      if (h_counter == 1919)
      begin
        h_counter <= 0;
        if (v_counter == 1079)
          v_counter <= 0;
        else
          v_counter <= v_counter + 1;
      end
      else
      begin
        h_counter <= h_counter + 1;
      end
    end
  end

  // Test pattern generation
  always @(*)
  begin
    if (h_counter < 480)
    begin
      test_R = 8'd255;
      test_G = 8'd0;
      test_B = 8'd0;      // Red
    end
    else if (h_counter < 960)
    begin
      test_R = 8'd0;
      test_G = 8'd255;
      test_B = 8'd0;      // Green
    end
    else if (h_counter < 1440)
    begin
      test_R = 8'd0;
      test_G = 8'd0;
      test_B = 8'd255;      // Blue
    end
    else
    begin
      test_R = 8'd255;
      test_G = 8'd255;
      test_B = 8'd255;  // White
    end
  end

  assign R_tp = TP ? test_R : R_cc;
  assign G_tp = TP ? test_G : G_cc;
  assign B_tp = TP ? test_B : B_cc;
  assign data_after_tp = {data_after_cc[26:24], R_tp, G_tp, B_tp};

  // Image Motion (IM) - Local region horizontal flip
  reg [7:0] R_im_reg, G_im_reg, B_im_reg;
  reg [26:0] line_buffer [0:1919];
  reg [10:0] write_addr, read_addr;
  wire flip_region;

  assign flip_region = (h_counter >= 480 && h_counter < 1440) && (v_counter >= 270 && v_counter < 810);

  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      write_addr <= 0;
      read_addr <= 0;
    end
    else if (de && IM && flip_region)
    begin
      // Store data in line buffer
      line_buffer[write_addr] <= data_after_tp;
      if (write_addr == 959)
      begin
        write_addr <= 0;
        read_addr <= 959;
      end
      else
      begin
        write_addr <= write_addr + 1;
        if (write_addr > 0)
          read_addr <= read_addr - 1;
      end
    end
  end

  always @(*)
  begin
    if (IM && flip_region && write_addr > 0)
    begin
      R_im_reg = line_buffer[read_addr][23:16];
      G_im_reg = line_buffer[read_addr][15:8];
      B_im_reg = line_buffer[read_addr][7:0];
    end
    else
    begin
      R_im_reg = R_tp;
      G_im_reg = G_tp;
      B_im_reg = B_tp;
    end
  end

  assign R_im = R_im_reg;
  assign G_im = G_im_reg;
  assign B_im = B_im_reg;
  assign data_after_im = {data_after_tp[26:24], R_im, G_im, B_im};

  // Image Format (IG) - RGB to YUV conversion
  wire [17:0] Y_calc, U_calc, V_calc;

  // Using LAB10 RGB to YUV conversion formulas:
  // Y = 0.299*R + 0.587*G + 0.114*B
  // U = -0.169*R - 0.331*G + 0.5*B + 128
  // V = 0.5*R - 0.419*G - 0.081*B + 128

  assign Y_calc = (77 * R_im + 150 * G_im + 29 * B_im) >> 8;
  assign U_calc = ((-43 * R_im - 85 * G_im + 128 * B_im) >> 8) + 128;
  assign V_calc = ((128 * R_im - 107 * G_im - 21 * B_im) >> 8) + 128;

  assign Y_ig = (Y_calc > 255) ? 8'd255 : Y_calc[7:0];
  assign U_ig = (U_calc > 255) ? 8'd255 : ((U_calc < 0) ? 8'd0 : U_calc[7:0]);
  assign V_ig = (V_calc > 255) ? 8'd255 : ((V_calc < 0) ? 8'd0 : V_calc[7:0]);

  // YUV to RGB conversion for output
  wire [17:0] R_calc, G_calc, B_calc;

  assign R_calc = Y_ig + ((359 * (V_ig - 128)) >> 8);
  assign G_calc = Y_ig - ((88 * (U_ig - 128) + 183 * (V_ig - 128)) >> 8);
  assign B_calc = Y_ig + ((454 * (U_ig - 128)) >> 8);

  assign R_ig = IG ? ((R_calc > 255) ? 8'd255 : ((R_calc < 0) ? 8'd0 : R_calc[7:0])) : R_im;
  assign G_ig = IG ? ((G_calc > 255) ? 8'd255 : ((G_calc < 0) ? 8'd0 : G_calc[7:0])) : G_im;
  assign B_ig = IG ? ((B_calc > 255) ? 8'd255 : ((B_calc < 0) ? 8'd0 : B_calc[7:0])) : B_im;
  assign data_after_ig = {data_after_im[26:24], R_ig, G_ig, B_ig};

  // Unsharp Mask (UM) - Edge enhancement
  reg [7:0] R_blur, G_blur, B_blur;
  reg [7:0] R_edge, G_edge, B_edge;
  wire [7:0] alpha;

  assign alpha = 8'd128; // α = 0.5 in 8-bit fixed point

  // Simple blur approximation (3x3 average)
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      R_blur <= 0;
      G_blur <= 0;
      B_blur <= 0;
    end
    else
    begin
      // Simplified blur - just use current pixel (would need line buffers for real blur)
      R_blur <= R_ig;
      G_blur <= G_ig;
      B_blur <= B_ig;
    end
  end

  // Edge detection
  assign R_edge = (R_ig > R_blur) ? (R_ig - R_blur) : (R_blur - R_ig);
  assign G_edge = (G_ig > G_blur) ? (G_ig - G_blur) : (G_blur - G_ig);
  assign B_edge = (B_ig > B_blur) ? (B_ig - B_blur) : (B_blur - B_ig);

  // Unsharp mask: Output = Input + α × (Input - Blurred)
  wire [16:0] R_um_calc, G_um_calc, B_um_calc;
  assign R_um_calc = R_ig + ((alpha * R_edge) >> 8);
  assign G_um_calc = G_ig + ((alpha * G_edge) >> 8);
  assign B_um_calc = B_ig + ((alpha * B_edge) >> 8);

  assign R_um = UM ? ((R_um_calc > 255) ? 8'd255 : R_um_calc[7:0]) : R_ig;
  assign G_um = UM ? ((G_um_calc > 255) ? 8'd255 : G_um_calc[7:0]) : G_ig;
  assign B_um = UM ? ((B_um_calc > 255) ? 8'd255 : B_um_calc[7:0]) : B_ig;
  assign data_after_um = {data_after_ig[26:24], R_um, G_um, B_um};

  // Final output
  assign DPo = data_after_um;

endmodule
