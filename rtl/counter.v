module counter (
  input  clk,      
  input  rst_n,    
  input  en,       
  output [7:0] cnt 
);
  reg [7:0] cnt_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cnt_reg <= 8'h0;
    else if (en)
      cnt_reg <= cnt_reg + 1;
  end
  
  assign cnt = cnt_reg;
endmodule
