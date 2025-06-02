import SwiftUI

// MARK: - Maintenance View
struct MaintenanceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var documentService = DocumentService.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Main content
                    VStack(spacing: 32) {
                        // Header section
                        headerSection
                        
                        // How it works
                        howItWorksSection
                        
                        // Quick actions
                        quickActionsSection
                        
                        // Supported forms
                        supportedFormsSection
                    }
                    .padding(.horizontal)
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            UniversalHeaderView(title: "Maintenance")
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await documentService.loadUnreadCount()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }
            
            // Title and description
            VStack(spacing: 8) {
                Text("Maintenance")
                    .font(AppFonts.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Send auto-populated DA maintenance forms from your property book and receive forms from others in your documents inbox.")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
    }
    
    private var howItWorksSection: some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 20) {
                // Section header
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppColors.accent)
                    Text("How Maintenance Forms Work")
                        .font(AppFonts.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                
                // Steps
                VStack(spacing: 20) {
                    StepRow(
                        number: 1,
                        title: "Create Maintenance Request",
                        description: "Go to your Property Book, find the equipment that needs maintenance, and tap 'Send Maintenance Form'."
                    )
                    
                    StepRow(
                        number: 2,
                        title: "Fill Out Form",
                        description: "The DA Form (2404 or 5988-E) will be auto-populated with equipment details. Describe the problem, add photos if needed, and select who to send it to from your connections."
                    )
                    
                    StepRow(
                        number: 3,
                        title: "Receive & Respond",
                        description: "Forms you receive will appear in your Documents inbox. You can view, share, or forward them as needed."
                    )
                }
            }
            .padding()
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            // Property Book Action
            NavigationLink(destination: MyPropertiesView()) {
                ActionCard(
                    icon: "book.closed",
                    iconColor: .blue,
                    title: "Create Maintenance Request",
                    description: "Send maintenance forms for your equipment",
                    buttonText: "Go to Property Book"
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Documents Action
            NavigationLink(destination: DocumentsView()) {
                ActionCard(
                    icon: "tray",
                    iconColor: .green,
                    title: "View Maintenance Forms",
                    description: "Review forms you've received from others",
                    buttonText: "Go to Documents",
                    badge: documentService.unreadMaintenanceCount > 0 ? documentService.unreadMaintenanceCount : nil
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var supportedFormsSection: some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Supported Forms")
                    .font(AppFonts.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                VStack(spacing: 12) {
                    FormTypeRow(
                        title: "DA Form 2404",
                        description: "Equipment Inspection and Maintenance Worksheet"
                    )
                    
                    Divider()
                        .background(AppColors.border)
                    
                    FormTypeRow(
                        title: "DA Form 5988-E", 
                        description: "Equipment Maintenance Request"
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(description)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
}

struct ActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let buttonText: String
    let badge: Int?
    
    init(icon: String, iconColor: Color, title: String, description: String, buttonText: String, badge: Int? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.buttonText = buttonText
        self.badge = badge
    }
    
    var body: some View {
        WebAlignedCard {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        
                        if let badge = badge {
                            Text("\(badge)")
                                .font(AppFonts.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(description)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(2)
                    
                    Spacer(minLength: 8)
                    
                    HStack {
                        Text(buttonText)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.accent)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct FormTypeRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct MaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MaintenanceView()
        }
        .preferredColorScheme(.dark)
    }
} 