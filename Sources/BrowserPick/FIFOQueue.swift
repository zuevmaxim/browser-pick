struct FIFOQueue<Element> {
    private(set) var current: Element?
    private var pending: [Element] = []

    mutating func enqueue(_ element: Element) {
        if current == nil {
            current = element
        } else {
            pending.append(element)
        }
    }

    @discardableResult
    mutating func completeCurrent() -> Element? {
        let completed = current
        advance()
        return completed
    }

    mutating func cancelCurrent() {
        advance()
    }

    private mutating func advance() {
        current = pending.isEmpty ? nil : pending.removeFirst()
    }
}
