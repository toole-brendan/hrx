import SwiftUI
import Charts

struct ReportsView: View {
    @State private var selectedReportType: ReportType = .inventory
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isGenerating = false
    
    enum ReportType: String, CaseIterable {
        case inventory = "Inventory"
        case transfers = "Transfers"
        case maintenance = "Maintenance"
        case readiness = "Readiness"
        
        var icon: String {
            switch self {
            case .inventory: return "shippingbox"
            case .transfers: return "arrow.left.arrow.right"
            case .maintenance: return "wrench"
            case .readiness: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Report Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("REPORT TYPE")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            ReportTypeCard(
                                type: type,
                                isSelected: selectedReportType == type
                            ) {
                                withAnimation {
                                    selectedReportType = type
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Time Range Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("TIME RANGE")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                    
                    HStack(spacing: 12) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            TimeRangeButton(
                                range: range,
                                isSelected: selectedTimeRange == range
                            ) {
                                withAnimation {
                                    selectedTimeRange = range
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Report Preview
                ReportPreviewCard(
                    reportType: selectedReportType,
                    timeRange: selectedTimeRange
                )
                .padding(.horizontal)
                
                // Quick Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("QUICK STATS")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                    
                    VStack(spacing: 12) {
                        QuickStatRow(label: "Total Items", value: "156", trend: .up(12))
                        QuickStatRow(label: "Transfers This Month", value: "23", trend: .down(5))
                        QuickStatRow(label: "Maintenance Completion", value: "87%", trend: .up(3))
                        QuickStatRow(label: "Overall Readiness", value: "92%", trend: .neutral)
                    }
                    .padding()
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Generate Report Button
                Button(action: {
                    generateReport()
                }) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text.fill")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Full Report")
                            .font(AppFonts.bodyBold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accent)
                    .cornerRadius(8)
                }
                .disabled(isGenerating)
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .padding(.top)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Export action
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
    
    private func generateReport() {
        isGenerating = true
        
        // Simulate report generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isGenerating = false
            // Show report or navigate to report view
        }
    }
}

// MARK: - Components
struct ReportTypeCard: View {
    let type: ReportsView.ReportType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : AppColors.accent)
                
                Text(type.rawValue)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(isSelected ? .white : AppColors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? AppColors.accent : AppColors.secondaryBackground)
            .cornerRadius(12)
        }
    }
}

struct TimeRangeButton: View {
    let range: ReportsView.TimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(AppFonts.captionBold)
                .foregroundColor(isSelected ? .white : AppColors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accent : AppColors.tertiaryBackground)
                .cornerRadius(20)
        }
    }
}

struct ReportPreviewCard: View {
    let reportType: ReportsView.ReportType
    let timeRange: ReportsView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(reportType.rawValue) Report")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Text("Last \(timeRange.rawValue)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // Mock Chart
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(mockChartData) { data in
                        LineMark(
                            x: .value("Day", data.day),
                            y: .value("Value", data.value)
                        )
                        .foregroundStyle(AppColors.accent)
                        
                        AreaMark(
                            x: .value("Day", data.day),
                            y: .value("Value", data.value)
                        )
                        .foregroundStyle(AppColors.accent.opacity(0.1))
                    }
                }
                .frame(height: 200)
            } else {
                // Fallback for iOS 15
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.tertiaryBackground)
                    
                    Text("Chart Preview")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                .frame(height: 200)
            }
            
            // Summary Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    Text("85%")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    Text("94%")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trend")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("+5%")
                            .font(AppFonts.headline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

struct QuickStatRow: View {
    let label: String
    let value: String
    let trend: Trend
    
    enum Trend {
        case up(Int)
        case down(Int)
        case neutral
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return AppColors.secondaryText
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
        
        var text: String {
            switch self {
            case .up(let value): return "+\(value)%"
            case .down(let value): return "-\(value)%"
            case .neutral: return "0%"
            }
        }
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.primaryText)
            
            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.caption)
                Text(trend.text)
                    .font(AppFonts.caption)
            }
            .foregroundColor(trend.color)
        }
    }
}

// MARK: - Mock Data
struct ChartData: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
}

let mockChartData = [
    ChartData(day: "Mon", value: 82),
    ChartData(day: "Tue", value: 85),
    ChartData(day: "Wed", value: 88),
    ChartData(day: "Thu", value: 84),
    ChartData(day: "Fri", value: 90),
    ChartData(day: "Sat", value: 92),
    ChartData(day: "Sun", value: 94)
]

// MARK: - Preview
struct ReportsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ReportsView()
        }
        .preferredColorScheme(.dark)
    }
} 