def run_bprogram(bthreads, steps = 10)
  syncs = {}

  # התחלה: כל bthread נותן את ה-sync הראשון שלו
  bthreads.each do |bt|
    syncs[bt] = bt.resume if bt.alive?
  end

  steps.times do
    requests = syncs.values.map { |h| h[:request] }.compact
    blocks   = syncs.values.map { |h| h[:block] }.compact

    allowed = requests.reject { |r| blocks.include?(r) }
    break if allowed.empty?

    chosen = allowed.sample
    puts "Chosen event: #{chosen}"

    # advance only fibers that were involved with chosen
    syncs.keys.each do |bt|
      sync = syncs[bt]
      next unless sync.is_a?(Hash)

      involved = [sync[:request], sync[:wait], sync[:block]].compact.include?(chosen)
      if involved
        syncs[bt] = bt.resume
        if !bt.alive?
          syncs.delete(bt)
        end
      else
        # keep last sync if not advanced
        syncs[bt] = sync
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

bthreads = [hot_bt, cold_bt, no_two_hot]

run_bprogram(bthreads, 10)
