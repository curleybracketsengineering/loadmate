import SwiftUI

enum NoseWeightGaugeDisplayStyle {
  case full
  case compact
}

/// Horizontal scale: green = ideal band, amber = caution outside band (but not over car limit), red = over limit.
struct NoseWeightSafeZoneGauge: View {
  let zoneLowKg: Double
  let zoneHighKg: Double
  let carMaxTowBallKg: Double
  let estimatedNoseKg: Double
  var displayStyle: NoseWeightGaugeDisplayStyle = .full

  private static let amberFill = Color(red: 0.97, green: 0.73, blue: 0.12)
  private static let barHeight: CGFloat = 12
  private static let markerHeight: CGFloat = 20
  private static let tickBarGap: CGFloat = 26
  private static let carMaxBarGap: CGFloat = tickBarGap / 2
  private static let carMaxPointerHeight: CGFloat = 48

  private static let textPointBump: CGFloat = 2
  private static let caption2PointSize: CGFloat = 11 + textPointBump
  private static let captionPointSize: CGFloat = 12 + textPointBump

  private static let legendScale: CGFloat = 1.1
  private static let legendDotDiameter: CGFloat = 7 * legendScale
  private static let legendTextSize: CGFloat = 11 * legendScale + textPointBump
  private static let legendTriangleSize: CGFloat = 8 * legendScale + textPointBump
  private static let carMaxTriangleSize: CGFloat = 11 + textPointBump

  private var barTop: CGFloat {
    carMaxTowBallKg > 0 ? Self.carMaxBarGap + Self.carMaxPointerHeight : 2
  }

  private var idealMidKg: Double { (zoneLowKg + zoneHighKg) / 2 }

  private var axisMin: Double {
    let candidates = [zoneLowKg, zoneHighKg, estimatedNoseKg, carMaxTowBallKg > 0 ? carMaxTowBallKg : zoneHighKg]
    let lo = candidates.min() ?? 0
    let pad = max((zoneHighKg - zoneLowKg) * 0.12, 2)
    return max(0, lo - pad)
  }

  private var axisMax: Double {
    var hi = max(zoneHighKg, estimatedNoseKg)
    if carMaxTowBallKg > 0 { hi = max(hi, carMaxTowBallKg) }
    let pad = max((zoneHighKg - zoneLowKg) * 0.12, 2)
    return hi + pad
  }

  private var axisSpan: Double { max(axisMax - axisMin, 1) }

  private func xFraction(for kg: Double) -> CGFloat {
    CGFloat((kg - axisMin) / axisSpan)
  }

  private func clampedXFraction(_ kg: Double) -> CGFloat {
    min(max(xFraction(for: kg), 0), 1)
  }

  private var segmentBoundaries: [Double] {
    var values: [Double] = [axisMin, axisMax, zoneLowKg, zoneHighKg]
    if carMaxTowBallKg > 0 {
      values.append(carMaxTowBallKg)
    }
    let sorted = values.sorted()
    var deduped: [Double] = []
    for v in sorted {
      if let last = deduped.last, abs(v - last) < 1e-6 {
        continue
      }
      deduped.append(v)
    }
    return deduped
  }

  private func zoneColor(forKilograms kg: Double) -> Color {
    if kg < zoneLowKg { return Self.amberFill }
    if kg <= zoneHighKg { return AppColors.green.opacity(0.92) }
    if carMaxTowBallKg > 0, kg <= carMaxTowBallKg { return Self.amberFill }
    return AppColors.red
  }

  private var segments: [(start: Double, end: Double, color: Color)] {
    let pts = segmentBoundaries
    guard pts.count >= 2 else { return [] }
    var result: [(start: Double, end: Double, color: Color)] = []
    for i in 0..<(pts.count - 1) {
      let s = pts[i]
      let t = pts[i + 1]
      guard t > s + 0.0001 else { continue }
      let mid = (s + t) / 2
      let color = zoneColor(forKilograms: mid)
      result.append((start: s, end: t, color: color))
    }
    return result
  }

  private var accessibilitySummary: String {
    let est = kgAmountGauge(estimatedNoseKg)
    if estimatedNoseKg < zoneLowKg {
      return "Estimated nose weight \(est), below ideal range starting at \(kgAmountGauge(zoneLowKg))."
    }
    if estimatedNoseKg > zoneHighKg, carMaxTowBallKg > 0, estimatedNoseKg <= carMaxTowBallKg {
      return "Estimated nose weight \(est), above ideal range but within car tow ball limit \(kgAmountGauge(carMaxTowBallKg))."
    }
    if carMaxTowBallKg > 0, estimatedNoseKg > carMaxTowBallKg {
      return "Estimated nose weight \(est), over car tow ball limit \(kgAmountGauge(carMaxTowBallKg))."
    }
    if estimatedNoseKg > zoneHighKg {
      return "Estimated nose weight \(est), above ideal range up to \(kgAmountGauge(zoneHighKg))."
    }
    if carMaxTowBallKg > 0 {
      return "Estimated nose weight \(est), within ideal range \(kgAmountGauge(zoneLowKg)) to \(kgAmountGauge(zoneHighKg)). Car maximum tow ball \(kgAmountGauge(carMaxTowBallKg))."
    }
    return "Estimated nose weight \(est), within ideal range \(kgAmountGauge(zoneLowKg)) to \(kgAmountGauge(zoneHighKg))."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if displayStyle == .full {
        Text("Safe zone")
          .font(.system(size: Self.captionPointSize, weight: .semibold))
          .foregroundStyle(Color.secondary)
      }

      GeometryReader { geo in
        let width = geo.size.width

        ZStack(alignment: .topLeading) {
          if carMaxTowBallKg > 0 {
            carMaxTowBallPointer()
              .position(
                x: clampedCenterX(forKg: carMaxTowBallKg, width: width),
                y: barTop - Self.carMaxBarGap - Self.carMaxPointerHeight / 2
              )
              .accessibilityHidden(true)
          }

          HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
              let w = max(width * CGFloat((seg.end - seg.start) / axisSpan), 0)
              Rectangle()
                .fill(seg.color)
                .frame(width: w)
            }
          }
          .frame(height: Self.barHeight)
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
          .offset(x: 0, y: barTop)

          RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color.primary)
            .frame(width: 4, height: Self.markerHeight)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .offset(
              x: clampedCenterX(forKg: estimatedNoseKg, width: width) - 2,
              y: barTop + Self.barHeight / 2 - Self.markerHeight / 2
            )
            .accessibilityHidden(true)

          tickLabel(valueKg: zoneLowKg, title: "Low", width: width)
            .position(x: labelX(forKg: zoneLowKg, width: width), y: barTop + Self.barHeight + Self.tickBarGap)

          tickLabel(valueKg: idealMidKg, title: "Ideal", width: width)
            .position(x: labelX(forKg: idealMidKg, width: width), y: barTop + Self.barHeight + Self.tickBarGap)

          tickLabel(valueKg: zoneHighKg, title: "Max", width: width)
            .position(x: labelX(forKg: zoneHighKg, width: width), y: barTop + Self.barHeight + Self.tickBarGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(height: barTop + Self.barHeight + 56)

      if displayStyle == .full {
        HStack(spacing: AppScreenMetrics.smallSpacing * Self.legendScale) {
          legendDot(AppColors.green.opacity(0.92))
          Text("Ideal")
            .foregroundStyle(Color.secondary)
          legendDot(Self.amberFill)
          Text("Caution")
            .foregroundStyle(Color.secondary)
          legendDot(AppColors.red)
          Text("Over limit")
            .foregroundStyle(Color.secondary)
          if carMaxTowBallKg > 0 {
            Text("·")
              .foregroundStyle(Color.secondary.opacity(0.55))
            Image(systemName: "arrowtriangle.down.fill")
              .font(.system(size: Self.legendTriangleSize, weight: .semibold))
              .foregroundStyle(Color.accentColor)
            Text("Car max")
              .foregroundStyle(Color.secondary)
          }
        }
        .font(.system(size: Self.legendTextSize, weight: .regular))
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Nose weight safe zone")
    .accessibilityValue(accessibilitySummary)
  }

  private func labelX(forKg kg: Double, width: CGFloat) -> CGFloat {
    clampedCenterX(forKg: kg, width: width)
  }

  private func clampedCenterX(forKg kg: Double, width: CGFloat) -> CGFloat {
    let raw = width * clampedXFraction(kg)
    return min(max(raw, 26), width - 26)
  }

  private func carMaxTowBallPointer() -> some View {
    VStack(spacing: 2) {
      Text("Max tow")
        .font(.system(size: Self.caption2PointSize, weight: .semibold))
        .foregroundStyle(Color.secondary)
      Text(stripKgGauge(Formatters.kg(carMaxTowBallKg)))
        .font(.system(size: Self.caption2PointSize, weight: .bold))
        .foregroundStyle(Color.accentColor)
      Spacer(minLength: 0)
      Image(systemName: "arrowtriangle.down.fill")
        .font(.system(size: Self.carMaxTriangleSize, weight: .semibold))
        .foregroundStyle(Color.accentColor)
    }
    .frame(width: 76, height: Self.carMaxPointerHeight, alignment: .top)
  }

  private func tickLabel(valueKg: Double, title: String, width: CGFloat) -> some View {
    VStack(spacing: 1) {
      Text(stripKgGauge(Formatters.kg(valueKg)))
        .font(.system(size: Self.captionPointSize, weight: .semibold))
        .foregroundStyle(Color.primary)
      Text(title)
        .font(.system(size: Self.caption2PointSize, weight: .medium))
        .foregroundStyle(Color.secondary)
    }
    .frame(width: min(width * 0.34, 120))
  }

  private func legendDot(_ color: Color) -> some View {
    Circle()
      .fill(color)
      .frame(width: Self.legendDotDiameter, height: Self.legendDotDiameter)
  }

  private func stripKgGauge(_ s: String) -> String {
    s.replacingOccurrences(of: " kg", with: "").trimmingCharacters(in: .whitespaces) + " kg"
  }

  private func kgAmountGauge(_ kg: Double) -> String {
    stripKgGauge(Formatters.kg(kg))
  }
}

// MARK: - Tow bar status badge (Locations)

struct TowBarWeightStatusBadge: View {
  let summary: WeightSummary
  let profile: VehicleProfile

  private struct BadgeStyle {
    let title: String
    let delta: String
    let foreground: Color
    let background: Color
  }

  private var badgeStyle: BadgeStyle? {
    if summary.isOverTowBallLimit {
      let over = max(0, summary.estimatedNoseWeightKg - profile.effectiveMaxTowBallKg)
      return BadgeStyle(
        title: "Over limit",
        delta: Formatters.signedKg(over),
        foreground: AppColors.red,
        background: AppColors.red.opacity(0.12)
      )
    }
    if summary.isNoseBelowRecommended {
      let add = max(0, summary.towBallMinKg - summary.estimatedNoseWeightKg)
      return BadgeStyle(
        title: "Below ideal",
        delta: Formatters.signedKg(add),
        foreground: AppColors.orange,
        background: AppColors.orange.opacity(0.14)
      )
    }
    if summary.isNoseAboveRecommended {
      let reduce = max(0, summary.estimatedNoseWeightKg - summary.towBallMaxKg)
      return BadgeStyle(
        title: "Above ideal",
        delta: Formatters.signedKg(reduce),
        foreground: AppColors.orange,
        background: AppColors.orange.opacity(0.14)
      )
    }
    return nil
  }

  var body: some View {
    if let style = badgeStyle {
      HStack(alignment: .top, spacing: 8) {
        if summary.isOverTowBallLimit {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .accessibilityHidden(true)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(style.title)
            .font(.caption.weight(.semibold))
          Text(style.delta)
            .font(.caption.weight(.bold))
        }
      }
      .foregroundStyle(style.foreground)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(style.background)
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(style.title), \(style.delta)")
    }
  }
}

extension WeightSummary {
  func noseGaugeZoneBounds(profile: VehicleProfile) -> (low: Double, high: Double) {
    let effectiveLimit = profile.effectiveMaxTowBallKg
    let carLimitOverridesMin = effectiveLimit > 0 && effectiveLimit < towBallMinKg
    let carLimitOverridesMax = effectiveLimit > 0 && effectiveLimit < towBallMaxKg
    let low = carLimitOverridesMin ? effectiveLimit : towBallMinKg
    let high = carLimitOverridesMax ? effectiveLimit : towBallMaxKg
    return (low, high)
  }
}
