// Simple FIFO module for buffering
module fifo #(
    parameter WIDTH = 32,
    parameter DEPTH = 16
)(
    input  logic clk,
    input  logic reset,
    input  logic wr_en,
    input  logic rd_en,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout,
    output logic full,
    output logic empty
);
    
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;
    
    assign full = (wr_ptr == (rd_ptr ^ (1 << ADDR_WIDTH)));
    assign empty = (wr_ptr == rd_ptr);
    
    // Write logic
    always_ff @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // Read logic
    always_ff @(posedge clk) begin
        if (reset) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
    
    // Show-ahead mode - data available when not empty
    assign dout = mem[rd_ptr[ADDR_WIDTH-1:0]];
    
endmodule

// Main switch fabric module
module very_simple_switch #(
    parameter DATA_WIDTH = 64,
    parameter INPUT_QTY = 8,
    parameter OUTPUT_QTY = 8
)(
    input  logic clk,
    input  logic reset,
    
    // Inputs
    input  logic [INPUT_QTY-1:0] data_in_valid,
    input  logic [INPUT_QTY-1:0][DATA_WIDTH-1:0] data_in,
    input  logic [INPUT_QTY-1:0][$clog2(OUTPUT_QTY)-1:0] data_in_destination,
    
    // Outputs
    output logic [OUTPUT_QTY-1:0] data_out_valid,
    output logic [OUTPUT_QTY-1:0][DATA_WIDTH-1:0] data_out
);

    localparam DEST_WIDTH = $clog2(OUTPUT_QTY);
    localparam FIFO_DATA_WIDTH = DATA_WIDTH + DEST_WIDTH;
    
    // FIFO signals for each input
    logic [INPUT_QTY-1:0] fifo_wr_en;
    logic [INPUT_QTY-1:0] fifo_rd_en;
    logic [INPUT_QTY-1:0][FIFO_DATA_WIDTH-1:0] fifo_din;
    logic [INPUT_QTY-1:0][FIFO_DATA_WIDTH-1:0] fifo_dout;
    logic [INPUT_QTY-1:0] fifo_full;
    logic [INPUT_QTY-1:0] fifo_empty;
    
    // Extracted data from FIFOs
    logic [INPUT_QTY-1:0][DATA_WIDTH-1:0] fifo_data;
    logic [INPUT_QTY-1:0][DEST_WIDTH-1:0] fifo_dest;
    
    // Output arbitration
    logic [OUTPUT_QTY-1:0][INPUT_QTY-1:0] output_requests;
    logic [OUTPUT_QTY-1:0][$clog2(INPUT_QTY)-1:0] selected_input;
    logic [OUTPUT_QTY-1:0] output_has_data;
    
    // Generate FIFOs for each input
    generate
        for (genvar i = 0; i < INPUT_QTY; i++) begin : gen_fifos
            // Pack data and destination for FIFO storage
            assign fifo_din[i] = {data_in[i], data_in_destination[i]};
            assign fifo_wr_en[i] = data_in_valid[i] && !fifo_full[i];
            
            // Unpack FIFO output
            assign fifo_data[i] = fifo_dout[i][FIFO_DATA_WIDTH-1:DEST_WIDTH];
            assign fifo_dest[i] = fifo_dout[i][DEST_WIDTH-1:0];
            
            fifo #(
                .WIDTH(FIFO_DATA_WIDTH),
                .DEPTH(16)
            ) input_fifo (
                .clk(clk),
                .reset(reset),
                .wr_en(fifo_wr_en[i]),
                .rd_en(fifo_rd_en[i]),
                .din(fifo_din[i]),
                .dout(fifo_dout[i]),
                .full(fifo_full[i]),
                .empty(fifo_empty[i])
            );
        end
    endgenerate
    
    // Build request matrix - which inputs want which outputs
    always_comb begin
        output_requests = '0;
        for (int i = 0; i < INPUT_QTY; i++) begin
            if (!fifo_empty[i] && fifo_dest[i] < DEST_WIDTH'(OUTPUT_QTY)) begin
                output_requests[fifo_dest[i]][i] = 1'b1;
            end
        end
    end
    
    // Priority arbitration for each output (lowest index wins)
    generate
        for (genvar out = 0; out < OUTPUT_QTY; out++) begin : gen_arbiters
            always_comb begin
                selected_input[out] = $clog2(INPUT_QTY)'(0);
                output_has_data[out] = 1'b0;
                
                // Find lowest index input requesting this output
                for (int i = 0; i < INPUT_QTY; i++) begin
                    if (output_requests[out][i]) begin
                        selected_input[out] = $clog2(INPUT_QTY)'(i);
                        output_has_data[out] = 1'b1;
                        break;
                    end
                end
            end
        end
    endgenerate
    
    // Generate FIFO read enables based on arbitration
    always_comb begin
        fifo_rd_en = '0;
        for (int out = 0; out < OUTPUT_QTY; out++) begin
            if (output_has_data[out]) begin
                fifo_rd_en[selected_input[out]] = 1'b1;
            end
        end
    end
    
    // Output assignment
    always_comb begin
        data_out_valid = '0;
        data_out = '0;
        
        for (int out = 0; out < OUTPUT_QTY; out++) begin
            if (output_has_data[out]) begin
                data_out_valid[out] = 1'b1;
                data_out[out] = fifo_data[selected_input[out]];
            end
        end
    end
    
endmodule
