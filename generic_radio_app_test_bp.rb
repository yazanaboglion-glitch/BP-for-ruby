require 'cosmos'
require 'cosmos/script'
require "generic_radio_lib.rb"

safe_GENERIC_RADIO()
$N = 0

def actuate(e)
  if e== "HOT"
        # בדיוק הלוגיקה המקורית + שימוש ב N
    cmd_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT")
    
    cmd("GENERIC_RADIO GENERIC_RADIO_NOOP_CC with CCSDS_LENGTH #{$N+2}") 
    
    get_GENERIC_RADIO_hk()
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT == #{cmd_err_cnt+1}")

    $N = $N + 1
   end
   if e== "COLD"
     
    # בדיוק הלוגיקה המקורית + שימוש ב N
    cmd_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT")
    
    cmd("GENERIC_RADIO GENERIC_RADIO_NOOP_CC with CCSDS_FC #{6+$N}")
    
    get_GENERIC_RADIO_hk()
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_RADIO GENERIC_RADIO_HK_TLM CMD_ERR_COUNT == #{cmd_err_cnt+1}")

    $N = $N + 1
   end
end

def run_bprogram(bthreads, steps = 20)
  syncs = {}

  # התחלה: הפעלת ה-bthreads (עם הגנה מפני קריסה בגרסאות ישנות)
  bthreads.each do |bt|
    res = bt.resume rescue nil
    syncs[bt] = res if res
  end

  steps.times do
    requests = syncs.values.map { |s| s[:request] }.compact
    blocks   = syncs.values.map { |s| s[:block] }.compact

    allowed = requests.reject { |r| blocks.include?(r) }
    break if allowed.empty?

    # בחירה אקראית
    chosen = allowed[rand(allowed.length)]
    
    puts "Chosen event: #{chosen}"
    actuate(chosen)
  

    # קידום ה-Fibers
    syncs.keys.each do |bt|
      sync = syncs[bt]
      if chosen == sync[:request] or chosen == sync[:wait] or sync[:wait] == "***"
        
        # הרצת הצעד הבא. אם נכשל/נגמר - מחזיר nil ולא קורס
        res = bt.resume(chosen) rescue nil
        
        if res
          syncs[bt] = res
        else
          syncs.delete(bt)
        end
      end
    end
  end
end

# --- בדיקת HOT (שורות 37-44 מהקוד המקורי) ---
hot_bt = Fiber.new do
  loop do
    Fiber.yield({ :request => "HOT" })

  end
end

# --- בדיקת COLD (שורות 46-54 מהקוד המקורי) ---
cold_bt = Fiber.new do
  loop do
    Fiber.yield({ :request => "COLD" })

  end
end

# --- Interleaver (מונע רצף זהה) ---
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

# הפעלה
bthreads = [hot_bt, cold_bt, interleaver]
run_bprogram(bthreads, 20)

