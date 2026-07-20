module bull_fifo_two #(

    parameter DATA_WIDTH = 32,
    parameter DEPTH  = 4
    
    )(

    input logic clk, 
    input logic rstn,

    input logic [DATA_WIDTH-1:0] data_in,
    input logic read_enable, // 1 oldu?unda read_counter?n gösterdi?i registerdan veri okunur
    input logic write_enable,// data_in sinyalinin anlaml? olup olmad???n? bildiren sinyal

    output logic [DATA_WIDTH-1:0] data_out,
    output logic empty, // FIFO bo? ise 1 basar
    output logic full // FIFO registerlar? doldu?u zaman bunu d??ar?ya 1 olarak bildiren sinyal

);

localparam counter_bits = $clog2(DEPTH);

logic [DATA_WIDTH-1:0] registers [0:DEPTH-1];

logic [counter_bits:0] read_pointer;
logic [counter_bits:0] write_pointer;


assign empty = (read_pointer == write_pointer);
assign full = (read_pointer[counter_bits-1:0] == write_pointer[counter_bits-1:0]) && (read_pointer[counter_bits] ^ write_pointer[counter_bits]);

always_ff@(posedge clk or negedge rstn) begin

    if(!rstn) begin 
        write_pointer <= '0;
        read_pointer <= '0;
    end

    else begin 

        if(write_enable && ~full) begin 

            if(read_enable && ~empty) begin  // YAZILIR VE OKUNUR

                write_pointer <= write_pointer + 1;
                read_pointer <= read_pointer + 1;

                data_out <= registers[read_pointer];
                registers[write_pointer] <= data_in;

            end

            else begin // YAZILIR VE OKUNMAZ

                write_pointer <= write_pointer + 1;
                read_pointer <= read_pointer;

                registers[write_pointer] <= data_in;
            end
        end

        else begin 

            if(read_enable && ~empty) begin // YAZILMAZ VE OKUNUR

                write_pointer <= write_pointer;
                read_pointer <= read_pointer + 1;

                data_out <= registers[read_pointer];

                
            end

            else begin // YAZILMAZ VE OKUNMAZ

                write_pointer <= write_pointer;
                read_pointer <= read_pointer;

                
            end
        end
    end
end




endmodule