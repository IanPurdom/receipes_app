import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "status", "tags"]
  static values = { url: String }

  connect() {
    this.activeIndex = -1
    this.requestId = 0
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
    this.abortController?.abort()
  }

  search() {
    clearTimeout(this.searchTimeout)
    this.abortController?.abort()
    this.activeIndex = -1
    this.clearSuggestions()

    const requestId = ++this.requestId
    const query = this.inputTarget.value.trim()
    if (query.length < 2) return

    this.searchTimeout = setTimeout(() => this.fetchSuggestions(query, requestId), 150)
  }

  navigate(event) {
    if (event.key === "Escape") {
      this.hideSuggestions()
      return
    }

    if (event.key === "Backspace" && this.inputTarget.value === "") {
      this.tagItems.at(-1)?.remove()
      return
    }

    if (event.key === "Enter" && this.inputTarget.value.trim() !== "") {
      // Typed text only becomes a tag when a suggestion is picked.
      event.preventDefault()
      if (this.activeIndex >= 0) this.select(this.suggestionOptions[this.activeIndex])
      return
    }

    if (this.suggestionOptions.length === 0) return

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const direction = event.key === "ArrowDown" ? 1 : -1
      const count = this.suggestionOptions.length
      this.activeIndex =
        this.activeIndex === -1
          ? (direction === 1 ? 0 : count - 1)
          : (this.activeIndex + direction + count) % count
      this.updateActiveOption()
    }
  }

  selectSuggestion(event) {
    event.preventDefault()
    this.select(event.currentTarget)
  }

  removeTag(event) {
    event.currentTarget.closest("li").remove()
    this.submit()
  }

  submitOnChange(event) {
    if (event.target !== this.inputTarget) this.submit()
  }

  submit() {
    this.element.requestSubmit()
  }

  async fetchSuggestions(query, requestId) {
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) throw new Error(`Suggestion request failed (${response.status})`)

      const suggestions = await response.json()
      if (requestId !== this.requestId || !Array.isArray(suggestions)) return

      const selected = this.selectedNames
      this.renderSuggestions(suggestions.filter(({ name }) => !selected.has(name.toLowerCase())))
    } catch (error) {
      if (error.name === "AbortError") return
      this.statusTarget.textContent = "Ingredient suggestions are currently unavailable."
    }
  }

  renderSuggestions(suggestions) {
    this.suggestionsTarget.replaceChildren()
    suggestions.forEach(({ name, note }, index) => {
      const option = document.createElement("li")
      option.id = `ingredient-suggestion-${this.requestId}-${index}`
      option.setAttribute("role", "option")
      option.setAttribute("aria-selected", "false")
      option.dataset.name = name
      option.dataset.note = note || ""
      option.textContent = note ? `${name} (${note})` : name
      option.addEventListener("pointerdown", this.selectSuggestion.bind(this))
      this.suggestionsTarget.append(option)
    })

    const hasSuggestions = suggestions.length > 0
    this.suggestionsTarget.hidden = !hasSuggestions
    this.inputTarget.setAttribute("aria-expanded", String(hasSuggestions))
    this.statusTarget.textContent = hasSuggestions
      ? `${suggestions.length} ingredient suggestions available.`
      : "No ingredient suggestions found."
  }

  select(option) {
    const { name, note } = option.dataset
    this.inputTarget.value = ""
    this.hideSuggestions()
    if (this.selectedNames.has(name.toLowerCase())) return

    this.addTag(name, note)
    this.submit()
  }

  addTag(name, note) {
    const item = document.createElement("li")
    item.className = "tag"

    const label = document.createElement("span")
    label.textContent = name

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "ingredients[]"
    hidden.value = name

    const button = document.createElement("button")
    button.type = "button"
    button.className = "tag-remove"
    button.setAttribute("aria-label", `Remove ${name}`)
    button.textContent = "×"
    button.addEventListener("click", this.removeTag.bind(this))

    item.append(label)
    if (note) {
      const noteLabel = document.createElement("span")
      noteLabel.className = "tag-note"
      noteLabel.textContent = `(${note})`
      item.append(noteLabel)
    }
    item.append(hidden, button)
    this.tagsTarget.append(item)
  }

  get tagItems() {
    return Array.from(this.tagsTarget.querySelectorAll("li"))
  }

  get selectedNames() {
    return new Set(this.tagItems.map((item) => item.querySelector("input").value.toLowerCase()))
  }

  get suggestionOptions() {
    return Array.from(this.suggestionsTarget.querySelectorAll('[role="option"]'))
  }

  updateActiveOption() {
    this.suggestionOptions.forEach((option, index) => {
      const active = index === this.activeIndex
      option.setAttribute("aria-selected", String(active))
      if (active) {
        this.inputTarget.setAttribute("aria-activedescendant", option.id)
        option.scrollIntoView({ block: "nearest" })
      }
    })
  }

  clearSuggestions() {
    this.suggestionsTarget.replaceChildren()
    this.suggestionsTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.statusTarget.textContent = ""
  }

  hideSuggestions() {
    this.clearSuggestions()
    this.activeIndex = -1
  }
}
