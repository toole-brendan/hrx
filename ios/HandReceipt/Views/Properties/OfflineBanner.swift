//
//  OfflineBanner.swift
//  HandReceipt
//
//  Offline mode banner component
//

import SwiftUI

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Changes will sync when connected")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.warning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(AppColors.warning.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
} 