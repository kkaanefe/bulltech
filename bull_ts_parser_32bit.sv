module bull_ts_parser_32bit (

input logic clk,
input logic rst, // acitve high belki low a döneriz kodun diğer kısımlarına da bakmak lazım 

// AXI-STREAM
taxi_axis_if.snk  s_axis, // 32 bit genişlik
taxi_axis_if.src  frame_m_axis, // 32 bit genişlik
taxi_axis_if.src  ts_m_axis // 64 bit genişlik

);


logic [31:0] swapped_ts; // time stampin sağdaki bitinin lsb olması için kullanılacak ara değişken

logic [63:0] buffer; // time stampin tüm byteları gelen kadar bytler burada tutulur

logic ts_m_axis_handshake;

logic frame_m_axis_handshake;

logic [2:0] state;

localparam IDLE      = 3'b001,
           COLLECT   = 3'b010,
           DRAIN     = 3'b100;
          

assign swapped_ts = {s_axis.tdata[7:0], s_axis.tdata[15:8], s_axis.tdata[23:16], s_axis.tdata[31:24]};

assign ts_m_axis.tdata = buffer;

assign ts_m_axis_handshake = ts_m_axis.tvalid && ts_m_axis.tready;

assign frame_m_axis_handshake = frame_m_axis.tvalid && frame_m_axis.tready;

assign s_axis.tready = !rst && ((state == DRAIN) ? frame_m_axis.tready : ts_m_axis.tready);


always_ff@(posedge clk or posedge rst) begin 

    if(rst) 
        ts_m_axis.tvalid <= 1'b0;
    
    else if((state == COLLECT) && s_axis.tvalid && s_axis.tready)
        ts_m_axis.tvalid <= 1'b1;
    
    else if(ts_m_axis_handshake)
        ts_m_axis.tvalid <= 1'b0;
    
    else 
        ts_m_axis.tvalid <= ts_m_axis.tvalid;
end


always_ff@(posedge clk or posedge rst) begin 

    if(rst)
        frame_m_axis.tvalid <= 1'b0;
    
    else if((state == DRAIN) && s_axis.tvalid && s_axis.tready)
        frame_m_axis.tvalid <= 1'b1;

    else if (frame_m_axis_handshake)
        frame_m_axis.tvalid <= 1'b0;
    
    else 
        frame_m_axis.tvalid <= frame_m_axis.tvalid;
end


always_ff@(posedge clk or posedge rst) begin 

    if(rst) begin
        state <= IDLE;
    end

    else begin 

        case(state)

        IDLE: begin 

            if(s_axis.tvalid && s_axis.tready) begin 

                buffer[63:32] <= swapped_ts;
                ts_m_axis.tkeep[7:4] <= s_axis.tkeep;

                state <= COLLECT;
            end

            else
                state <= IDLE;
        end

        COLLECT:begin 

            if(s_axis.tvalid && s_axis.tready) begin 

                buffer[31:0] <= swapped_ts;
                ts_m_axis.tkeep[3:0] <= s_axis.tkeep;
                ts_m_axis.tlast <= 1'b1;

                state <= DRAIN;
            end

            else
                state <= COLLECT;

        end

        DRAIN:begin 

            if(s_axis.tvalid && s_axis.tready) begin 

                if(s_axis.tlast) begin 

                    frame_m_axis.tdata <= s_axis.tdata;
                    frame_m_axis.tkeep <= s_axis.tkeep;
                    frame_m_axis.tlast <= s_axis.tlast;

                    state <= IDLE;
                end

                else begin 

                    frame_m_axis.tdata <= s_axis.tdata;
                    frame_m_axis.tkeep <= s_axis.tkeep;
                    frame_m_axis.tlast <= s_axis.tlast;                    

                    state <= DRAIN;
                end
            end

            else
                state <= DRAIN;
        end
        endcase
    end
end

endmodule

