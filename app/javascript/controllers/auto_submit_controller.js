import { Controller } from "@hotwired/stimulus"

// Submits the form when a select/radio/number field changes. Text inputs are
// skipped: the ingredient autocomplete submits the form itself.
export default class extends Controller {
  submit(event) {
    if (event.target.type !== "text") this.element.requestSubmit()
  }
}
