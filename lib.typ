// Internal states and counter
#let rates-state = state("wp-rates", (:))
#let currency-state = state("wp-currency", "CHF")
#let thousand-sep-state = state("wp-thousand-sep", "'")
#let digits-state = state("wp-digits", 0)
#let wp-round-state = state("wp-wp-round", 0)
#let wps-state = state("wp-records", ())
#let wp-counter = counter("wp-counter")

// Helper: consistent currency styling
#let fmt-price(amount, cur) = {
    let sep = thousand-sep-state.get()
    let decimals = digits-state.get()

    let num = if type(amount) == str { float(amount) } else { amount }
    let rounded = calc.round(num, digits: decimals)

    let s = str(rounded)
    let parts = s.split(".")
    let int-part = parts.at(0)

    // Pad decimal places to exactly 2 digits (e.g. 155 -> .00, 155.5 -> .50)
    let dec-part = if parts.len() > 1 { parts.at(1) } else { "" }
    if decimals > 0 {
    dec-part += "0" * calc.max(0, decimals - dec-part.len())
    dec-part = dec-part.slice(0, decimals)
    }

    // Handle negative values cleanly
    let is-neg = int-part.starts-with("-")
    let digits-only = if is-neg { int-part.slice(1) } else { int-part }

    // Insert Swiss thousands separator from right to left
    let formatted = ""
    let count = 0
    for digit in digits-only.clusters().rev() {
    if count > 0 and calc.rem(count, 3) == 0 {
        formatted = sep + formatted
    }
    formatted = digit + formatted
    count += 1
    }

    if is-neg { formatted = "-" + formatted }
    let final-num = if decimals > 0 { formatted + "." + dec-part } else { formatted }

    [#final-num #text(size: 0.85em)[#cur]]

}

/// Renders an overview table of all defined hourly rates
#let hourly-rates() = context {
  let rates = rates-state.get()
  let cur = currency-state.get()
  let round = wp-round-state.get()

  align(center,
    table(
      columns: (auto, auto),
      stroke: none,
      align: (right, right),
      ..rates
        .pairs()
        .map(((staff, rate)) => (
          [#staff:],
          [*#fmt-price(rate, cur)*]
        ))
        .flatten(),
    )
  )

  v(1em)
  if round != 0 {
      align(center, text(size: 0.85em)[Personell cost is rounded to the next #fmt-price(round, cur) for every work package.])
  }

}

/// Configures the global project rates and currency.
#let setup(rates: (:), currency: "CHF", thousand-seperator: "'", digits: 0, round: 0, show-rates: false) = {
    rates-state.update(rates)
    currency-state.update(currency)
    thousand-sep-state.update(thousand-seperator)
    digits-state.update(digits)
    wp-round-state.update(round)

    if show-rates {
        hourly-rates()
    }
}

/// Defines and renders a single Work Package
#let work-package(
  title,
  hours: (:),
  materials: 0,
  description: none,
  deliverables: (),
) = [
  #wp-counter.step()

  // Register raw WP data to state so totals can be computed anywhere
  #wps-state.update(wps => wps + ((
    title: title,
    hours: hours,
    materials: materials,
  ),))

  #context {
    let rates = rates-state.get()
    let cur = currency-state.get()
    let round = wp-round-state.get()

    // Calculate staff costs
    let staff-cost = 0
    for (person, h) in hours.pairs() {
      let r = rates.at(person, default: 0)
      staff-cost += h * r
    }
    if round != 0 {
        staff-cost = calc.ceil(staff-cost / round) * round
    }
    let total-cost = staff-cost + materials


    block(
      width: 100%,
      stroke: 0.75pt + luma(180),
      inset: 1.25em,
      radius: 0.4em,
      breakable: false,
      [
        #set text(size: 0.9em)
        #heading(level: 3, numbering: none)[
          WP#wp-counter.display("01"): #title
        ]

        #if description != none [
          #v(0.3em)
          #description
        ]

        #line(length: 100%, stroke: 0.5pt + luma(210))

        #if deliverables != none and deliverables.len() > 0 [
          *Deliverables:*
          #list(..deliverables)
          #v(0.3em)
          #line(length: 100%, stroke: 0.5pt + luma(210))
        ]

        *Personnel Allocation:*
        #if hours.len() > 0 {
          table(
            columns: (1fr, auto, auto, auto),
            align: (left, right, right, right),
            stroke: none,
            inset: (x: 0.5em, y: 0.35em),
            ..hours
              .pairs()
              .map(((person, time)) => {
                let r = rates.at(person, default: 0)
                (
                  person,
                  fmt-price(r, cur),
                  [#(time)h],
                  fmt-price(r * time, cur),
                )
              })
              .flatten(),
          )
        } else [ _No staff allocated._ \ ]

        #v(0.3em)
        #line(length: 100%, stroke: 0.5pt + luma(210))

        #table(
          columns: (1fr, auto),
          align: (left, right),
          stroke: none,
          inset: (x: 0.5em, y: 0.35em),
          [Material Costs:], [#fmt-price(materials, cur)],
          [*Total Costs:*], [*#fmt-price(total-cost, cur)*],
        )
      ],
    )
  }
]

/// Generates a comprehensive summary table for all work packages
#let summary(vat: 0.081, discount: 0, round: 0) = context {
  let wps = wps-state.final()
  let rates = rates-state.final()
  let cur = currency-state.get()
  let wp-round = wp-round-state.get()

  // Calculate totals across all packages
  let processed-wps = wps.map(wp => {
    let staff-cost = 0
    for (person, h) in wp.hours.pairs() {
      staff-cost += h * rates.at(person, default: 0)
    }
    if wp-round != 0 {
        staff-cost = calc.ceil(staff-cost / wp-round) * wp-round
    }
    (
      title: wp.title,
      staff-cost: staff-cost,
      materials: wp.materials,
      total: staff-cost + wp.materials,
    )
  })

  let total-staff = processed-wps.fold(0, (acc, wp) => acc + wp.staff-cost)
  let total-materials = processed-wps.fold(0, (acc, wp) => acc + wp.materials)
  let grand-total = processed-wps.fold(0, (acc, wp) => acc + wp.total)
  let discount-total = grand-total - discount
  let vat-amount = calc.round(discount-total * vat, digits: 2)
  let total-incl-vat = calc.round(discount-total * (1 + vat), digits: 2)
  let final-discount = discount
  if round != 0 {
      let target-total = calc.floor(total-incl-vat / round) * round
      let diff = total-incl-vat - target-total
      final-discount = final-discount + calc.round(diff / (1 + vat), digits: 2)
      discount-total = grand-total - final-discount
      vat-amount = calc.round(discount-total * vat, digits: 2)
      total-incl-vat = calc.round(discount-total * (1 + vat), digits: 2)
  }

  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    stroke: 0.5pt + luma(180),
    fill: (col, row) => if row == 0 { luma(242) },
    [*Work Package*], [*Personnel Cost*], [*Material Cost*], [*Total*],

    ..processed-wps
      .enumerate()
      .map(((i, wp)) => (
        text(size: 0.85em, "WP" + str(i + 1) + ": " + wp.title),
        fmt-price(wp.staff-cost, cur),
        fmt-price(wp.materials, cur),
        [*#fmt-price(wp.total, cur)*],
      ))
      .flatten(),

    [*Total* #text(size: 0.75em)[_excl. VAT_]],
    [*#fmt-price(total-staff, cur)*],
    [*#fmt-price(total-materials, cur)*],
    [*#fmt-price(grand-total, cur)*],

    ..(if final-discount != 0 {
        (table.cell(colspan: 3)[_Discount_],
        [#fmt-price(final-discount, cur)])
    } else {()}),

    table.cell(colspan: 3)[_#(vat * 100)% VAT_],
    [#fmt-price(vat-amount, cur)],

    table.cell(colspan: 3)[*Total* #text(size: 0.75em)[_incl. VAT_]],
    [*#fmt-price(total-incl-vat, cur)*],
  )
}
