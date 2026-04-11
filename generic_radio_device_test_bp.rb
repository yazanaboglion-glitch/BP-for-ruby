require 'cosmos'
require 'cosmos/script'
require "generic_radio_lib.rb"
require 'bp_lib.rb'

safe_GENERIC_RADIO()
$N = 0
def actuate(e)

  if e== "INVALID_LENGTH"
        #    +   N
    cmd_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT")
    
    cmd("GENERIC_RADIO GENERIC_RADIO_NOOP_CC with CCSDS_LENGTH #{$N+2}") 
    
    get_GENERIC_RADIO_hk()
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT == #{cmd_err_cnt+1}")

    $N = $N + 1
   end
   if e== "INVALID_FUNCTION_CODE"
     
    #    +   N
    cmd_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT")
    
    cmd("GENERIC_RADIO GENERIC_RADIO_NOOP_CC with CCSDS_FC #{6+$N}")
    
    get_GENERIC_RADIO_hk()
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT == #{cmd_err_cnt+1}")

    $N = $N + 1
   end
end


valid_bt = Fiber.new do
  loop do
    Fiber.yield({ :request => "VALID" })

  end
end

invalid_bt = Fiber.new do
  loop do
    Fiber.yield({ :request => "INVALID" })

  end
end

interleaver = Fiber.new do
  last_event = nil
  loop do
    if last_event
      event = Fiber.yield({ :wait => "***", :block => last_event })
    else
      event = Fiber.yield({ :wait => "***" })
    end
    last_event = event
  end
end

# 
bthreads = [valid_bt, invalid_bt, interleaver]
run_bprogram(bthreads, method(:actuate), 20)

