import WidgetKit
import SwiftUI

// ─── Veri modeli ────────────────────────────────────────────────────────────

struct VirdEntry: TimelineEntry {
    let date: Date
    let seri: Int
    let hasanat: Int
    let hatimName: String
    let hatimCurrent: Int
    let hatimTotal: Int
    let todayLogged: Bool
}

// ─── Timeline Provider ─────────────────────────────────────────────────────

struct VirdTimelineProvider: TimelineProvider {
    
    private let appGroupId = "group.com.example.virdApp"
    
    func placeholder(in context: Context) -> VirdEntry {
        VirdEntry(
            date: Date(),
            seri: 12,
            hasanat: 450,
            hatimName: "Arapça Hatim",
            hatimCurrent: 120,
            hatimTotal: 604,
            todayLogged: false
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (VirdEntry) -> Void) {
        completion(readEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<VirdEntry>) -> Void) {
        let entry = readEntry()
        // Her 30 dakikada yeniden oku
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func readEntry() -> VirdEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return VirdEntry(
            date: Date(),
            seri: defaults?.integer(forKey: "seri") ?? 0,
            hasanat: defaults?.integer(forKey: "hasanat") ?? 0,
            hatimName: defaults?.string(forKey: "hatim_name") ?? "",
            hatimCurrent: defaults?.integer(forKey: "hatim_current") ?? 0,
            hatimTotal: defaults?.integer(forKey: "hatim_total") ?? 604,
            todayLogged: defaults?.bool(forKey: "today_logged") ?? false
        )
    }
}

// ─── Widget View ────────────────────────────────────────────────────────────

struct VirdWidgetEntryView: View {
    var entry: VirdEntry
    
    private let bgColor = Color(red: 0.10, green: 0.18, blue: 0.21) // #1A2E35
    private let tealColor = Color(red: 0.16, green: 0.50, blue: 0.55) // #2A7F8C
    private let tealLightColor = Color(red: 0.91, green: 0.96, blue: 0.97) // #E8F5F7
    private let orangeColor = Color(red: 1.0, green: 0.59, blue: 0.0) // #FF9600
    private let goldColor = Color(red: 1.0, green: 0.76, blue: 0.0) // #FFC200
    
    var progress: Double {
        guard entry.hatimTotal > 0 else { return 0 }
        return Double(entry.hatimCurrent) / Double(entry.hatimTotal)
    }
    
    var statusMessage: String {
        if entry.todayLogged {
            return "Bugün okudum ✓ Maşallah!"
        } else if entry.seri > 0 {
            return "Bugün okumadın · \(entry.seri) günlük serini koru! 📖"
        } else {
            return "Bugün okumadın · Hadi başla! 📖"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Üst satır: Seri + Hasanat ───────────────────────────────
            HStack {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 14))
                    Text("\(entry.seri) Gün")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(orangeColor)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("⭐")
                        .font(.system(size: 14))
                    Text("\(entry.hasanat)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(goldColor)
                }
            }
            .padding(.bottom, 10)
            
            // ── Ayırıcı ────────────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.bottom, 10)
            
            // ── Hatim bilgisi ──────────────────────────────────────────
            HStack {
                Text("📖")
                    .font(.system(size: 14))
                
                Text(entry.hatimName.isEmpty ? "Aktif hatim yok" : entry.hatimName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(tealLightColor)
                    .lineLimit(1)
                
                Spacer()
                
                if !entry.hatimName.isEmpty {
                    Text("\(entry.hatimCurrent)/\(entry.hatimTotal)")
                        .font(.system(size: 12))
                        .foregroundColor(tealLightColor.opacity(0.5))
                }
            }
            .padding(.bottom, 8)
            
            // ── Progress bar ───────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tealColor)
                        .frame(width: max(geo.size.width * progress, 2), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.bottom, 10)
            
            // ── Ayırıcı ────────────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.bottom, 8)
            
            // ── Durum mesajı ───────────────────────────────────────────
            Text(statusMessage)
                .font(.system(size: 11))
                .foregroundColor(tealLightColor.opacity(0.55))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// ─── Widget tanımı ──────────────────────────────────────────────────────────

struct VirdWidget: Widget {
    let kind: String = "VirdWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VirdTimelineProvider()) { entry in
            VirdWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.10, green: 0.18, blue: 0.21)
                }
        }
        .configurationDisplayName("Vird")
        .description("Seri, Hasanat ve Hatim ilerlemenizi takip edin.")
        .supportedFamilies([.systemMedium])
    }
}

// ─── Preview ────────────────────────────────────────────────────────────────

#Preview(as: .systemMedium) {
    VirdWidget()
} timeline: {
    VirdEntry(
        date: Date(),
        seri: 12,
        hasanat: 450,
        hatimName: "Arapça Hatim",
        hatimCurrent: 120,
        hatimTotal: 604,
        todayLogged: false
    )
    VirdEntry(
        date: Date(),
        seri: 13,
        hasanat: 500,
        hatimName: "Arapça Hatim",
        hatimCurrent: 130,
        hatimTotal: 604,
        todayLogged: true
    )
}
