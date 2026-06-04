import CoreGraphics
import SwiftUI

/// Normalized drop-target regions over iPad cutaway artwork (origin top-left, 0…1).
struct CutawayZoneDropLayout {
    struct Region {
        let zone: LoadZone
        /// Painted band on the asset.
        let rect: CGRect
        /// Extra hit area beyond the painted band (normalized; drop targets only).
        let hitOutset: EdgeInsets

        func hitRectNormalized() -> CGRect {
            CGRect(
                x: rect.minX - hitOutset.leading,
                y: rect.minY - hitOutset.top,
                width: rect.width + hitOutset.leading + hitOutset.trailing,
                height: rect.height + hitOutset.top + hitOutset.bottom
            )
        }
    }

    static func imageAspectRatio(assetName: String) -> CGFloat? {
        switch assetName {
        case "caravanAndBike": return 1536.0 / 1024.0
        case "Caravan": return 1774.0 / 887.0
        default: return nil
        }
    }

    static func regions(assetName: String, zones: [LoadZone]) -> [Region] {
        let all = regionsByAsset[assetName] ?? []
        let allowed = Set(zones)
        return all.filter { allowed.contains($0.zone) }
    }

    private static let regionsByAsset: [String: [Region]] = [
        "caravanAndBike": [
            Region(
                zone: .frontLocker,
                rect: CGRect(x: 0.141, y: 0.320, width: 0.057, height: 0.301),
                hitOutset: EdgeInsets(top: 0.04, leading: 0.05, bottom: 0.03, trailing: 0.025)
            ),
            Region(
                zone: .front,
                rect: CGRect(x: 0.158, y: 0.271, width: 0.232, height: 0.372),
                hitOutset: EdgeInsets()
            ),
            Region(
                zone: .middle,
                rect: CGRect(x: 0.330, y: 0.271, width: 0.311, height: 0.373),
                hitOutset: EdgeInsets()
            ),
            Region(
                zone: .rear,
                rect: CGRect(x: 0.552, y: 0.270, width: 0.307, height: 0.374),
                hitOutset: EdgeInsets()
            ),
            Region(
                zone: .bikeRack,
                rect: CGRect(x: 0.882, y: 0.348, width: 0.063, height: 0.236),
                hitOutset: EdgeInsets(top: 0.02, leading: 0.02, bottom: 0.02, trailing: 0.02)
            ),
        ],
        "Caravan": [
            Region(
                zone: .frontLocker,
                rect: CGRect(x: 0.078, y: 0.511, width: 0.089, height: 0.167),
                hitOutset: EdgeInsets(top: 0.05, leading: 0.055, bottom: 0.03, trailing: 0.02)
            ),
            Region(
                zone: .front,
                rect: CGRect(x: 0.138, y: 0.140, width: 0.243, height: 0.575),
                hitOutset: EdgeInsets()
            ),
            Region(
                zone: .middle,
                rect: CGRect(x: 0.382, y: 0.140, width: 0.280, height: 0.575),
                hitOutset: EdgeInsets()
            ),
            Region(
                zone: .rear,
                rect: CGRect(x: 0.662, y: 0.140, width: 0.300, height: 0.575),
                hitOutset: EdgeInsets()
            ),
        ],
    ]
}

enum AspectFitGeometry {
    /// Frame occupied by `scaledToFit` content inside `container`.
    static func contentRect(imageAspect: CGFloat, in container: CGSize) -> CGRect {
        guard container.width > 0, container.height > 0, imageAspect > 0 else { return .zero }
        let containerAspect = container.width / container.height
        if containerAspect > imageAspect {
            let height = container.height
            let width = height * imageAspect
            let x = (container.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        } else {
            let width = container.width
            let height = width / imageAspect
            let y = (container.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        }
    }

    static func pixelRect(normalized: CGRect, in contentRect: CGRect) -> CGRect {
        CGRect(
            x: contentRect.minX + normalized.minX * contentRect.width,
            y: contentRect.minY + normalized.minY * contentRect.height,
            width: normalized.width * contentRect.width,
            height: normalized.height * contentRect.height
        )
    }
}
