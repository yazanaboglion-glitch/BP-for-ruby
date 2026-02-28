require 'cosmos'
require 'cosmos/script'
require "generic_torquer_lib.rb"
require 'bp_lib' 

$N = 0

def actuate(e)

  if e == "HK"
    puts "Executing: Housekeeping Request"
    get_generic_torquer_hk()
    $N = $N + 14
  end
  
  if e == "NOOP"
    puts "Executing: NOOP Command"
    generic_torquer_cmd("GENERIC_TORQUER GENERIC_TORQUER_NOOP_CC")
    $N = $N + 15
  end

  if e == "RESET"
    puts "Executing: Reset Counters Sequence"
    generic_torquer_cmd("GENERIC_TORQUER GENERIC_TORQUER_NOOP_CC")
    cmd("GENERIC_TORQUER GENERIC_TORQUER_RST_COUNTERS_CC")
    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == 0")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == 0")
    $N = $N + 13
  end

  if e == "BAD_LENGTH"
    
    cmd_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT")
    err_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT")
    
    val = ($N + 2)
    puts "Executing: Invalid Command (Bad Length: #{val})"
    cmd("GENERIC_TORQUER GENERIC_TORQUER_NOOP_CC with CCSDS_LENGTH #{val}")

    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == #{err_cnt + 1}")
    
    $N = $N + 12
  end

   if e == "BAD_COMMAND_CODES"
    
    cmd_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT")
    err_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT")
    
   
  
    val = (6 + $N)
    puts "Executing: Invalid Command (Bad FC: #{val})"
    cmd("GENERIC_TORQUER GENERIC_TORQUER_NOOP_CC with CCSDS_FC #{val}")
    

    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == #{err_cnt + 1}")
    
    $N = $N + 11
  end

end


hk_thread = Fiber.new do
  loop do
    Fiber.yield({ :request => "HK" })
  end
end

noop_thread = Fiber.new do
  loop do
    Fiber.yield({ :request => "NOOP" })
  end
end

reset_thread = Fiber.new do
  loop do
    Fiber.yield({ :request => "RESET" })
  end
end

bad_length_thread = Fiber.new do
  loop do
    Fiber.yield({ :request => "BAD_LENGTH" })
  end
end

bad_command_codes_thread = Fiber.new do
  loop do
    Fiber.yield({ :request => "BAD_COMMAND_CODES" })
  end
end


bthreads = [hk_thread, noop_thread, reset_thread, bad_length_thread, bad_command_codes_thread]
run_bprogram(bthreads, method(:actuate), total_steps=10)
