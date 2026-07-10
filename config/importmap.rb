# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Chart.js is loaded as a self-contained UMD build via public/chart.umd.min.js
# (window.Chart) — jspm ESM pin was incomplete (missing chunk ../_/MwoWUuIu.js).
