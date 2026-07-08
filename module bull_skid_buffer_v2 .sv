module bull_skid_buffer_v2 (

    input logic clk,
    input logic rstn,

    //modul slave rolu aldıgındaki I/O'lar

    input logic s_axis_tlast,
    input logic s_axis_tvalid,
    input logic [3:0] s_axis_tkeep,
    input logic [31:0] s_axis_tdata,

    output logic s_axis_tready,

    //modul master rolu yapparken I/O'lar

    input logic m_axis_tready,

    output logic m_axis_tlast,
    output logic m_axis_tvalid,
    output logic [3:0] m_axis_tkeep,
    output logic [31:0] m_axis_tdata



);

logic [39:0] skid_reg; //yedek register [39:8] --->tdata  [7:4] -----> tkeep [0] ----->tlast 

logic [2:0] state;

localparam EMPTY = 3'b001, // buffer icerisindeki iki registerıbn ikisi de bos
           HALF  = 3'b010, // registerlardan biri dolu
           FULL  = 3'b100; // registerın ikisi de dolu


always_ff@(posedge clk or negedge rstn) begin

    if(!rstn)begin 
        s_axis_tready <= 0;
        m_axis_tlast  <= 0;
        m_axis_tvalid <= 0;
        m_axis_tkeep  <= 4'd0;
        m_axis_tdata  <= 32'd0;

        skid_reg <= 40'd0;

        state <= EMPTY;
    end

    else begin

        case(state) 

            EMPTY: begin 
                s_axis_tready <= 1;

                if(s_axis_tvalid && s_axis_tready) begin 
                     
                     m_axis_tdata  <= s_axis_tdata;
                     m_axis_tkeep  <= s_axis_tkeep;
                     m_axis_tlast  <= s_axis_tlast;
                     m_axis_tvalid <= 1;

                     state <= HALF;
       
                  
                end

                else begin 

                    m_axis_tdata  <= m_axis_tdata;
                    m_axis_tkeep  <= m_axis_tkeep;
                    m_axis_tlast  <= m_axis_tlast;
                    m_axis_tvalid <= 0;
                    
                    state <= EMPTY;
                end


            end

            HALF: begin 

                if(s_axis_tvalid && s_axis_tready )begin 

                    if(m_axis_tready && m_axis_tvalid) begin 

                        m_axis_tdata  <= s_axis_tdata;
                        m_axis_tkeep  <= s_axis_tkeep;
                        m_axis_tlast  <= s_axis_tlast;
                        m_axis_tvalid <= 1;

                        s_axis_tready <= 1;

                        state <= HALF;
                    end

                    else begin 

                        skid_reg[39:8] <= s_axis_tdata;
                        skid_reg[7:4]  <= s_axis_tkeep;
                        skid_reg[0]    <= s_axis_tlast;

                        m_axis_tvalid <= 1;

                        s_axis_tready <= 0;

                        state <= FULL;
                    end
                end

                else begin 

                    if(m_axis_tready && m_axis_tvalid) begin

                        m_axis_tdata  <= m_axis_tdata;
                        m_axis_tkeep  <= m_axis_tkeep;
                        m_axis_tlast  <= m_axis_tlast;
                        m_axis_tvalid <= 0;

                        s_axis_tready <= 1;

                        state <= EMPTY;


                    end 

                    else begin

                        m_axis_tdata  <= m_axis_tdata;
                        m_axis_tkeep  <= m_axis_tkeep;
                        m_axis_tlast  <= m_axis_tlast;
                        m_axis_tvalid <= 1;

                        s_axis_tready <= 1;

                        state <= HALF;
                    end
                end

            end

            FULL:begin 

                if(m_axis_tready && m_axis_tvalid) begin 

                    m_axis_tdata  <= skid_reg[39:8];
                    m_axis_tkeep <= skid_reg[7:4];
                    m_axis_tlast  <= skid_reg[0];
                    m_axis_tvalid <= 1;

                    s_axis_tready <= 1;

                    state <= HALF;
                end

                else begin 
                    
                    m_axis_tdata  <= m_axis_tdata;
                    m_axis_tkeep  <= m_axis_tkeep;
                    m_axis_tlast  <= m_axis_tlast;
                    m_axis_tvalid <= 1;

                    s_axis_tready <= 0;

                    skid_reg <= skid_reg;

                    state <= FULL;


                end
            end

            default:begin 

               s_axis_tready <= 0;
               m_axis_tlast  <= 0;
               m_axis_tvalid <= 0;
               m_axis_tkeep  <= 4'd0;
               m_axis_tdata  <= 32'd0;

               skid_reg <= 40'd0;

               state <= EMPTY;
            end
        endcase
    end
end

endmodule