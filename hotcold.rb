Any = "***"


def run_bprogram(bthreads, steps = 10)
  syncs = {}
  

  # התחלה: כל bthread נותן את ה-sync הראשון שלו
  bthreads.each do |bt| 
    syncs[bt] = bt.resume if bt.alive?
  end

  steps.times do
    requests = syncs.values.map { |s| s[:request] }.compact
    blocks   = syncs.values.map { |s| s[:block] }.compact

    allowed = requests.reject { |r| blocks.include?(r) }
    break if allowed.empty?

    chosen = allowed.sample
    puts "Chosen event: #{chosen}"

    # advance only fibers that were involved with chosen
    syncs.keys.each do |bt|
      sync = syncs[bt]

      if chosen == sync[:request] or chosen == sync[:wait] or sync[:wait] == Any
        syncs[bt] = bt.resume(chosen)
        if !bt.alive?
          syncs.delete(bt)
        end
      end
    end
  end
end

# Example bthreads
hot_bt = Fiber.new do
  3.times { Fiber.yield({ request: "HOT" }) }
end

cold_bt = Fiber.new do
  3.times { Fiber.yield({ request: "COLD" }) }
end

no_two_hot = Fiber.new do
  loop do
    Fiber.yield({ wait: "HOT" })
    Fiber.yield({ wait: "COLD", block: "HOT" })
  end
end

no_two_in_a_sequence = Fiber.new do
  e = Fiber.yield({ wait: Any})
  loop do
    e = Fiber.yield({ wait: Any, block: e })
  end
end

bthreads = [hot_bt, cold_bt, no_two_in_a_sequence]

run_bprogram(bthreads, 10)

