// Internal states and counter
#let rates-state = state("wp-rates", (:))
#let currency-state = state("wp-currency", "CHF")
#let wps-state = state("wp-records", ())
#let wp-counter = counter("wp-counter")

// Helper: consistent currency styling
#let fmt-price(amount, cur) = [#amount #text(size: 0.85em, cur)]

/// Renders an overview table of all defined hourly rates
#let hourly-rates() = context {
  let rates = rates-state.get()
  let cur = currency-state.get()

  align(center,
    table(
      columns: (auto, auto),
      column-gutter: 1.5em,
      stroke: none,
      align: (right, left),
      ..rates
        .pairs()
        .map(((staff, rate)) => (
          [#staff:],
          [*#fmt-price(rate, cur)*]
        ))
        .flatten(),
    )
  )
}

/// Configures the global project rates and currency.
/// Works both as a show rule (#show: wp.setup.with(...)) or standalone (#wp.setup(...))
#let setup(rates: (:), currency: "CHF", show-rates: false) = {
    rates-state.update(rates)
    currency-state.update(currency)

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

    // Calculate staff costs
    let staff-cost = 0
    for (person, h) in hours.pairs() {
      let r = rates.at(person, default: 0)
      staff-cost += h * r
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

        #grid(
          columns: (1fr, auto),
          row-gutter: 0.5em,
          [Material Costs:], [#fmt-price(materials, cur)],
          [*Total Costs:*], [*#fmt-price(total-cost, cur)*],
        )
      ],
    )
  }
]

/// Generates a comprehensive summary table for all work packages
#let summary(vat: 0.081) = context {
  let wps = wps-state.final()
  let rates = rates-state.final()
  let cur = currency-state.get()

  // Calculate totals across all packages
  let processed-wps = wps.map(wp => {
    let staff-cost = 0
    for (person, h) in wp.hours.pairs() {
      staff-cost += h * rates.at(person, default: 0)
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
  let vat-amount = calc.round(grand-total * vat, digits: 2)
  let total-incl-vat = calc.round(grand-total * (1 + vat), digits: 2)

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

    table.cell(colspan: 3)[_#(vat * 100)% VAT_],
    [#fmt-price(vat-amount, cur)],

    table.cell(colspan: 3)[*Total* #text(size: 0.75em)[_incl. VAT_]],
    [*#fmt-price(total-incl-vat, cur)*],
  )
}
