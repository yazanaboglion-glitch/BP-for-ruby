require 'cosmos'
require 'cosmos/script'

def run_bprogram(bthreads, actuate, steps = 20)
  syncs = {}

  # התחלה: הפעלת ה-bthreads (עם הגנה מפני קריסה בגרסאות ישנות)
  bthreads.each do |bt|
    res = bt.resume rescue nil
    syncs[bt] = res if res
  end

  steps.times do
    requests = syncs.values.map { |s| s[:request] }.flatten.compact
    blocks   = syncs.values.map { |s| s[:block] }.flatten.compact

    allowed = requests.reject { |r| blocks.include?(r) }
    break if allowed.empty?

    # בחירה אקראית
    chosen = allowed[rand(allowed.length)]
    
    puts "Chosen event: #{chosen}"
    actuate.call(chosen)
  

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

