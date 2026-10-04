import SwiftUI
import Charts

enum UI {
    static let corner: CGFloat = 14
    static let cardPadding: CGFloat = 16
    static let gridSpacing: CGFloat = 14
}

struct Card<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    var accent: Color = .accentColor
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            content()
        }
        .padding(UI.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: UI.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UI.corner, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var systemImage: String? = nil
    var accent: Color = .accentColor

    var body: some View {
        Card(accent: accent) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(sub ?? " ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 20)
    }
}

struct RingGauge: View {
    var progress: Double
    var label: String
    var caption: String? = nil
    var tint: Color = .accentColor
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let caption {
                    Text(caption)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct BarMeter: View {
    var value: Double
    var tint: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: height)
    }
}

struct PercentAreaChart: View {
    var points: [HistoryPoint]
    var tint: Color = .accentColor
    var height: CGFloat = 130

    var body: some View {
        Chart(points) { p in
            AreaMark(x: .value("t", p.t), y: .value("v", p.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("t", p.t), y: .value("v", p.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { v in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))%").font(.system(size: 9)) } }
            }
        }
        .chartXAxis(.hidden)
        .frame(height: height)
    }
}

struct NetworkChart: View {
    var inPoints: [HistoryPoint]
    var outPoints: [HistoryPoint]
    var height: CGFloat = 150

    private var maxVal: Double {
        let m = (inPoints + outPoints).map(\.value).max() ?? 0
        return max(1024, m * 1.2)
    }

    var body: some View {
        Chart {
            ForEach(inPoints) { p in
                AreaMark(x: .value("t", p.t), y: .value("v", p.value), series: .value("s", "Download"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("t", p.t), y: .value("v", p.value), series: .value("s", "Download"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)
            }
            ForEach(outPoints) { p in
                LineMark(x: .value("t", p.t), y: .value("v", p.value), series: .value("s", "Upload"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.green)
            }
        }
        .chartYScale(domain: 0...maxVal)
        .chartYAxis {
            AxisMarks(position: .leading) { v in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel { if let d = v.as(Double.self) { Text(Formatters.rate(d)).font(.system(size: 9)) } }
            }
        }
        .chartXAxis(.hidden)
        .frame(height: height)
    }
}

struct LineSeriesChart: View {
    var points: [HistoryPoint]
    var tint: Color = .orange
    var unit: String = ""
    var height: CGFloat = 130

    private var domain: ClosedRange<Double> {
        let vals = points.map(\.value)
        let lo = (vals.min() ?? 0) - 2
        let hi = (vals.max() ?? 1) + 2
        return (lo < hi ? lo : lo - 1)...(hi)
    }

    var body: some View {
        Chart(points) { p in
            LineMark(x: .value("t", p.t), y: .value("v", p.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading) { v in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))\(unit)").font(.system(size: 9)) } }
            }
        }
        .chartXAxis(.hidden)
        .frame(height: height)
    }
}

struct LegendDot: View {
    var color: Color
    var text: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

struct SectionScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UI.gridSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 22, weight: .bold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
