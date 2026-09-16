module blinky (
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] led
);
  logic [23:0] cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= '0;
      led <= '0;
    end else begin
      cnt <= cnt + 1'b1;
      if (cnt == '1) led <= led + 1'b1;
    end
  end
endmodule
