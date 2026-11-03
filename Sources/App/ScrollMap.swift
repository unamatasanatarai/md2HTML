import CoreGraphics

/// Piecewise-linear map between two scroll positions, built from matching (source, target) points.
struct ScrollMap {
    private(set) var points: [(source: CGFloat, target: CGFloat)]

    /// Keeps only points that increase in both coordinates, so the map is monotonic and invertible.
    init(points: [(source: CGFloat, target: CGFloat)]) {
        var kept: [(source: CGFloat, target: CGFloat)] = []
        for point in points {
            if let last = kept.last, point.source <= last.source || point.target <= last.target { continue }
            kept.append(point)
        }
        self.points = kept
    }

    var inverted: ScrollMap {
        return ScrollMap(points: points.map { (source: $0.target, target: $0.source) })
    }

    func map(_ value: CGFloat) -> CGFloat {
        guard let first = points.first, let last = points.last else { return value }
        if value <= first.source { return first.target }
        if value >= last.source { return last.target }
        for index in 1..<points.count where value < points[index].source {
            let a = points[index - 1], b = points[index]
            let t = (value - a.source) / (b.source - a.source)
            return a.target + t * (b.target - a.target)
        }
        return last.target
    }
}
