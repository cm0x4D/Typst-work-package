#import "@local/work-packages:0.1.0" as wp

#wp.setup(
  currency: "CHF",
  rates: (
    "Professor": 155,
    "Senior Researcher": 105,
    "Assistant": 70,
  )
)

= Project Budget

== Hourly Rates

#wp.hourly-rates()

== Packages

#wp.work-package(
  "Embedded Architecture Definition",
  description: [Drafting hardware interface specs and RTOS driver layout.],
  hours: (
    "Professor": 5,
    "Senior Researcher": 30,
  ),
  materials: 250,
  deliverables: (
    "System specification document",
  ),
)

#wp.work-package(
  "Embedded Implementation",
  description: [Implementing embedded application.],
  hours: (
    "Professor": 2,
    "Senior Researcher": 75,
  ),
  materials: 1750,
  deliverables: (
    "Source code",
  ),
)

== Summary

#wp.summary()
